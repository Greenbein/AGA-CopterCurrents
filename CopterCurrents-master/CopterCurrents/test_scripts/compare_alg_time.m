function compare_alg_time()
    % compare_alg_time
    % Compares timing results between two algorithms using CSV files.
    % Generates per-window curves and an overlaid bar chart for stages.
    
    results_root = prompt_results_root();
    if isempty(results_root)
        disp('compare_alg_time: cancelled by user.');
        return;
    end
    
    algo_list = discover_algo_folders_with_timing(results_root);
    if numel(algo_list) < 2
        errordlg(['Need at least two subfolders that contain timing CSV files.' newline ...
            'Root: ' results_root], 'compare_alg_time');
        return;
    end
    
    algo1 = prompt_algorithm_choice(algo_list, 'Select FIRST algorithm');
    if isempty(algo1)
        disp('compare_alg_time: cancelled by user.');
        return;
    end
    
    remaining = algo_list(~strcmp(algo_list, algo1));
    algo2 = prompt_algorithm_choice(remaining, 'Select SECOND algorithm');
    if isempty(algo2)
        disp('compare_alg_time: cancelled by user.');
        return;
    end
    
    algo1_dir = fullfile(results_root, algo1);
    algo2_dir = fullfile(results_root, algo2);
    
    % Load timing data robustly from CSVs using comma delimiter
    [W1, S1] = load_algo_timings(algo1_dir);
    [W2, S2] = load_algo_timings(algo2_dir);
    
    % Create pair folder for saving comparison results
    comparison_root = fullfile(results_root, 'comparison');
    pair_folder = fullfile(comparison_root, [algo1 '_vs_' algo2]);
    if exist(pair_folder, 'dir') ~= 7
        mkdir(pair_folder);
    end
    
    % Clean names for labels and titles
    name1 = strrep(algo1, '_', ' ');
    name2 = strrep(algo2, '_', ' ');
    
    % =========================================================================
    % 1. PER-WINDOW TIMING COMPARISON (4 SUBPLOTS, LINES)
    % =========================================================================
    h_win = figure('Name', 'Per-Window Timing Comparison', ...
        'NumberTitle', 'off', 'Position', [100 100 1200 900], 'Color', 'w');
    
    n_win = min(height(W1), height(W2));
    x_win = str2double(string(W1{1:n_win, 1}));
    
    % Operation labels corresponding to columns 2 to 5
    op_titles = {'Per-window cut time', 'Per-window spectrum time', 'Per-window fit time', 'Per-window total time'};
    
    for i = 1:4
        subplot(4, 1, i);
        
        % Force numeric conversion to avoid any cell/string issues
        y1 = str2double(string(W1{1:n_win, i+1}));
        y2 = str2double(string(W2{1:n_win, i+1}));
        
        % Determine which algorithm is faster for this specific operation
        mean1 = mean(y1, 'omitnan');
        mean2 = mean(y2, 'omitnan');
        
        if mean1 <= mean2
            % algo1 is faster (Blue), algo2 is slower (Red)
            plot(x_win, y2, 'Color', [0.9 0.2 0.2], 'LineWidth', 1.5); % Slower first
            hold on;
            plot(x_win, y1, 'Color', [0.15 0.45 0.95], 'LineWidth', 1.5); % Faster on top
            lgd = legend(name2, name1, 'Location', 'best');
        else
            % algo2 is faster (Blue), algo1 is slower (Red)
            plot(x_win, y1, 'Color', [0.9 0.2 0.2], 'LineWidth', 1.5); % Slower first
            hold on;
            plot(x_win, y2, 'Color', [0.15 0.45 0.95], 'LineWidth', 1.5); % Faster on top
            lgd = legend(name1, name2, 'Location', 'best');
        end
        
        grid on;
        title(sprintf('%s: %s vs %s per cell', op_titles{i}, name1, name2), ...
            'Color', 'k', 'FontWeight', 'bold');
        ylabel('Time [s]', 'Color', 'k', 'FontWeight', 'bold');
        if i == 4
            xlabel('Window index', 'Color', 'k', 'FontWeight', 'bold');
        end
        apply_black_plot_style(gca, lgd);
        xlim([1 max(1, max(x_win))]);
        
        % Dynamic scaling adjusted strictly to the maximum point of both curves
        max_val = max([max(y1), max(y2)]);
        if ~isnan(max_val) && max_val > 0
            ylim([0 max_val * 1.05]);
        end
    end
    
    % Save window timing graph in high resolution
    save_path_win = fullfile(pair_folder, 'per_window_timing_comparison.png');
    exportgraphics(h_win, save_path_win, 'Resolution', 300);
    disp(['Saved window comparison: ', save_path_win]);
    
    
    % =========================================================================
    % 2. STAGE TIMING COMPARISON (OVERLAID BARS)
    % =========================================================================
    h_stage = figure('Name', 'Pipeline Stage Timing Comparison', ...
        'NumberTitle', 'off', 'Position', [150, 150, 800, 600], 'Color', 'w');
    
    % Extract names and values
    stages_count = min(height(S1), height(S2));
    stage_names = string(S1{1:stages_count, 1});
    t1 = str2double(string(S1{1:stages_count, 2}));
    t2 = str2double(string(S2{1:stages_count, 2}));
    
    % Determine global faster/slower algorithm based on total pipeline time
    if sum(t1, 'omitnan') <= sum(t2, 'omitnan')
        % S1 is faster (Blue), S2 is slower (Red)
        bar(t2, 'FaceColor', [0.9 0.2 0.2], 'BarWidth', 0.8); % Slower drawn wide (Red)
        hold on;
        bar(t1, 'FaceColor', [0.15 0.45 0.95], 'BarWidth', 0.5); % Faster drawn narrow (Blue overlay)
        lgd = legend(name2, name1, 'Location', 'best');
        max_scale = max(t2);
    else
        % S2 is faster (Blue), S1 is slower (Red)
        bar(t1, 'FaceColor', [0.9 0.2 0.2], 'BarWidth', 0.8); % Slower drawn wide (Red)
        hold on;
        bar(t2, 'FaceColor', [0.15 0.45 0.95], 'BarWidth', 0.5); % Faster drawn narrow (Blue overlay)
        lgd = legend(name1, name2, 'Location', 'best');
        max_scale = max(t1);
    end
    
    grid on;
    ylabel('Time [s]', 'Color', 'k', 'FontWeight', 'bold');
    title(sprintf('Pipeline Stage Comparison: %s vs %s', name1, name2), ...
        'Color', 'k', 'FontWeight', 'bold');
    apply_black_plot_style(gca, lgd);
    xticks(1:stages_count);
    
    % Replace underscores with spaces for clean labels
    clean_stage_names = strrep(stage_names, '_', ' ');
    xticklabels(clean_stage_names);
    xtickangle(25);
    
    % Scale determined strictly by the maximum value of the slower algorithm
    if ~isnan(max_scale) && max_scale > 0
        ylim([0 max_scale * 1.1]);
    end
    
    % Save stage timing histogram in high resolution
    save_path_stage = fullfile(pair_folder, 'stage_timing_comparison.png');
    exportgraphics(h_stage, save_path_stage, 'Resolution', 300);
    disp(['Saved stage comparison: ', save_path_stage]);
    
    msgbox(sprintf('Timing comparison graphs saved successfully in:\n%s', pair_folder), ...
        'compare_alg_time', 'help');
    
    end
    
    %% --- Local helpers ---
    
    function results_root = prompt_results_root()
    results_root = '';
    selected = uigetdir(pwd, 'Select [video_name]_results folder');
    if isequal(selected, 0)
        answer = inputdlg({'Results folder full path:'}, ...
            'Manual results folder path', [1 80], {''});
        if isempty(answer) || isempty(strtrim(answer{1}))
            return;
        end
        selected = strtrim(answer{1});
    end
    if exist(selected, 'dir') ~= 7
        errordlg(['Folder not found: ' selected], 'compare_alg_time');
        return;
    end
    results_root = selected;
    end
    
    function algo_list = discover_algo_folders_with_timing(results_root)
    algo_list = {};
    entries = dir(results_root);
    for i = 1:numel(entries)
        if ~entries(i).isdir
            continue;
        end
        name = entries(i).name;
        if strcmp(name, '.') || strcmp(name, '..') || strcmpi(name, 'comparison')
            continue;
        end
        folder = fullfile(results_root, name);
        
        % Verify that both core timing CSV files exist in the subdirectory
        has_win = ~isempty(dir(fullfile(folder, 'per_window_timing.csv')));
        has_stage = ~isempty(dir(fullfile(folder, 'stage_timing.csv')));
        
        if has_win && has_stage
            algo_list{end+1} = name; %#ok<AGROW>
        end
    end
    algo_list = sort(algo_list);
    end
    
    function algo_name = prompt_algorithm_choice(algo_list, prompt_text)
    algo_name = '';
    [idx, ok] = listdlg('PromptString', prompt_text, ...
        'SelectionMode', 'single', ...
        'ListString', algo_list, ...
        'Name', 'compare_alg_time', ...
        'ListSize', [360, 180]);
    if ~ok
        return;
    end
    algo_name = algo_list{idx};
    end
    
    function apply_black_plot_style(ax, lgd)
    set(ax, 'Color', 'w');
    ax.XColor = 'k';
    ax.YColor = 'k';
    ax.GridColor = 'k';
    ax.GridAlpha = 0.3;
    if nargin >= 2 && ~isempty(lgd)
        set(lgd, 'Color', 'w', 'EdgeColor', 'k', 'TextColor', 'k');
    end
    end
    
    function [W, S] = load_algo_timings(algo_dir)
    win_path = fullfile(algo_dir, 'per_window_timing.csv');
    stage_path = fullfile(algo_dir, 'stage_timing.csv');
    
    % Load Window Timing Table with comma forced
    try
        T = readtable(win_path, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
        W = T;
    catch ME
        error('Error reading window timing CSV in %s: %s', algo_dir, ME.message);
    end
    
    % Load Stage Timing Table with comma forced
    try
        T_s = readtable(stage_path, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
        S = T_s;
    catch ME
        error('Error reading stage timing CSV in %s: %s', algo_dir, ME.message);
    end
end