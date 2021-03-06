%
% DD_SPHERESURF  Particles distributed on a sphere's surface
%
%   info = DD_SPHERESURF
%   Returns an (info) structure containing the specifics of the model.
%
%   P = DD_SPHERESURF(r,param)
%   Computes the N-point model (P) from the N-point distance axis (r) according to 
%   the paramteres array (param). The required parameters can also be found 
%   in the (info) structure.
%
% PARAMETERS
% name    symbol default lower bound upper bound
% --------------------------------------------------------------------------
% param(1)   R    2.5       0.1         20         sphere radius
% --------------------------------------------------------------------------
%
%   See: D.R. Kattnig, D. Hinderberger, Journal of Magnetic Resonance, 230 (2013), 50-63 
%        http://doi.org/10.1016/j.jmr.2013.01.007
%

% This file is a part of DeerLab. License is MIT (see LICENSE.md). 
% Copyright(c) 2019-2020: Luis Fabregas, Stefan Stoll and other contributors.


function output = dd_spheresurf(r,param)

nParam = 1;

if nargin~=0 && nargin~=2 
    error('Model requires two input arguments.')
end

if nargin==0
    %If no inputs given, return info about the parametric model
    info.model  = 'Sphere Surface';
    info.nparam  = nParam;
    info.parameters(1).name = 'Sphere radius R';
    info.parameters(1).range = [0.1 20];
    info.parameters(1).default = 2.5;
    info.parameters(1).units = 'nm';
    
    output = info;
    return
end

% Assert that the number of parameters matches the model
if length(param)~=nParam
  error('The number of input parameters does not match the number of model parameters.')
end

%Parse input
validateattributes(r,{'numeric'},{'nonnegative','increasing','nonempty'},mfilename,'r')

% Compute the model distance distribution
R = param(1);
P = zeros(numel(r),1);
idx = r >= 0 & r<= 2*R;
P(idx) = r(idx)/R^2;

if ~all(P==0)
P = P/sum(P)/mean(diff(r));
end

output = P;

return