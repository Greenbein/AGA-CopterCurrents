function ui_print_run_summary(video_fname, algorithm_name, base_results_dir, grid_dir, aga_dir, simple_dir)
% UI_PRINT_RUN_SUMMARY  Echo user selections after dialogs.
    fprintf('Selected video: %s\n', video_fname);
    fprintf('Selected algorithm: %s\n', algorithm_name);
    fprintf('Results root: %s\n', base_results_dir);
    fprintf('Grid folder: %s\n', grid_dir);
    fprintf('Adaptive folder: %s\n', aga_dir);
    fprintf('Simple GA folder: %s\n', simple_dir);
end
