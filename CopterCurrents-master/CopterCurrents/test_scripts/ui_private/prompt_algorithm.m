function [fit_method, algorithm_name] = prompt_algorithm()
fit_method = '';
algorithm_name = '';
[idx, ok] = listdlg('PromptString', 'Select run_fit algorithm:', ...
    'SelectionMode', 'single', ...
    'ListString', {'Grid Search', 'Adaptive Gradient Ascent', 'Simple Gradient Ascent'}, ...
    'Name', 'UI_CopterCurrents', ...
    'ListSize', [280, 140]);
if ~ok
    return;
end

switch idx
    case 1
        fit_method = 'grid';
        algorithm_name = 'Grid Search';
    case 2
        fit_method = 'adaptive_ga';
        algorithm_name = 'Adaptive Gradient Ascent';
    otherwise
        fit_method = 'simple_ga';
        algorithm_name = 'Simple Gradient Ascent';
end
end
