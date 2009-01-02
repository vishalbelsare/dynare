function [fval,cost_flag,ys,trend_coeff,info] = DsgeLikelihood(xparam1,gend,data,data_index,number_of_observations,no_more_missing_observations)
% function [fval,cost_flag,ys,trend_coeff,info] = DsgeLikelihood(xparam1,gend,data,data_index,number_of_observations,no_more_missing_observations)
% Evaluates the posterior kernel of a dsge model. 
% 
% INPUTS 
%   xparam1                        [double]   vector of model parameters.
%   gend                           [integer]  scalar specifying the number of observations.
%   data                           [double]   matrix of data
%   data_index                     [cell]     cell of column vectors
%   number_of_observations         [integer]
%   no_more_missing_observations   [integer] 
% OUTPUTS 
%   fval        :     value of the posterior kernel at xparam1.
%   cost_flag   :     zero if the function returns a penalty, one otherwise.
%   ys          :     steady state of original endogenous variables
%   trend_coeff :
%   info        :     vector of informations about the penalty:
%                     41: one (many) parameter(s) do(es) not satisfied the lower bound
%                     42: one (many) parameter(s) do(es) not satisfied the upper bound
%               
% SPECIAL REQUIREMENTS
%

% Copyright (C) 2004-2008 Dynare Team
%
% This file is part of Dynare.
%
% Dynare is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% Dynare is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with Dynare.  If not, see <http://www.gnu.org/licenses/>.

  global bayestopt_ estim_params_ options_ trend_coeff_ M_ oo_
  fval		= [];
  ys		= [];
  trend_coeff	= [];
  cost_flag  	= 1;
  nobs 		= size(options_.varobs,1);
  %------------------------------------------------------------------------------
  % 1. Get the structural parameters & define penalties
  %------------------------------------------------------------------------------
  if options_.mode_compute ~= 1 & any(xparam1 < bayestopt_.lb)
      k = find(xparam1 < bayestopt_.lb);
      fval = bayestopt_.penalty+sum((bayestopt_.lb(k)-xparam1(k)).^2);
      cost_flag = 0;
      info = 41;
      return;
  end
  if options_.mode_compute ~= 1 & any(xparam1 > bayestopt_.ub)
      k = find(xparam1 > bayestopt_.ub);
      fval = bayestopt_.penalty+sum((xparam1(k)-bayestopt_.ub(k)).^2);
      cost_flag = 0;
      info = 42;
      return;
  end
  Q = M_.Sigma_e;
  H = M_.H;
  for i=1:estim_params_.nvx
    k =estim_params_.var_exo(i,1);
    Q(k,k) = xparam1(i)*xparam1(i);
  end
  offset = estim_params_.nvx;
  if estim_params_.nvn
    for i=1:estim_params_.nvn
      k = estim_params_.var_endo(i,1);
      H(k,k) = xparam1(i+offset)*xparam1(i+offset);
    end
    offset = offset+estim_params_.nvn;
  end	
  if estim_params_.ncx
    for i=1:estim_params_.ncx
      k1 =estim_params_.corrx(i,1);
      k2 =estim_params_.corrx(i,2);
      Q(k1,k2) = xparam1(i+offset)*sqrt(Q(k1,k1)*Q(k2,k2));
      Q(k2,k1) = Q(k1,k2);
    end
    [CholQ,testQ] = chol(Q);
    if testQ 	%% The variance-covariance matrix of the structural innovations is not definite positive.
		%% We have to compute the eigenvalues of this matrix in order to build the penalty.
		a = diag(eig(Q));
		k = find(a < 0);
		if k > 0
		  fval = bayestopt_.penalty+sum(-a(k));
		  cost_flag = 0;
		  info = 43;
		  return
		end
    end
    offset = offset+estim_params_.ncx;
  end
  if estim_params_.ncn 
    for i=1:estim_params_.ncn
      k1 = options_.lgyidx2varobs(estim_params_.corrn(i,1));
      k2 = options_.lgyidx2varobs(estim_params_.corrn(i,2));
      H(k1,k2) = xparam1(i+offset)*sqrt(H(k1,k1)*H(k2,k2));
      H(k2,k1) = H(k1,k2);
    end
    [CholH,testH] = chol(H);
    if testH
      a = diag(eig(H));
      k = find(a < 0);
      if k > 0
	fval = bayestopt_.penalty+sum(-a(k));
	cost_flag = 0;
	info = 44;
	return
      end
    end
    offset = offset+estim_params_.ncn;
  end
  if estim_params_.np > 0
      M_.params(estim_params_.param_vals(:,1)) = xparam1(offset+1:end);
  end
  M_.Sigma_e = Q;
  M_.H = H;
  %------------------------------------------------------------------------------
  % 2. call model setup & reduction program
  %------------------------------------------------------------------------------
  [T,R,SteadyState,info] = dynare_resolve(bayestopt_.restrict_var_list,...
					  bayestopt_.restrict_columns,...
					  bayestopt_.restrict_aux);
  if info(1) == 1 | info(1) == 2 | info(1) == 5
    fval = bayestopt_.penalty+1;
    cost_flag = 0;
    return
  elseif info(1) == 3 | info(1) == 4 | info(1) == 20
    fval = bayestopt_.penalty+info(2);%^2; % penalty power raised in DR1.m and resol already. GP July'08
    cost_flag = 0;
    return
  end
  bayestopt_.mf = bayestopt_.mf1;
  if ~options_.noconstant
    if options_.loglinear == 1
      constant = log(SteadyState(bayestopt_.mfys));
    else
      constant = SteadyState(bayestopt_.mfys);
    end
  else
    constant = zeros(nobs,1);
  end
  if bayestopt_.with_trend == 1
    trend_coeff = zeros(nobs,1);
    t = options_.trend_coeffs;
    for i=1:length(t)
      if ~isempty(t{i})
	trend_coeff(i) = evalin('base',t{i});
      end
    end
    trend = repmat(constant,1,gend)+trend_coeff*[1:gend];
  else
    trend = repmat(constant,1,gend);
  end
  start = options_.presample+1;
  np    = size(T,1);
  mf    = bayestopt_.mf;
  no_missing_data_flag = (number_of_observations==gend*nobs);
  %------------------------------------------------------------------------------
  % 3. Initial condition of the Kalman filter
  %------------------------------------------------------------------------------
  kalman_algo = options_.kalman_algo;
  if options_.lik_init == 1		% Kalman filter
      if kalman_algo ~= 2
          kalman_algo = 1;
      end
      Pstar = lyapunov_symm(T,R*Q*R',options_.qz_criterium);
      Pinf	= [];
  elseif options_.lik_init == 2	% Old Diffuse Kalman filter
      if kalman_algo ~= 2
          kalman_algo = 1;
      end
      Pstar = 10*eye(np);
      Pinf = [];
  elseif options_.lik_init == 3	% Diffuse Kalman filter
      if kalman_algo ~= 4
          kalman_algo = 3;
      end
      [QT,ST] = schur(T);
      if exist('OCTAVE_VERSION') || matlab_ver_less_than('7.0.1')
          e1 = abs(my_ordeig(ST)) > 2-options_.qz_criterium;
      else
          e1 = abs(ordeig(ST)) > 2-options_.qz_criterium;
      end
      [QT,ST] = ordschur(QT,ST,e1);
      if exist('OCTAVE_VERSION') || matlab_ver_less_than('7.0.1')
          k = find(abs(my_ordeig(ST)) > 2-options_.qz_criterium);
      else
          k = find(abs(ordeig(ST)) > 2-options_.qz_criterium);
      end
      nk = length(k);
      nk1 = nk+1;
      Pinf = zeros(np,np);
      Pinf(1:nk,1:nk) = eye(nk);
      Pstar = zeros(np,np);
      B = QT'*R*Q*R'*QT;
      for i=np:-1:nk+2
          if ST(i,i-1) == 0
              if i == np
                  c = zeros(np-nk,1);
              else
                  c = ST(nk1:i,:)*(Pstar(:,i+1:end)*ST(i,i+1:end)')+...
                      ST(i,i)*ST(nk1:i,i+1:end)*Pstar(i+1:end,i);
              end
              q = eye(i-nk)-ST(nk1:i,nk1:i)*ST(i,i);
              Pstar(nk1:i,i) = q\(B(nk1:i,i)+c);
              Pstar(i,nk1:i-1) = Pstar(nk1:i-1,i)';
          else
              if i == np
                  c = zeros(np-nk,1);
                  c1 = zeros(np-nk,1);
              else
                  c = ST(nk1:i,:)*(Pstar(:,i+1:end)*ST(i,i+1:end)')+...
                      ST(i,i)*ST(nk1:i,i+1:end)*Pstar(i+1:end,i)+...
                      ST(i,i-1)*ST(nk1:i,i+1:end)*Pstar(i+1:end,i-1);
                  c1 = ST(nk1:i,:)*(Pstar(:,i+1:end)*ST(i-1,i+1:end)')+...
                       ST(i-1,i-1)*ST(nk1:i,i+1:end)*Pstar(i+1:end,i-1)+...
                       ST(i-1,i)*ST(nk1:i,i+1:end)*Pstar(i+1:end,i);
              end
              q = [eye(i-nk)-ST(nk1:i,nk1:i)*ST(i,i) -ST(nk1:i,nk1:i)*ST(i,i-1);...
                   -ST(nk1:i,nk1:i)*ST(i-1,i) eye(i-nk)-ST(nk1:i,nk1:i)*ST(i-1,i-1)];
              z =  q\[B(nk1:i,i)+c;B(nk1:i,i-1)+c1];
              Pstar(nk1:i,i) = z(1:(i-nk));
              Pstar(nk1:i,i-1) = z(i-nk+1:end);
              Pstar(i,nk1:i-1) = Pstar(nk1:i-1,i)';
              Pstar(i-1,nk1:i-2) = Pstar(nk1:i-2,i-1)';
              i = i - 1;
          end
      end
      if i == nk+2
          c = ST(nk+1,:)*(Pstar(:,nk+2:end)*ST(nk1,nk+2:end)')+ST(nk1,nk1)*ST(nk1,nk+2:end)*Pstar(nk+2:end,nk1);
          Pstar(nk1,nk1)=(B(nk1,nk1)+c)/(1-ST(nk1,nk1)*ST(nk1,nk1));
      end
      Z = QT(mf,:);
      R1 = QT'*R;
      [QQ,RR,EE] = qr(Z*ST(:,1:nk),0);
      k = find(abs(diag([RR; zeros(nk-size(Z,1),size(RR,2))])) < 1e-8);
      if length(k) > 0
          k1 = EE(:,k);
	  dd =ones(nk,1);
	  dd(k1) = zeros(length(k1),1);
	  Pinf(1:nk,1:nk) = diag(dd);
      end
  end
  if kalman_algo == 2
  end
  kalman_tol = options_.kalman_tol;
  riccati_tol = options_.riccati_tol;
  mf = bayestopt_.mf1;
  Y   = data-trend;
  %------------------------------------------------------------------------------
  % 4. Likelihood evaluation
  %------------------------------------------------------------------------------
  if (kalman_algo==1)% Multivariate Kalman Filter
      if no_missing_data_flag
          LIK = kalman_filter(T,R,Q,H,Pstar,Y,start,mf,kalman_tol,riccati_tol); 
      else
          LIK = ...
              missing_observations_kalman_filter(T,R,Q,H,Pstar,Y,start,mf,kalman_tol,riccati_tol, ...
                                                 data_index,number_of_observations,no_more_missing_observations);
      end
      if isinf(LIK)
          kalman_algo = 2;
      end
  end
  if (kalman_algo==2)% Univariate Kalman Filter
      no_correlation_flag = 1;
      if length(H)==1 & H == 0
          H = zeros(nobs,1);
      else
          if all(all(abs(H-diag(diag(H)))<1e-14))% ie, the covariance matrix is diagonal...
              H = diag(H);
          else
              no_correlation_flag = 0;
          end
      end
      if no_correlation_flag
          LIK = univariate_kalman_filter(T,R,Q,H,Pstar,Y,start,mf,kalman_tol,riccati_tol,data_index,number_of_observations,no_more_missing_observations);
      else
          LIK = univariate_kalman_filter_corr(T,R,Q,H,Pstar,Y,start,mf,kalman_tol,riccati_tol,data_index,number_of_observations,no_more_missing_observations);
      end
  end
  if (kalman_algo==3)% Multivariate Diffuse Kalman Filter
      if no_missing_data_flag
          LIK = diffuse_kalman_filter(ST,R1,Q,H,Pinf,Pstar,Y,start,Z,kalman_tol, ...
                                      riccati_tol);
      else
          LIK = missing_observations_diffuse_kalman_filter(ST,R1,Q,H,Pinf, ...
                                                           Pstar,Y,start,Z,kalman_tol,riccati_tol,...
                                                           data_index,number_of_observations,...
                                                           no_more_missing_observations);
      end
      if isinf(LIK)
          kalman_algo = 4;
      end
  end
  if (kalman_algo==4)% Univariate Diffuse Kalman Filter
      no_correlation_flag = 1;
      if length(H)==1 & H == 0
          H = zeros(nobs,1);
      else
          if all(all(abs(H-diag(diag(H)))<1e-14))% ie, the covariance matrix is diagonal...
              H = diag(H);
          else
              no_correlation_flag = 0;
          end
      end
      if no_correlation_flag
          LIK = univariate_diffuse_kalman_filter(ST,R1,Q,H,Pinf,Pstar,Y, ...
                                                 start,Z,kalman_tol,riccati_tol,data_index,...
                                                 number_of_observations,no_more_missing_observations);
      else
          LIK = univariate_diffuse_kalman_filter_corr(ST,R1,Q,H,Pinf,Pstar, ...
                                                      Y,start,Z,kalman_tol,riccati_tol,...
                                                      data_index,number_of_observations,...
                                                      no_more_missing_observations);
      end
  end
  if imag(LIK) ~= 0
      likelihood = bayestopt_.penalty;
  else
      likelihood = LIK;
  end
  % ------------------------------------------------------------------------------
  % Adds prior if necessary
  % ------------------------------------------------------------------------------
  lnprior = priordens(xparam1,bayestopt_.pshape,bayestopt_.p1,bayestopt_.p2,bayestopt_.p3,bayestopt_.p4);
  fval    = (likelihood-lnprior);
  options_.kalman_algo = kalman_algo;