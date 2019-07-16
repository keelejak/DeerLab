rmean=3.0;
sigr=0.5;
noise=0.01;
dens=0.6;
dim=2;
depth=0.3;
fname='gaussian_30_5_2D';

r=linspace(1.5,10,1000);
t=0:8:2400;
rarg=(r-rmean*ones(size(r)))/sigr;
distr=exp(-rarg.^2);
distr=0.01*distr/sum(distr);

deer=make_test_data(fname,r,distr,t,noise,dens,dim,depth);

figure(1); clf;
plot(r,distr,'b');
axis([1.5,8,-0.1*max(distr),1.1*max(distr)]);
axis off

figure(2); clf;
plot(t,deer,'k');