function [h_stage, h_window] = print_time_graphs(stage_names,stage_times,window_timing)
%PRINT_TIME_GRAPHS Plot processing times for pipeline and windows.
%
% Inputs:
%   stage_names   : 1xN cell array with stage names
%   stage_times   : 1xN numeric array with elapsed time [s] per stage
%   window_timing : struct with per-window timing arrays:
%       - t_window_cut
%       - t_window_fft
%       - t_window_fit
%       - t_window_total

if nargin < 1 || isempty(stage_names)
    stage_names = {};
end
if nargin < 2 || isempty(stage_times)
    stage_times = [];
end
if nargin < 3 || isempty(window_timing)
    window_timing = struct();
end

h_stage = [];
h_window = [];

% ==========================================
% 1. STAGE TIMING GRAPH
% ==========================================
if ~isempty(stage_times)
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
    
    if ~isempty(stage_names)
        clean_names = strrep(string(stage_names), '_', ' ');
        xticklabels(clean_names);
        xtickangle(25);
    end
end

% ==========================================
% 2. WINDOW TIMING GRAPHS
% ==========================================
required_fields = {'t_window_cut','t_window_fft','t_window_fit','t_window_total'};
has_window_data = all(isfield(window_timing,required_fields));

if has_window_data
    n_windows = numel(window_timing.t_window_total);
    x = 1:n_windows;
    
    h_window = figure('Name','CopterCurrents Window Timing', ...
                      'NumberTitle','off', ...
                      'Position', [100, 100, 1200, 900], 'Color', 'w');
    
    subplot(4,1,1);
    plot(x,window_timing.t_window_cut,'LineWidth',1.5, 'Color', [0.15 0.45 0.95]);
    grid on;
    ax = gca; ax.Color = 'w'; ax.XColor = 'k'; ax.YColor = 'k'; ax.GridColor = 'k'; ax.GridAlpha = 0.3;
    title('Per-window cut time', 'Color', 'k', 'FontWeight', 'bold');
    ylabel('Time [s]', 'Color', 'k', 'FontWeight', 'bold');
    xlim([1 max(1,n_windows)]);
    
    subplot(4,1,2);
    plot(x,window_timing.t_window_fft,'LineWidth',1.5, 'Color', [0.15 0.45 0.95]);
    grid on;
    ax = gca; ax.Color = 'w'; ax.XColor = 'k'; ax.YColor = 'k'; ax.GridColor = 'k'; ax.GridAlpha = 0.3;
    title('Per-window spectrum time', 'Color', 'k', 'FontWeight', 'bold');
    ylabel('Time [s]', 'Color', 'k', 'FontWeight', 'bold');
    xlim([1 max(1,n_windows)]);
    
    subplot(4,1,3);
    plot(x,window_timing.t_window_fit,'LineWidth',1.5, 'Color', [0.15 0.45 0.95]);
    grid on;
    ax = gca; ax.Color = 'w'; ax.XColor = 'k'; ax.YColor = 'k'; ax.GridColor = 'k'; ax.GridAlpha = 0.3;
    title('Per-window fit time', 'Color', 'k', 'FontWeight', 'bold');
    ylabel('Time [s]', 'Color', 'k', 'FontWeight', 'bold');
    xlim([1 max(1,n_windows)]);
    
    subplot(4,1,4);
    plot(x,window_timing.t_window_total,'LineWidth',1.5, 'Color', [0.15 0.45 0.95]);
    grid on;
    ax = gca; ax.Color = 'w'; ax.XColor = 'k'; ax.YColor = 'k'; ax.GridColor = 'k'; ax.GridAlpha = 0.3;
    title('Per-window total time', 'Color', 'k', 'FontWeight', 'bold');
    ylabel('Time [s]', 'Color', 'k', 'FontWeight', 'bold');
    xlabel('Window index', 'Color', 'k', 'FontWeight', 'bold');
    xlim([1 max(1,n_windows)]);
end
end