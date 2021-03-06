%
% DD_RICE2 Sum of two 3D-Rice distributions parametric model
%
%   info = DD_RICE2
%   Returns an (info) structure containing the specifics of the model.
%
%   P = DD_RICE2(r,param)
%   Computes the N-point model (P) from the N-point distance axis (r) according to
%   the paramteres array (param). The required parameters can also be found
%   in the (info) structure.
%
% PARAMETERS
% name      symbol default lower bound upper bound
% --------------------------------------------------------------------------
% param(1)  nu1      2.5     1.0        10         center of 1st component
% param(2)  sigma1   0.7     0.1        5          spread of 1st component
% param(3)  a1       0.5     0          1          amplitude of 1st component
% param(4)  nu2      4.0     1.0        10         center of 2nd component
% param(5)  sigma2   0.7     0.1        5          spread of 2nd component
% --------------------------------------------------------------------------
%

% This file is a part of DeerLab. License is MIT (see LICENSE.md). 
% Copyright(c) 2019-2020: Luis Fabregas, Stefan Stoll and other contributors.

function output = dd_rice2(r,param)

nParam = 5;

if nargin~=0 && nargin~=2
    error('Model requires two input arguments.')
end

if nargin==0
    % If no inputs given, return info about the parametric model
    info.model  = 'Two 3D-Rice distributions';
    info.nparam  = nParam;
    info.parameters(1).name = ['Center ',char(957),'1 1st component'];
    info.parameters(1).range = [1 10];
    info.parameters(1).default = 2.5;
    info.parameters(1).units = 'nm';
    
    info.parameters(2).name = ['Spread ',char(963),'1 1st component'];
    info.parameters(2).range = [0.1 5];
    info.parameters(2).default = 0.7;
    info.parameters(2).units = 'nm';
        
    info.parameters(3).name = 'Relative amplitude a1 1st component';
    info.parameters(3).range = [0 1];
    info.parameters(3).default = 0.5;
    
    info.parameters(4).name = ['Center ',char(957),'2 2nd component'];
    info.parameters(4).range = [1 10];
    info.parameters(4).default = 4.0;
    info.parameters(4).units = 'nm';
    
    info.parameters(5).name = ['Spread ',char(963),'2 2nd component'];
    info.parameters(5).range = [0.1 5];
    info.parameters(5).default = 0.7;
    info.parameters(5).units = 'nm';
    
    output = info;
    return;
end

% If user passes them, check that the number of parameters matches the model
if length(param)~=nParam
    error('The number of input parameters does not match the number of model parameters.')
end

% Parse input
validateattributes(r,{'numeric'},{'nonnegative','increasing','nonempty'},mfilename,'r')

% Compute non-central chi distribution with 3 degrees of freedom (a 3D Rician)
nu = param([1 4]);
sig = param([2 5]);
a = param(3);
a(2) = max(1-a,0);

P = multirice3d(r,nu,sig,a);

if ~all(P==0)
    P = P/sum(P)/mean(diff(r));
end

output = P;

return
