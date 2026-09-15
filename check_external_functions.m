%% Check presence of required external functions on MATLAB path

neededFuncs = { ...
    'ImageRectify_by_caltech_library_v2', ...
    'cmocean', ...
    'pmkmp', ...
    'freezeColors', ...
    'deg2utm' ...
};

fprintf('=== Checking required FUNCTIONS on MATLAB path ===\n');
for i = 1:numel(neededFuncs)
    name = neededFuncs{i};
    p = which(name);
    if isempty(p)
        fprintf('MISSING: %s (not found on path)\n', name);
    else
        fprintf('OK     : %s -> %s\n', name, p);
    end
end

%% Check presence of L2 optimization file (out_fit_L2.mat) for Flight 7, Video 0001, t5to35_sqsizeDefault

FlightNum = 7;
VidNum    = 1;
time_limits = [5 35];              
OutputSubFoldSuff = '_sqsizeDefault/';

FoldCCbase = 'C:/Users/lesha/Documents/MATLAB/CCAnalysis/';
OutputSubFoldBase = sprintf('Flight%d_Video%04d/t', FlightNum, VidNum);
FoldIn = [FoldCCbase, OutputSubFoldBase, ...
          num2str(time_limits(1)),'to',num2str(time_limits(2)), ...
          OutputSubFoldSuff];
FoldNewFit = [FoldIn, 'VelOptim2dFit/'];

l2file = fullfile(FoldNewFit, 'out_fit_L2.mat');

fprintf('\n=== Checking L2 optimization file ===\n');
if exist(l2file, 'file') == 2
    fprintf('OK     : %s\n', l2file);
else
    fprintf('MISSING: %s\n', l2file);
end