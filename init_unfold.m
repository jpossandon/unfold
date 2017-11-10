
fprintf('\nAdding toolboxes and subfolders to path... \n')

projectFolder  = fileparts(which('init_unfold.m'));
scriptDir = fullfile(projectFolder,'src');


addpath(genpath(scriptDir))
addpath(fullfile(projectFolder,'lib','erplab'))
addpath(fullfile(projectFolder,'lib','gramm'))
addpath(fullfile(projectFolder,'lib','lsmr'))
addpath(fullfile(projectFolder,'lib','luong_bruno'))
addpath(fullfile(projectFolder,'lib','ept_TFCE','TFCE','Dependencies'))
addpath(genpath(fullfile(projectFolder,'lib','eegvis','topo_butter')))

addpath(fullfile(projectFolder,'lib','glmnet_matlab'))

if ~exist('eeg_checkset','file')
    warning('EEGlab could not be found in your path. Please add it before you use this toolbox')
end
if ~exist('gramm','file')
  warning('gramm could not be found. Did you run "git submodule update --init" to initialize submodules?')
end
