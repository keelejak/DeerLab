function [pass,maxerr] = test(opt)

% Test selregparam with Tikhonov regularization using all selection 
% functionals and the golden search algorithm

t = linspace(0,3,200);
r = linspace(2,6,100);
P = dd_gauss(r,[3,0.5]);
K = dipolarkernel(t,r);
S = K*P;

alphaopt1 = selregparam(S,K,'tikhonov','all','NonNegConstrained',false,'NoiseLevel',0.05);
alphaopt2 = selregparam(S,K,'tikhonov',{'all'},'NonNegConstrained',false,'NoiseLevel',0.05);

%Accept testif all values are the same (should be as there is no noise)
pass(1) = length(alphaopt2) == 14;
pass(2) = length(alphaopt1) == 14;

pass = all(pass);

maxerr = NaN;


end