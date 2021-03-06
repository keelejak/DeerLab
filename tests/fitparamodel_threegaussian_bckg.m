function [pass,maxerr] = test(opt)

% Test a distance-domain fit of a three gauss model with background

rng(1)
t = linspace(0,3,200);
r = linspace(1,5,150);
parIn = [2.5 0.5 0.4 4 0.5 0.3 3 0.2];
P = dd_gauss3(r,parIn);
B = bg_exp(t,0.15);
lam = 0.5;
V = dipolarsignal(t,r,P,lam,B);
KB = dipolarkernel(t,r,lam,B);
par0 = [2 0.3 0.5 4 0.1 0.1 1 0.2];

[~,Pfit] = fitparamodel(V,@dd_gauss3,r,KB,par0);

%Pass: distance distribution is well fitted
pass = all(abs(Pfit - P) < 2e-4);

maxerr = max(abs(Pfit - P));

if opt.Display
   plot(r,P,'k',r,Pfit,'r')
   legend('truth','fit')
   xlabel('r [nm]')
   ylabel('P(r) [nm^{-1}]')
   grid on, axis tight, box on
end


end