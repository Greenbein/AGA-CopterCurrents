function UI_CopterCurrents()
% UI_CopterCurrents
% Interactive launcher for CopterCurrents processing (thin facade).
%
%   - Constants: get_ui_pipeline_config.m
%   - Dialogs / cache / IO: ./ui_private/*.m

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'ui_private'));

clearvars -except ans;
close all;

matlab_root = get_matlab_root();
cfg         = get_ui_pipeline_config(matlab_root);

video_fname = prompt_video_file(matlab_root);
if isempty(video_fname)
    disp('UI_CopterCurrents: cancelled by user.');
    return;
end

[fit_method, algorithm_name] = prompt_algorithm();
if isempty(algorithm_name)
    disp('UI_CopterCurrents: cancelled by user.');
    return;
end

% ---------------- GPU SELECTION PROMPT ----------------
gpu_choice = questdlg('Do you want to use the GPU?', ...
    'GPU Mode Selection', ...
    'Yes (GPU)', 'No (CPU)', 'Cancel', 'Yes (GPU)');

if isempty(gpu_choice) || strcmp(gpu_choice, 'Cancel')
    disp('UI_CopterCurrents: cancelled by user.');
    return;
end

global USE_GPU_FLAG;
USE_GPU_FLAG = strcmp(gpu_choice, 'Yes (GPU)');
% ------------------------------------------------------

[base_results_dir, was_cancelled] = prompt_save_base_dir(video_fname, matlab_root);
if was_cancelled
    disp('UI_CopterCurrents: cancelled by user.');
    return;
end

[algo_results_dir, grid_dir, aga_dir, simple_dir] = prepare_results_folders(base_results_dir, fit_method);
georef_cache_file = fullfile(base_results_dir, 'georeference_cache.mat');
[force_rebuild_cache, was_cancelled_cache_mode] = prompt_cache_mode();
if was_cancelled_cache_mode
    disp('UI_CopterCurrents: cancelled by user.');
    return;
end

ui_print_run_summary(video_fname, algorithm_name, base_results_dir, grid_dir, aga_dir, simple_dir);
ui_validate_inputs(video_fname, cfg);

stage_times   = zeros(1, 5);
window_timing = struct();

[CamPos_ST, stage_times] = ui_step_01_camera_metadata(video_fname, stage_times, matlab_root);
[IMG_SEQ, stage_times]   = ui_step_02_georeference(video_fname, CamPos_ST, georef_cache_file, ...
    force_rebuild_cache, cfg, stage_times);
[STCFIT, stage_times]    = ui_step_03_stcfit(IMG_SEQ, base_results_dir, cfg, stage_times);
[STCFIT, window_timing, stage_times] = ui_step_04_fit(IMG_SEQ, STCFIT, fit_method, stage_times);
stage_times = ui_step_05_maps_and_velocity_save(STCFIT, algo_results_dir, cfg, stage_times);

% Optional: timing file for compare_algorithms.m (uncomment when needed):
% save(fullfile(algo_results_dir, 'processing_output.mat'), ...
%     'stage_times', 'window_timing', 'algorithm_name');

stage_names = {'Config', 'Georeference', 'Grid Setup', 'Fit Algorithm', 'Save Results'};
[h_stage, h_window] = print_time_graphs(stage_names, stage_times, window_timing);
save_timing_results(h_stage, h_window, stage_names, stage_times, window_timing, algo_results_dir);

msgbox(sprintf(['Done!\nAlgorithm: %s\nSaved to:\n%s'], algorithm_name, algo_results_dir), ...
    'UI_CopterCurrents', 'help');
end
