function [pass,maxerr] = test(opt)

% Check dimensionality, non-negativity, and values at boundaries of model

info = dd_gauss5();

r = linspace(0,50,500);
par0 = [info.parameters(:).default];
bounds = [info.parameters(:).range];
lower = bounds(1:2:end);
upper = bounds(2:2:end);

P1 = dd_gauss5(r,par0);
P2 = dd_gauss5(r.',par0);
P3 = dd_gauss5(r,lower);
P4 = dd_gauss5(r,upper);

% Pass 1: dimensionality is correct
pass(1) = isequal(P1,P2);
% Pass 2: non-negativity of default values fulfilled
pass(2) = all(P1 >= 0);
% Pass 3: non-negativity of default boundaries fulfilled
pass(3) = all(P1 >= 0) && all(P2 >= 0);
% Pass 4: there are no NaN values
pass(4) = all(~isnan(P1)) && all(~isnan(P2)) && all(~isnan(P3)) && all(~isnan(P4));

pass = all(pass);
 
maxerr = NaN;

end