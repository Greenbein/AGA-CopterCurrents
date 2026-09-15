function compare_window_velocities()
    % compare_window_velocities
    % Standalone comparison of two algorithm runs reading from CSV files.
    % Generates a scatter plot comparison (Ux and Uy) for the poster.
    
    results_root = prompt_results_root();
    if isempty(results_root)
        disp('compare_window_velocities: cancelled by user.');
        return;
    end
    
    algo_list = discover_algo_folders_with_velocities(results_root);
    if numel(algo_list) < 2
        errordlg(['Need at least two subfolders that contain velocity CSV files.' newline ...
            'Root: ' results_root], 'compare_window_velocities');
        return;
    end
    
    algo1 = prompt_algorithm_choice(algo_list, 'Select FIRST algorithm (Y-axis)');
    if isempty(algo1)
        disp('compare_window_velocities: cancelled by user.');
        return;
    end
    
    remaining = algo_list(~strcmp(algo_list, algo1));
    algo2 = prompt_algorithm_choice(remaining, 'Select SECOND algorithm (X-axis)');
    if isempty(algo2)
        disp('compare_window_velocities: cancelled by user.');
        return;
    end
    
    algo1_dir = fullfile(results_root, algo1);
    algo2_dir = fullfile(results_root, algo2);
    
    % Load data robustly from CSV
    T1 = load_csv_velocities(algo1_dir);
    T2 = load_csv_velocities(algo2_dir);
    
    % Extract and align Ux and Uy arrays
    [x_ux, y_ux, x_uy, y_uy] = align_velocity_vectors(T1, T2);
    
    comparison_root = fullfile(results_root, 'comparison');
    pair_folder = fullfile(comparison_root, [algo1 '_vs_' algo2]);
    if exist(pair_folder, 'dir') ~= 7
        mkdir(pair_folder);
    end
    
    % Create a large, high-resolution figure with white background for the poster
    h_vel = figure('Name', 'Velocity Comparison (CSV)', ...
        'NumberTitle', 'off', 'Position', [100 100 1200 600], 'Color', 'w');
    
    plot_velocity_comparison(x_ux, y_ux, x_uy, y_uy, algo1, algo2);
    tighten_axes_inset(h_vel);
    
    save_path = fullfile(pair_folder, 'velocity_comparison.png');
    save_compare_figure(h_vel, save_path);
    
    msgbox(sprintf('Velocity comparison saved:\n%s', save_path), ...
        'compare_window_velocities', 'help');
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
        errordlg(['Folder not found: ' selected], 'compare_window_velocities');
        return;
    end
    results_root = selected;
    end
    
    function algo_list = discover_algo_folders_with_velocities(results_root)
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
        % Search for any CSV file containing "velocit" in its name
        csv_files = dir(fullfile(folder, '*velocit*.csv'));
        if ~isempty(csv_files)
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
        'Name', 'compare_window_velocities', ...
        'ListSize', [360, 180]);
    if ~ok
        return;
    end
    algo_name = algo_list{idx};
    end
    
    function data_table = load_csv_velocities(algo_dir)
    % Find the velocity CSV file
    csv_files = dir(fullfile(algo_dir, '*velocit*.csv'));
    if isempty(csv_files)
        error('Missing velocity CSV in %s', algo_dir);
    end
    csv_path = fullfile(algo_dir, csv_files(1).name);
    
    % Robust reading: force comma delimiter, preserve original headers
    opts = detectImportOptions(csv_path);
    opts.Delimiter = ',';
    opts.VariableNamingRule = 'preserve';
    data_table = readtable(csv_path, opts);
    end
    
    function [x_ux, y_ux, x_uy, y_uy] = align_velocity_vectors(T1, T2)
    % Dynamically find the Ux and Uy columns by name
    names1 = T1.Properties.VariableNames;
    idx_ux1 = find(contains(names1, 'Ux', 'IgnoreCase', true), 1);
    idx_uy1 = find(contains(names1, 'Uy', 'IgnoreCase', true), 1);
    
    names2 = T2.Properties.VariableNames;
    idx_ux2 = find(contains(names2, 'Ux', 'IgnoreCase', true), 1);
    idx_uy2 = find(contains(names2, 'Uy', 'IgnoreCase', true), 1);
    
    if isempty(idx_ux1) || isempty(idx_uy1)
        error('Could not find Ux or Uy columns in the first algorithm CSV.');
    end
    if isempty(idx_ux2) || isempty(idx_uy2)
        error('Could not find Ux or Uy columns in the second algorithm CSV.');
    end
    
    % Match length in case one algorithm processed fewer windows
    n = min(height(T1), height(T2));
    
    % Force numeric conversion (str2double) to bypass MATLAB string/cell quirks
    y_ux = str2double(string(T1{1:n, idx_ux1}));
    y_uy = str2double(string(T1{1:n, idx_uy1}));
    x_ux = str2double(string(T2{1:n, idx_ux2}));
    x_uy = str2double(string(T2{1:n, idx_uy2}));
    
    % Filter out any NaNs or missing data
    valid = isfinite(x_ux) & isfinite(y_ux) & isfinite(x_uy) & isfinite(y_uy);
    x_ux = x_ux(valid); 
    y_ux = y_ux(valid);
    x_uy = x_uy(valid); 
    y_uy = y_uy(valid);
    end
    
    function plot_velocity_comparison(x_ux, y_ux, x_uy, y_uy, algo1, algo2)
    % Clean underscores for nice plotting
    name1 = strrep(algo1, '_', ' ');
    name2 = strrep(algo2, '_', ' ');
    
    % UY COMPARISON
    subplot(1, 2, 1);
    scatter(x_uy, y_uy, 36, [0.15 0.45 0.95], 'filled', 'MarkerFaceAlpha', 0.75);
    hold on;
    plot_identity_line(x_uy, y_uy);
    grid on;
    xlabel(sprintf('%s Uy [m/s]', name2), 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k');
    ylabel(sprintf('%s Uy [m/s]', name1), 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k');
    title('Uy Comparison', 'FontSize', 14, 'Color', 'k', 'FontWeight', 'bold');
    apply_black_plot_style(gca);
    
    % UX COMPARISON
    subplot(1, 2, 2);
    scatter(x_ux, y_ux, 36, [0.15 0.45 0.95], 'filled', 'MarkerFaceAlpha', 0.75);
    hold on;
    plot_identity_line(x_ux, y_ux);
    grid on;
    xlabel(sprintf('%s Ux [m/s]', name2), 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k');
    ylabel(sprintf('%s Ux [m/s]', name1), 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k');
    title('Ux Comparison', 'FontSize', 14, 'Color', 'k', 'FontWeight', 'bold');
    apply_black_plot_style(gca);
    
    sgtitle('Velocity Similarity (Y: Algo 1, X: Algo 2)', ...
        'FontWeight', 'bold', 'FontSize', 16, 'Color', 'k');
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
    
    function plot_identity_line(x, y)
    v = [x(:); y(:)];
    v = v(isfinite(v));
    if isempty(v)
        lim = [-1 1];
    else
        mn = min(v);
        mx = max(v);
        if mn == mx
            mn = mn - 0.5;
            mx = mx + 0.5;
        end
        pad = 0.05 * (mx - mn);
        lim = [mn - pad, mx + pad];
    end
    plot(lim, lim, '--', 'Color', [0.3 0.3 0.3], 'LineWidth', 1.5);
    xlim(lim);
    ylim(lim);
    end
    
    function tighten_axes_inset(fig)
    if nargin < 1 || isempty(fig) || ~isgraphics(fig)
        return;
    end
    allAxes = findall(fig, 'Type', 'axes');
    for ii = 1:numel(allAxes)
        ax = allAxes(ii);
        if ~strcmpi(ax.Visible, 'on')
            continue;
        end
        try
            ti = get(ax, 'TightInset');
            set(ax, 'LooseInset', ti);
        catch
        end
    end
    end
    
    function save_compare_figure(fig, filepath)
    if nargin < 2 || isempty(filepath)
        return;
    end
    drawnow;
    try
        % Save in High Resolution (300 DPI) for the Figma Poster
        exportgraphics(fig, filepath, 'Resolution', 300);
    catch
        saveas(fig, filepath); % Fallback
    end
    end