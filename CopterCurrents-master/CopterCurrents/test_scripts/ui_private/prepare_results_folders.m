function [algo_results_dir, grid_dir, aga_dir, simple_dir] = prepare_results_folders(base_results_dir, fit_method)
grid_dir = fullfile(base_results_dir, 'Grid_Search_results');
aga_dir = fullfile(base_results_dir, 'Adaptive_Gradient_Ascent_results');
simple_dir = fullfile(base_results_dir, 'Simple_Gradient_Ascent_results');

if exist(base_results_dir, 'dir') ~= 7
    mkdir(base_results_dir);
end
if exist(grid_dir, 'dir') ~= 7
    mkdir(grid_dir);
end
if exist(aga_dir, 'dir') ~= 7
    mkdir(aga_dir);
end
if exist(simple_dir, 'dir') ~= 7
    mkdir(simple_dir);
end

switch fit_method
    case 'adaptive_ga'
        algo_results_dir = aga_dir;
    case 'simple_ga'
        algo_results_dir = simple_dir;
    otherwise
        algo_results_dir = grid_dir;
end

reset_folder_contents(algo_results_dir);
end
