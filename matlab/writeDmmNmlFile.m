function writeDmmNmlFile(M_, options_, estimation_info)
% function writeDmmNmlFile(M_, options_, estimation_info)
% Writes the NML file used by the DMM code
%
% INPUTS
%   M_               [structure]
%   options_         [structure]
%   estimation_info  [structure]
%
% OUTPUTS
%   none
%
% SPECIAL REQUIREMENTS
%   none

% Copyright (C) 2014 Dynare Team
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

fid = fopen([M_.fname '.nml'], 'w');
if fid == -1
    error(['writeDmmNmlFile could not open ' M_.fname '.nml for writing.']);
end

fprintf(fid, '%s.nml file generated by Dynare\n', M_.fname);
fprintf(fid, 'from %s.mod on %d-%d-%d at %d:%d:%d\n', M_.fname, fix(clock));

%% SSM
fprintf(fid, '\n&ssm\n');
fprintf(fid, 'nu=%d nv=%d nx=%d d=%d %d dllname=%s check=%s', M_.exo_nbr, ...
        size(options_.multinomial, 2), options_.dmm.nx, ...
        options_.dmm.max_order_of_integration, options_.dmm.num_nonstationary, ...
        [M_.fname '_dmm.m'], options_.dmm.check_mats);
fprintf(fid, '\n&end\n');

%% Prior
fprintf(fid, '\n&prior\n');
nt = size(estimation_info.parameter,2);
fprintf(fid, 'nt=%d\n', nt);
for i=1:nt
    switch estimation_info.parameter(i).prior(1).shape
        case 1
            shape = 'BE';
        case 3
            shape = 'NT';
        case 4
            shape = 'IG';
        otherwise
            error(['Only inv_gamma, normal, and beta are supported for the ' ...
                   'prior distributions of dmm.']);
    end
    fprintf(fid, 'pdftheta(%d) = %s hyptheta(1, %d) = %d %d %d %d\n', i, ...
            shape, i, estimation_info.parameter(i).prior(1).mean, ...
            estimation_info.parameter(i).prior(1).stdev, ...
            estimation_info.parameter(i).prior(1).interval);
end
fprintf(fid, '&end\n');

%% S*
for i=1:size(options_.dmm.S, 2)
    fprintf(fid, '\n&S%d\n', i);

    multidx = find(strcmp({options_.multinomial(:).process}, options_.dmm.S(i).process));
    tpidx = find(strcmp(estimation_info.transition_probability_index, options_.multinomial(multidx).probability));
    params = estimation_info.transition_probability(tpidx).prior.params;

    fprintf(fid, 'dynS%d=%s nS%d=%d hypS%d(1,1)=%d %d matS%d=%s',i,'I',i, ...
            options_.dmm.S(i).ns, i, params, i, options_.dmm.S(i).mat);
    fprintf(fid, '\n&end\n');
end

%% MCMC
fprintf(fid, '\n&mcmc\n');
fprintf(fid, 'seed=%d thin=%d burnin=%d simulrec=%d hbl=%d MargLik=%s', ...
        options_.dmm.seed, options_.dmm.thinning_factor, options_.mcmc.drop, ...
        options_.mcmc.replic, options_.dmm.block_length, ...
        options_.dmm.calc_marg_lik);
fprintf(fid, '\n&end\n');

%% Dataset

fclose(fid);
end
