%
% REGOPERATOR Compute discrete derivative regularization operators 
% 
%   L = REGOPERATOR(n,d)
%   Computes the discrete approximation L to the derivative operator 
%   of order d on a regular grid with n points, i.e. L is (n-d)-by-n. 
%
%   L = REGOPERATOR(r,d)
%   Computes the same as above, using the number of element in r as n.
%

% This file is a part of DeerLab. License is MIT (see LICENSE.md). 
% Copyright(c) 2019-2020: Luis Fabregas, Stefan Stoll and other contributors.


function L = regoperator(n,d)

if nargin~=2
    error('regoperator requires 2 input arguments: the dimension and the order.');
end

% Check arguments.
if numel(n)>1
  if isvector(n)
    n = numel(n);
  else
    error('The first input must be either a positive integer (n) or a vector (r).');
  end
end
if numel(d)~=1 || ~any(d==[0 1 2 3])
    error('The order d (2nd input argument) must be 0, 1, 2, or 3.');
end

% Compute L
switch d
    case 0
        L = eye(n);
    case 1
        L = diff(eye(n),1);
    case 2
        L = diff(eye(n),2);
    case 3
        L = diff(eye(n),3);
end

end
