%
% BG_POLY1 Polynomial 1st-order background model
%
%   info = BG_POLY1
%   Returns an (info) structure containing the specifics of the model.
%
%   B = BG_POLY1(t,param)
%   B = BG_POLY1(t,param,lambda)
%   Computes the N-point model (B) from the N-point time axis (t) according to
%   the paramteres array (param). The required parameters can also be found
%   in the (info) structure. The pathway amplitude (lambda) can be
%   included, if not given the default lambda=1 will be used.
%
% PARAMETERS
% name    symbol default lower bound upper bound
% ------------------------------------------------------------------
% PARAM(1)  p0     1        0            200        Intercept
% PARAM(2)  p1     -1     -200           200        1st order weight
% ------------------------------------------------------------------
%

% This file is a part of DeerLab. License is MIT (see LICENSE.md). 
% Copyright(c) 2019-2020: Luis Fabregas, Stefan Stoll and other contributors.



function output = bg_poly1(t,param,lambda)

nParam = 2;

if all(nargin~=[0 2 3])
    error('Model requires at least two input arguments.')
end

if nargin==0
    %If no inputs given, return info about the parametric model
    info.model  = 'Polynomial 1st order';
    info.nparam  = nParam;
    info.parameters(1).name = 'intercept p0';
    info.parameters(1).range = [0 200];
    info.parameters(1).default = 1;
    info.parameters(1).units = ' ';
    
    info.parameters(2).name = 'slope p1';
    info.parameters(2).range = [-200 200];
    info.parameters(2).default = -1;
    info.parameters(2).units = 'us^-1';
    
    output = info;
    return
end

if nargin<3
    lambda = 1;
end

% If user passes them, check that the number of parameters matches the model
if length(param)~=nParam
    error('The number of input parameters does not match the number of model parameters.')
end

% If necessary inputs given, compute the model distance distribution
p = fliplr(param);
B = polyval(lambda*p,abs(t));
B = B(:);
output = B;


return