function ufresult = uf_addmarginal(ufresult,varargin)
%% add the marginal of the other predictors (i.e. continuous & spline predictors) to the beta estimates
% Important: If dummy-coded (i.e. non-effect coded) predictors and
% interactions exist, they are NOT added to the marginal effect. I.e. the
% output of the method returns the average ERP evaluated at the average of
% all spline/continuous predictors. The categorical predictors are kept at
% their reference level (which is X = 0, so in the case of dummy coded this
% is the reference, in case of sum/contrast coding this is the mean of
% group means). Interactions are also ignored. This can potentially be
% problematic and you have to calculate the marginal for yourmodel by hand!
%
% Note: This calculates the marginal effect at mean (MEM), that is f(E(x)). In other
% words, it calculates the effect at the average of the continuous covariate. An 
% alternative would be to calculate the average marginal mean (AME) E(f(x)). In 
% other word, the average effect of the predictor over all continuous
% covariate values. The latter is not implemented.
%
% Arguments:
%   ufresult         unfold result structure generated by uf_condense()
%
% Optional arguments:
%   cfg.channel      (all) Calculate only for a subset of channels (numeric)
%   cfg.betaSetname  ("beta" = deconvolution model) string that indicates which unfold.(field) to use 
%                    (i.e. ufresult.beta for deconvolution vs. ufresult.beta_nodc for a massive univariate model)
%
% Example
% For instance the model 1 + cat(facA) + continuousB
%   has the betas: intercept, facA==1, continuousB-Slope
%
% The beta output of uf_condense(uf_glmfit) mean the following:
%   intercept: response with facA = 0 and continuousB = 0
%   facA==1  : differential effect of facA == 1 (against facA==0)
%   continuousB-slope: the slope of continous B
%
% Using uf_predictContinuous(), we evaluate the continuous predictor at [0 50 100]
% The beta output of uf_predictContinuous then mean the following:
%   intercept: same as before
%   facA==1  : same as before
%   continuousB@0  : the differential effect if continuous B is 0 
%   continuousB@50 : the differential effect if continuous B is 50
%   continuousB@100: the differential effect if continuous B is 100
%
% Using uf_addmarginal(), the average response is added to all predictors:
%
%   intercept: the response of facA==0 AND continuousB@mean(continuousB)
%   intercept: the response of facA==1 AND continuousB@mean(continuousB)
%   continuousB@0  : the response of facA==0 if continuous B is 0 
%   continuousB@50 : the response of facA==0 if continuous B is 50
%   continuousB@100: the response of facA==0 if continuous B is 100
%
% Note that mean(continuousB) does not need to be a number we evaluated in
% the uf_predictContinuous step

% parse inputs
cfg = finputcheck(varargin,...
    {'channel','integer',[],[]; ...
    'betaSetname','string','','' ...
    },'mode','ignore');

if(ischar(cfg)); error(cfg); end

% check whether the user tried to enter EEG.unfold directly into this 
% function (without running uf_condense() first)
if ~isfield(ufresult,'param') & isfield(ufresult,'unfold')
    error('\n%s(): You cannot directly enter the unfold output into this function - please run uf_condense() first', mfilename)
end

if any(strcmp({ufresult.param.type},'interaction'))
   warning('You included interactions. They are not accounted for in the marginal and the results might be missleading. betas of interactions are not included in what is added to the individual traces, this is equivalent to at least one of the predictors (of the interaction) being 0. Take this into account when interpreting your results.')
end

% In order to add the marginal, we need evaluated splines (uf_predictContinuous) first.
% Here we are looking for "spline_converted" or "continuous_converted" (in ufresult.param.type) 
% If any continuous predictors have not yet been evaluated, throw an error:
if any(strcmp({ufresult.param.type},'spline')) || any(strcmp({ufresult.param.type},'continous'))
    error('In order to add the marginals, you need to run uf_predictContinuous() first to evaluate the splines and continuous predictors at certain values');
end

% if no betaSetname was provided: apply uf_addmarginal() to all betas (recursive call)
if isempty(cfg.betaSetname)
    [betaSetname] = uf_unfoldbetaSetname(ufresult,varargin{:}); % get the appropriate field containing the betas
    
    % RECURSION ALERT!
    if length(betaSetname) > 1
        for b = betaSetname
            ufresult_tmp    = uf_addmarginal(ufresult,'betaSetname',b{1});
            ufresult.(b{1}) = ufresult_tmp.(b{1});
        end
        return
    else
        cfg.betaSetname = betaSetname{1};
    end
    % END OF RECURSION ALERT
end

fprintf('\n%s(): working on the data in the field \"%s\" \n',mfilename, cfg.betaSetname)

% determine number of channels
if isempty(cfg.channel)
    cfg.channel = 1:size(ufresult.(cfg.betaSetname),1);
end

paramEvents       = {ufresult.param.event}; 
paramNames        = {ufresult.param.name};  

% make copy ufresult_avg
fprintf('\nRe-running uf_condense() to recover unconverted splines\n')
ufresult_avg = uf_condense(ufresult); % re-genererate, (without "evaluated" predictors)
ufresult_avg = uf_predictContinuous(ufresult_avg,'auto_method','average'); % get mean of continuous/spline predictors

% find the unique events
uniqueParamEvents = ufresult.unfold.eventtypes;

%% go trough unique event types
for e = uniqueParamEvents%unique(paramEvents)
    
    % find indices where current event type (e.g., "123", "saccade", "fixation") exists in paramEvents
    % (note: this can be multiple times, one for each evaluated parameter)
    e_Idx = [];
    for cTest= 1:length(paramEvents)
        % if there are multiple eventmarking-events, we have to check all
        % of them
        % In principle we would like to do paramEvent{cTest} == e{1} but
        % because this is a test of cell array of strings to cell array of
        % strings, we need a workaround.
        tmp = cellfun(@(x)strcmp(x,paramEvents{cTest}),e{1},'UniformOutput',0);
        tmp = cat(1,tmp{:});
       if all(any(tmp,2))
           e_Idx = [e_Idx cTest];
       end
    end
        

    % I had this in here because if there is only one predictor for an
    % event, then there is nothing to to (e.g. y~1)
    %     if length(e_Idx) == 1
    %         continue 
    %     end
            
    % get the parameters associated with the current events
    eventParamNames = paramNames(e_Idx);
    
    % we have to do it only once per parameter, so if a parameter occurs
    % multiple times, we can add the same marginal

    for p = unique(eventParamNames)
        
        % Find the names & types of the other parameters
        currEvent       = e_Idx(strcmp(p,eventParamNames));
        otherEvents     = setdiff(e_Idx,currEvent);
        otherParamNames = unique(paramNames(otherEvents));
        

        % now we now over what which columns we have to average in
        % ufresult, but we want to average the response to the average
        % covariate in "ufresult_avg". Therefore we have to search for the
        % parameter there

        ufresultavg_ix  = [];
        for pOther = otherParamNames
            ufresultavg_ix(end+1) = find(strcmp(pOther{1},{ufresult_avg.param.name}));
        end
        

        % We don't want to add to any categorical predictors, they are
        % encoded as differences and adding the marginal should be left to
        % the user (this is inconsistent - but - I found it much more
        % helpful this way, we could add a flag).
        
        % don't do categorical
        removeix = strcmp('categorical',{ufresult_avg.param(ufresultavg_ix).type});            
        % and also don't do interaction (note thte removeix |  in the
        % beginning)
        removeix = removeix | strcmp('interaction',{ufresult_avg.param(ufresultavg_ix).type}); 
        
        % Don't use those
        ufresultavg_ix(removeix) = []; % remove
        
        % calculate the marginal over all other predictors
        average_otherEffects = squeeze(sum(ufresult_avg.(cfg.betaSetname)(cfg.channel,:,ufresultavg_ix),3));
        
        % add this marginal to the current predictor
        ufresult.(cfg.betaSetname)(cfg.channel,:,currEvent) = ufresult.(cfg.betaSetname)(cfg.channel,:,currEvent) + repmat(average_otherEffects,1,1,length(currEvent));
        
        tmp = {ufresult_avg.param.name};
        tmp = tmp(ufresultavg_ix);
        whichMarginalized = sprintf('%s,',tmp{:});
        fprintf('uf_addmarginal: Added to %s|%s the sum of the mean responses of predictors: %s|[%s] \n',strjoin(e{1},'+'),p{1},strjoin(e{1},'+'),whichMarginalized(1:end-1))
        
        
    end
end
