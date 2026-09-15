function replot_time_graphs(results_dir)
% REPLOT_TIME_GRAPHS Re-draws and overwrites the timing graphs 
% (stage timing and window timing) using the existing CSV files.
%
% Usage:
%   replot_time_graphs() - Opens a dialog to select the results folder
%   replot_time_graphs('path/to/results') - Runs directly

    if nargin < 1 || isempty(results_dir)
        results_dir = uigetdir('', 'Select the Results Folder containing the timing CSVs');
        if isequal(results_dir, 0)
            disp('Cancelled by user.');
            return;
        end
    end
    
    stage_csv = fullfile(results_dir, 'stage_timing.csv');
    window_csv = fullfile(results_dir, 'per_window_timing.csv');
    
    if ~exist(stage_csv, 'file') || ~exist(window_csv, 'file')
        error('Cannot find stage_timing.csv or per_window_timing.csv in the selected folder.');
    end
    
    % --- 1. Load Stage Timing ---
    disp(['Reading ', stage_csv]);
    T_stage = readtable(stage_csv);
    stage_names = T_stage.Stage_Name;
    stage_times = T_stage.Time_Seconds;
    
    % Replot Stage Timing
    h_stage = figure('Name','CopterCurrents Stage Timing', ...
                     'NumberTitle','off', ...
                     'Position', [150, 150, 800, 600], 'Color', 'w');
    b = bar(stage_times);
    b.FaceColor = [0.15 0.45 0.95];
    grid on;
    
    ax = gca;
    ax.Color = 'w';
    ax.XColor = 'k';
    ax.YColor = 'k';
    ax.GridColor = 'k';
    ax.GridAlpha = 0.3;
    
    ylabel('Time [s]', 'Color', 'k', 'FontWeight', 'bold');
    title('Pipeline stage timing', 'Color', 'k', 'FontSize', 14);
    xticks(1:numel(stage_times));
    
    clean_names = strrep(string(stage_names), '_', ' ');
    xticklabels(clean_names);
    xtickangle(25);
    
    % Save Stage Timing
    stage_png = fullfile(results_dir, 'stage_timing.png');
    stage_fig = fullfile(results_dir, 'stage_timing.fig');
    exportgraphics(h_stage, stage_png, 'Resolution', 300);
    savefig(h_stage, stage_fig);
    disp(['Overwritten: ', stage_png]);
    
    % --- 2. Load Window Timing ---
    disp(['Reading ', window_csv]);
    T_window = readtable(window_csv);
    x = T_window.Window_Index;
    t_cut = T_window.Cut_Time_s;
    t_fft = T_window.FFT_Time_s;
    t_fit = T_window.Fit_Time_s;
    t_total = T_window.Total_Time_s;
    n_windows = length(x);
    
    % Replot Window Timing
    h_window = figure('Name','CopterCurrents Window Timing', ...
                      'NumberTitle','off', ...
                      'Position', [100, 100, 1200, 900], 'Color', 'w');
    
    subplot(4,1,1);
    plot(x, t_cut, 'LineWidth', 1.5, 'Color', [0.15 0.45 0.95]);
    grid on;
    ax = gca; ax.Color = 'w'; ax.XColor = 'k'; ax.YColor = 'k'; ax.GridColor = 'k'; ax.GridAlpha = 0.3;
    title('Per-window cut time', 'Color', 'k', 'FontWeight', 'bold');
    ylabel('Time [s]', 'Color', 'k', 'FontWeight', 'bold');
    xlim([1 max(1,n_windows)]);
    
    subplot(4,1,2);
    plot(x, t_fft, 'LineWidth', 1.5, 'Color', [0.15 0.45 0.95]);
    grid on;
    ax = gca; ax.Color = 'w'; ax.XColor = 'k'; ax.YColor = 'k'; ax.GridColor = 'k'; ax.GridAlpha = 0.3;
    title('Per-window spectrum time', 'Color', 'k', 'FontWeight', 'bold');
    ylabel('Time [s]', 'Color', 'k', 'FontWeight', 'bold');
    xlim([1 max(1,n_windows)]);
    
    subplot(4,1,3);
    plot(x, t_fit, 'LineWidth', 1.5, 'Color', [0.15 0.45 0.95]);
    grid on;
    ax = gca; ax.Color = 'w'; ax.XColor = 'k'; ax.YColor = 'k'; ax.GridColor = 'k'; ax.GridAlpha = 0.3;
    title('Per-window fit time', 'Color', 'k', 'FontWeight', 'bold');
    ylabel('Time [s]', 'Color', 'k', 'FontWeight', 'bold');
    xlim([1 max(1,n_windows)]);
    
    subplot(4,1,4);
    plot(x, t_total, 'LineWidth', 1.5, 'Color', [0.15 0.45 0.95]);
    grid on;
    ax = gca; ax.Color = 'w'; ax.XColor = 'k'; ax.YColor = 'k'; ax.GridColor = 'k'; ax.GridAlpha = 0.3;
    title('Per-window total time', 'Color', 'k', 'FontWeight', 'bold');
    ylabel('Time [s]', 'Color', 'k', 'FontWeight', 'bold');
    xlabel('Window index', 'Color', 'k', 'FontWeight', 'bold');
    xlim([1 max(1,n_windows)]);
    
    % Save Window Timing
    window_png = fullfile(results_dir, 'per_window_timing.png');
    window_fig = fullfile(results_dir, 'per_window_timing.fig');
    exportgraphics(h_window, window_png, 'Resolution', 300);
    savefig(h_window, window_fig);
    disp(['Overwritten: ', window_png]);
    
    disp('Done replotting!');
end