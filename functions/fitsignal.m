%
% FITSIGNAL  Fit model to dipolar time-domain trace
%
%   [Vfit,Pfit,Bfit,parfit,parci,stats] = FITSIGNAL(V,t,r,dd,bg,ex,par0)
%   __ = FITSIGNAL(V,t,r,dd,bg,ex)
%   __ = FITSIGNAL(V,t,r,dd,bg)
%   __ = FITSIGNAL(V,t,r,dd)
%   __ = FITSIGNAL(V,t,r)
%   __ = FITSIGNAL({V1,V2,__},{t1,t2,__},r,dd,{bg1,bg2,__},{ex1,ex2,__},par0)
%   __ = FITSIGNAL({V1,V2,__},{t1,t2,__},r,dd,{bg1,bg2,__},{ex1,ex2,__})
%   __ = FITSIGNAL({V1,V2,__},{t1,t2,__},r,dd,{bg1,bg2,__},ex)
%   __ = FITSIGNAL({V1,V2,__},{t1,t2,__},r,dd)
%   __ = FITSIGNAL({V1,V2,__},{t1,t2,__},r)
%   __ = FITSIGNAL(___,'Property',Values,___)
%
%   Fits a dipolar model to the experimental signal V with time axis t, using
%   distance axis r. The model is specified by the distance distribution (dd),
%   the background (bg), and the experiment (ex).
%
%   If multiple signals (V1,V2,...) and their corresponding time axes (t1,t2,...)
%   are given, they will be fitted globally with a single distance distribution (dd).
%   For each signal, a specific background (bg1,bg2,...) and experiment (ex1,ex2)
%   models can be assigned.
%
%   If the inputs signal(s) is not pre-processed, it will automatically
%   undergo phase-correction, zero-time and scale adjustment.
%
%   FITSIGNAL can handle both parametric and non-parametric distance
%   distribution models.
%
%  Input:
%    V      time-domain signal to fit (N-element vector)
%    t      time axis, in microseconds (N-element vector)
%    r      distance axis, in nanometers (M-element vector)
%    dd     distance distribution model (default 'P')
%           - 'P' to indicate parameter-free distribution
%           - function handle to parametric distribution model (e.g. @dd_gauss)
%           - 'none' to indicate no distribution, i.e. only background
%    bg     background model (default @bg_hom3d)
%           - function handle to parametric background model (e.g. @bg_hom3d)
%           - 'none' to indicate no background decay
%    ex     experiment model (default @ex_4pdeer)
%           - function handle to experiment model (e.g. @ex_4pdeer)
%           - 'none' to indicate simple dipolar oscillation (mod.depth = 1)
%    par0   starting parameters, 3-element cell array {par0_dd,par0_bd,par0_ex}
%           default: {[],[],[]} (automatic choice)
%
%  Output:
%    Vfit   fitted time-domain signal
%    Pfit   fitted distance distribution
%    Bfit   fitted background decay
%    parfit structure with fitted parameters
%           .dd  fitted parameters for distance distribution model
%           .bg  fitted parameters for background model
%           .ex  fitted parameters for experiment model
%    parci structure with confidence intervals for parameter, similar to parfit
%    stats goodness of fit statistical estimators, N-element structure array
%
%  Name-value pairs:
%
%   'Lower'         - Lower bounds for parameters, cell array {lb_dd,lb_bg,lb_ex}
%   'Upper'         - Upper bounds for parameters, cell array {ub_dd,ub_bg,ub_ex}
%   'TolFun'        - Optimizer function tolerance
%   'RegType'       - Regularization functional type ('tikh','tv','huber')
%   'RegParam'      - Regularization parameter selection ('lr','lc','cv','gcv',
%                     'rgcv','srgcv','aic','bic','aicc','rm','ee','ncp','gml','mcl')
%   'alphaOptThreshold' - relative parameter change threshold for reoptimizing
%                         the regularization parameter

% Example:
%    Vfit = fitsignal(Vexp,t,r,@dd_gauss,@bg_hom3d,@ex_4pdeer)
%

% This file is a part of DeerLab. License is MIT (see LICENSE.md).
% Copyright(c) 2019-2020: Luis Fabregas, Stefan Stoll and other contributors.

function [Vfit,Pfit,Bfit,parfit,parci,stats] = fitsignal(Vexp,t,r,dd_model,bg_model,ex_model,par0,varargin)

if nargin<3
    error('At least three inputs (V,t,r) must be specified.');
end

% Validation of Vexp, t, r
%-------------------------------------------------------------------------------
if ~iscell(Vexp)
    Vexp = {Vexp};
end
nSignals = numel(Vexp);
if ~iscell(t)
    t = {t};
end
if numel(t)~=nSignals
    error('The same number of signals V and time axes t must be provided.')
end
for i = 1:nSignals
    Vexp{i} = Vexp{i}(:);
    t{i} = t{i}(:);
    if numel(Vexp{i})~=numel(t{i})
        error('V{%i} and t{%i} must have the same number of elements.',i,i)
    end
    validateattributes(Vexp{i},{'numeric'},{'vector'},mfilename,'V (1st input)');
    validateattributes(t{i},{'numeric'},{'vector'},mfilename,'t (2nd input)');
    % If not pre-processed, do standard preprocessing steps
    if ~isreal(Vexp{i})
        Vexp{i} = correctphase(Vexp{i});
        t{i} = correctzerotime(Vexp{i},t{i});
        Vexp{i} = correctscale(Vexp{i},t{i});
    end
end
validateattributes(r,{'numeric'},{'vector'},mfilename,'r (3rd input)');


% Parse the optional parameters in varargin
%-------------------------------------------------------------------------------
optionalProperties = {'RegParam','RegType','alphaOptThreshold','TolFun','Lower','Upper'};
[regparam,regtype,alphaOptThreshold,TolFun,lb,ub] = parseoptional(optionalProperties,varargin);

if isempty(lb)
    lb = {[],[],[]};
end
validateattributes(lb,{'cell'},{'row'},mfilename,'Lower option');
if isempty(ub)
    ub = {[],[],[]};
end
validateattributes(ub,{'cell'},{'row'},mfilename,'Upper option');

if isempty(TolFun)
    TolFun = 1e-5;
else
    validateattributes(TolFun,{'numeric'},{'scalar','nonnegative'},mfilename,'TolFun option');
end

% Regularization settings
if isempty(regtype)
    regtype = 'tikh';
end
validateattributes(regtype,{'char'},{'nonempty'},mfilename,'RegType option');
regtype = validatestring(regtype,{'tikh','tv','huber'});

if isempty(regparam)
    regparam = 'aic';
end
if ischar(regparam)
    allowedMethodInputs = {'lr','lc','cv','gcv','rgcv','srgcv','aic','bic','aicc','rm','ee','ncp','gml','mcl'};
    validateattributes(regparam,{'char'},{'nonempty'},mfilename,'RegParam option');
    regparam = validatestring(regparam,allowedMethodInputs);
else
    validateattributes(regparam,{'numeric'},{'scalar','nonempty','nonnegative'},mfilename,'RegParam')
end

if isempty(alphaOptThreshold)
    alphaOptThreshold = 1e-3;
end
validateattributes(alphaOptThreshold,{'numeric'},{'scalar','nonnegative'},mfilename,'alphaOptThreshold option');

% Set defaults
if nargin<4, dd_model = 'P'; end
if nargin<5, bg_model = @bg_hom3d; end
if nargin<6, ex_model = @ex_4pdeer; end
if nargin<7, par0 = {[],[],[]}; end

calculateCI = nargout>=5 || nargout==0;
computeStats = nargout>4 || nargout==0;
verbose = 'off';

if ~isempty(par0)
    if ~iscell(par0) || numel(par0)~=3
        error('Initial parameters (7th input) must be a 3-element cell array.')
    end
end

% Get information about distance distribution parameters
%-------------------------------------------------------------------------------
par0_dd = [];
lower_dd = [];
upper_dd = [];
N_dd = 0;
includeForeground = true;
if isa(dd_model,'function_handle')
    [par0_dd,lower_dd,upper_dd,N_dd] = getmodelparams(dd_model);
    parfreeDistribution = false;
elseif ischar(dd_model) && strcmp(dd_model,'P')
    parfreeDistribution = true;
elseif ischar(dd_model) && strcmp(dd_model,'none')
    includeForeground = false;
    parfreeDistribution = false;
else
    error('Distribution model (4th input) must either be a function handle, ''P'', or ''none''.')
end

% Get information about background parameters
%-------------------------------------------------------------------------------
par0_bg = cell(1,nSignals);
lower_bg = cell(1,nSignals);
upper_bg = cell(1,nSignals);
N_bg = zeros(nSignals,1);
if ~iscell(bg_model)
    bg_model = {bg_model};
end
if numel(bg_model)~=nSignals
    bg_model = repmat(bg_model,nSignals,1);
end
includeBackground = NaN(nSignals,1);
for i = 1:nSignals
    includeBackground(i) = true;
    if isa(bg_model{i},'function_handle')
        [par0_bg{i},lower_bg{i},upper_bg{i},N_bg(i)] = getmodelparams(bg_model{i});
    elseif ischar(bg_model{i}) && strcmp(bg_model{i},'none')
        includeBackground(i) = false;
    else
        error('Background model (5th input) must either be a function handle, or ''none''.')
    end
end

% Get information about experiment parameters
%-------------------------------------------------------------------------------
par0_ex = cell(1,nSignals);
lower_ex = cell(1,nSignals);
upper_ex = cell(1,nSignals);
N_ex = zeros(nSignals,1);
if ~iscell(ex_model)
    ex_model = {ex_model};
end
if numel(ex_model)~=nSignals
    ex_model = repmat(ex_model,nSignals,1);
end
includeExperiment = NaN(nSignals,1);
for i = 1:nSignals
    includeExperiment(i) = true;
    if isa(ex_model{i},'function_handle')
        [par0_ex{i},lower_ex{i},upper_ex{i},N_ex(i)] = getmodelparams(ex_model{i},t{i});
    elseif ischar(ex_model{i}) && strcmp(ex_model{i},'none')
        includeExperiment(i) = false;
    else
        error('Experiment models must either be a function handle, or ''none''.')
    end
end

% Catch nonsensical situation
if any(~includeForeground & ~includeBackground)
    error('Cannot fit anything without distribution model and without background model.')
end

% Combine all initial, lower and upper bounds of parameters into vectors
par0 = parcombine(par0,{par0_dd,par0_bg,par0_ex});
lb = parcombine(lb,{lower_dd,lower_bg,lower_ex});
ub = parcombine(ub,{upper_dd,upper_bg,upper_ex});
nParams = numel(par0);
if numel(lb)~=nParams
    error('Lower bounds and initial values of parameters must have the same number of elements.');
end
if numel(ub)~=nParams
    error('Lower bounds and initial values of parameters must have the same number of elements.');
end
if any(lb>ub)
    error('Lower bounds cannot be larger than upper bounds.');
end
if any(lb>par0 | par0>ub)
    error('Inital values for parameters must lie between lower and upper bounds.');
end


% Build index vectors for accessing parameter subsets
ddidx = 1:N_dd;
bgidx = cell(nSignals,1);
exidx = cell(nSignals,1);
for i = 1:nSignals
    bgidx{i} = N_dd + sum(N_bg(1:i-1)) + (1:N_bg(i));
    exidx{i} = N_dd + sum(N_bg) + sum(N_ex(1:i-1)) + (1:N_ex(i));
end

% Generate K(theta) and B(theta) for the multi-pathway kernel and background
Bmodels = cell(nSignals,1);
Kmodels = cell(nSignals,1);
for j = 1:nSignals
    if includeBackground(j)
        Bfcn = @(t,lam,par) bg_model{j}(t,par,lam);
    else
        Bfcn = @(~,~,~) ones(numel(t{j}),1);
    end
    
    if includeExperiment(j)
        Exfcn = @(par)ex_model{j}(t{j},par);
        Bmodels{j} = @(par) dipolarbackground(t{j},Exfcn(par{1}),@(t,lam)Bfcn(t,lam,par{2}));
        Kmodels{j} = @(par) dipolarkernel(t{j},r,Exfcn(par{1}),@(t,lam)Bfcn(t,lam,par{2}));
    else
        Kmodels{j} = @(~) dipolarkernel(t{j},r);
        Bmodels{j} = @(par) Bfcn(t,1,par);
    end
end

% Perform fitting
%-------------------------------------------------------------------------------
RegularizationOnly = nParams==0;
if RegularizationOnly
    
    % Solve regularization only
    Ks = cell(nSignals,1);
    Vfit = cell(nSignals,1);
    Bfit = cell(nSignals,1);
    for i = 1:nSignals
        Ks{i} = Kmodels{i}([]);
    end
    Pfit = fitregmodel(Vexp,Ks,r,regtype,regparam,'Verbose',verbose);
    for i = 1:nSignals
        Vfit{i} = Ks{i}*Pfit;
        Bfit{i} = ones(size(Vexp{i}));
    end
    parfit_ = [];
    parci_ = [];
    
else
    
    % Keep track of alpha and parameter vector across iterations, to avoid
    % doing alpha optimizations if parameter vector doesn't change much
    par_prev = [];
    regparam_prev = [];
    
    % Create some containers to cache variables not changing between
    % different signals in global fitting
    P_cached = [];
    K_cached = [];
    B_cached = [];
    
    % Fit the parameters
    args = {Vexp,@Vmodel,t,par0,'Lower',lb,'Upper',ub,'TolFun',TolFun,'Verbose',verbose};
    [parfit_] = fitparamodel(args{:});
    
    
    % Calculate the fitted signal, background, and distribution
    alpha = regparam; % use original setting for final run
    for i = 1:nSignals
        [Vfit{i},Bfit{i},Pfit] = Vmodel([],parfit_,i);
    end
    
    if calculateCI
        Weights = globalweights(Vexp);
        covmatrix = 0;
        
        % Compute the jacobian of the signal fit with respect to parameter set
        for i = 1:nSignals
            
            if parfreeDistribution
                % Mixed signal - augmented Jacobian
                L = regoperator(r,2);
                Kmod = @(par)Kmodels{i}({par(exidx{i}),par(bgidx{i})});
                J = [jacobianest(@(p)Kmod(p)*Pfit,parfit_), Kmod(parfit_);
                    zeros(size(L,1),numel(parfit_)), regparam_prev*L];
                subidx_P = numel(parfit_)+[1:numel(Pfit)];
                subidx_theta = 1:numel(parfit_);
            else
                % Full parametric signal - numerical Jacobian
                J = jacobianest(@(par)Vmodel([],par,i),parfit_);
            end
            
            % Suppress warnings for a moment
            warning('off','MATLAB:nearlySingularMatrix'), warning('off','MATLAB:singularMatrix')
            lastwarn('');
            
            % Estimate variance on experimental signal
            sigma2 = std(Vexp{i}-Vfit{i}).^2;
            
            % Estimate the covariance matrix by means of the inverse of Fisher information matrix
            covmatrix_ = sigma2.*inv(J.'*J);
            
            % Detect if there was a 'nearly singular' warning...
            [~, warnId] = lastwarn;
            if strcmp(warnId,'MATLAB:nearlySingularMatrix') || strcmp(warnId,'MATLAB:singularMatrix')
                % ...and if there was, then use a pseudoinverse instead of inverse
                covmatrix_ = sigma2.*sparse(pinv(full(J.'*J)));
                lastwarn('');
            end
            warning('on','MATLAB:nearlySingularMatrix'), warning('on','MATLAB:singularMatrix')
            
            % Combine covariance matrices from different signals
            covmatrix = covmatrix + Weights(i)*covmatrix_;
        end
        
        % Set significance level for confidence intervals
        ConfidenceLevel = [0.95 0.5];
        cov = 1 - ConfidenceLevel;
        p = 1 - cov/2; % percentile
        N = numel(Vexp{1}) - numel(parfit_); % degrees of freedom
        
        parci_ = cell(numel(p),1);
        z = zeros(numel(p),1);
        % Get the CI at requested confidence levels
        for jj = 1:numel(p)
            if parfreeDistribution
                % Get Gaussian critical value
                z(jj) = norm_inv(p(jj));

                % Compute (unconstrained) CI for parameters
                covmatsub = covmatrix(subidx_theta,subidx_theta);
                parci_{jj} = parfit_.' + z(jj)*sqrt(diag(covmatsub)).*[-1 +1];
                
                % Compute CI for parameter-free distribution
                covmatsub = covmatrix(subidx_P,subidx_P);
                PfitCI{jj}(:,1) = Pfit + z(jj)*sqrt(diag(covmatsub));
                PfitCI{jj}(:,2) = max(0,Pfit - z(jj)*sqrt(diag(covmatsub)));
            else
                % Get Student's t critical value
                z(jj) = t_inv(p(jj),N);
                
                % Compute (unconstrained) CI for parameters
                parci_{jj} = parfit_.' + z(jj)*sqrt(diag(covmatrix)).*[-1 +1];
            end
            % Constrain parameter CIs to model boundaries
            parci_{jj} = max(parci_{jj},lb.');
            parci_{jj} = min(parci_{jj},ub.');
        end
        parci_ = parci_{1};
        
        for idx = 1:nSignals
            %Propagate errors in the parameter sets to the signal model
            VfitCI{idx} = propagateCI(covmatrix,J,parfit_,Vfit{idx},z(1),t{idx});
        end
        if ~parfreeDistribution
            for i=1:numel(z)
                PfitCI{i} = max(propagateCI(covmatrix(ddidx,ddidx),dd_model,parfit_(ddidx),Pfit,z(i),r),0);
            end
        end
    else
        parci_ = [];
    end
end

% Calculate goodness of fit
%-------------------------------------------------------------------------------
if computeStats
    stats = cell(nSignals,1);
    for i = 1:nSignals
        Ndof = numel(Vexp{i}) - numel(parfit_);
        stats{i} = gof(Vexp{i},Vfit{i},Ndof);
    end
else
    stats = [];
end

% Return fitted parameters and confidence intervals in structures
%-------------------------------------------------------------------------------
parfit_ = parfit_(:);
parfit.dd = parfit_(ddidx);
for i = 1:nSignals
    parfit.bg{i} = parfit_(bgidx{i});
    parfit.ex{i} = parfit_(exidx{i});
end
if calculateCI
    parci.dd = parci_(ddidx,:);
    for i = 1:nSignals
        parci.bg{i} = parci_(bgidx{i},:);
        parci.ex{i} = parci_(exidx{i},:);
    end
end

% Plotting
%-------------------------------------------------------------------------------
if nargout==0
    for i = 1:nSignals
        subplot(2,nSignals,i);
        plot(t{i},Vexp{i},'k.',t{i},Vfit{i},'r','LineWidth',1.5)
        hold on
        fill([t{i}; flipud(t{i})],[VfitCI{i}(:,1); flipud(VfitCI{i}(:,2))],'r','LineStyle','none','FaceAlpha',0.4)
        hold off
        axis tight
        grid on
        xlabel('Time [\mus]');
        ylabel(sprintf('V\\{%d\\}',i));
        legend('Data','Fit','95%-CI');
    end
    subplot(2,1,2);
    plot(r,Pfit,'k','LineWidth',1.5);
    hold on
    fill([r fliplr(r)],[PfitCI{1}(:,1); flipud(PfitCI{1}(:,2))],'r','LineStyle','none','FaceAlpha',0.2)
    fill([r fliplr(r)],[PfitCI{2}(:,1); flipud(PfitCI{2}(:,2))],'r','LineStyle','none','FaceAlpha',0.5)
    hold off
    xlabel('Distance [nm]');
    ylabel('P [nm^{-1}]');
    legend('Fit','95%-CI','50%-CI')
    axis tight,grid on
    drawnow
    disp('Goodness of fit')
    for i=1:nSignals
        fprintf('  V{%i}: %s2 = %.4f  RMSD  = %.4f \n',i,char(hex2dec('3c7')),stats{i}.chi2red,stats{i}.RMSD)
    end
    disp('Fitted parameters and 95%-confidence intervals')
    str = '  %s{%d}(%d):   %.7f  (%.7f, %.7f)  %s (%s)\n';
    if numel(parfit.dd)>0
        info = dd_model();
        pars = info.parameters;
        for p = 1:numel(parfit.dd)
            c = parfit.dd(p);
            ci = parci.dd(p,:);
            fprintf(str,'dd',1,p,c,...
                ci(1),ci(2),pars(p).name,pars(p).units);
        end
    end
    if numel(parfit.bg)>0
        for i = 1:nSignals
            info = bg_model{i}();
            pars = info.parameters;
            for p = 1:numel(parfit.bg{i})
                c = parfit.bg{i}(p);
                ci = parci.bg{i}(p,:);
                fprintf(str,'bg',i,p,c,...
                    ci(1),ci(2),pars(p).name,pars(p).units)
            end
        end
    end
    if numel(parfit.ex)>0
        for i = 1:nSignals
            info = ex_model{i}(t{i});
            pars = info.parameters;
            for p = 1:numel(parfit.ex{i})
                c = parfit.ex{i}(p);
                ci = parci.ex{i}(p,:);
                fprintf(str,'ex',i,p,c,...
                    ci(1),ci(2),pars(p).name,pars(p).units)
            end
        end
    end
end

% Return numeric and not cell arrays if there is only one signal
if nSignals==1
    Vfit = Vfit{1};
    Bfit = Bfit{1};
    if iscell(parfit.dd)
        parfit.dd = parfit.dd{1};
    end
    if iscell(parfit.bg)
        parfit.bg = parfit.bg{1};
    end
    if iscell(parfit.ex)
        parfit.ex = parfit.ex{1};
    end
    if ~isempty(parci_)
        parci.bg = parci.bg{1};
        parci.ex = parci.ex{1};
    end
    if ~isempty(stats)
        stats = stats{1};
    end
end

%===============================================================================

% General multi-pathway DEER signal model function
    function [V,B,P] = Vmodel(~,par,idx)
        
        if nargin<3
            idx = 1;
        end
        % Calculate all K, all B, and P when called for first signal
        if idx==1
            for j = 1:nSignals
                % Calculate the background and the experiment kernel matrix
                K{j} = Kmodels{j}({par(exidx{j}),par(bgidx{j})});
                B{j} = Bmodels{j}({par(exidx{j}),par(bgidx{j})});
            end
            
            % Get the distance distribution
            if includeForeground && nargin<4
                
                % Use the alpha-search settings by default
                alpha = regparam;
                % If the parameter vectors has not changed by much...
                if ~isempty(par_prev)
                    if all(abs(par_prev-par)./par < alphaOptThreshold)
                        % ...use the alpha optimized in the previous iteration
                        alpha = regparam_prev;
                    end
                end
                par_prev = par;
                
                if parfreeDistribution
                    [P,~,regparam_prev] = fitregmodel(Vexp,K,r,regtype,alpha,'Verbose',verbose);
                else
                    P = dd_model(r,par(ddidx));
                end
            else
                P = zeros(numel(t),1);
            end
            K_cached = K;
            B_cached = B;
            P_cached = P;
        else
            % Compute the rest of the signals from the cached results
            K = K_cached;
            B = B_cached;
            P = P_cached;
        end
        
        % Compute the current signal
        if includeForeground
            V = K{idx}*P;
        else
            V = B{idx};
        end
        B = B{idx};
        
    end
end

%===============================================================================

function [par0,lo,up,N] = getmodelparams(model,t)

if contains(func2str(model),'ex_')
    info = model(t);
else
    info = model();
end
par0 = [info.parameters.default];
range = [info.parameters.range];
lo = range(1:2:end-1);
up = range(2:2:end);
N = numel(par0);

end

%===============================================================================

function modelFitCI = propagateCI(covmatrix,model,param,modelFit,z,ax)

if isnumeric(model)
    jacobian = model;
else
    jacobian = jacobianest(@(par)model(ax,par),param);
end
modelvariance = arrayfun(@(idx)full(jacobian(idx,:))*covmatrix*full(jacobian(idx,:)).',1:numel(ax)).';
upper = modelFit + z*sqrt(modelvariance);
lower = modelFit - z*sqrt(modelvariance);
modelFitCI = [upper lower];
end

%===============================================================================

function pvec = parcombine(p,def)
for k = 1:3
  if isempty(p{k}), p{k} = def{k}; end
  if iscell(p{k}), p{k} = cell2mat(p{k}); end
end
pvec = cell2mat(p);
end
