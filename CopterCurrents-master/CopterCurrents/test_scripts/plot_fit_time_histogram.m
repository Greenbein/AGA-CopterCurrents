function plot_fit_time_histogram()
    % Prompts user for a CSV file and plots a bar chart comparing fit times.
    % The CSV must contain columns: FileName, AgaFitTime, GsFitTime.
    
    % 1. Open file dialog
    [file, path] = uigetfile('*.csv', 'Select CSV file with Fit Times');
    if isequal(file, 0)
        disp('Cancelled by user.');
        return;
    end
    
    full_path = fullfile(path, file);
    disp(['Reading file: ', full_path]);
    
    % 2. Read table
    opts = detectImportOptions(full_path);
    opts.VariableNamingRule = 'preserve'; % Preserve exact column names
    T = readtable(full_path, opts);
    
    headers = T.Properties.VariableNames;
    
    % Find column indices (case-insensitive to be safe)
    idx_name = find(strcmpi(headers, 'FileName'), 1);
    idx_aga = find(strcmpi(headers, 'AgaFitTime'), 1);
    idx_gs = find(strcmpi(headers, 'GsFitTime'), 1);
    
    if isempty(idx_name) || isempty(idx_aga) || isempty(idx_gs)
        error('The CSV must contain "FileName", "AgaFitTime", and "GsFitTime" columns.');
    end
    
    % 3. Extract data
    file_names = string(T{:, idx_name});
    aga_time = str2double(string(T{:, idx_aga}));
    gs_time = str2double(string(T{:, idx_gs}));
    
    % Remove rows with NaN (if any processing failed)
    valid_idx = isfinite(aga_time) & isfinite(gs_time);
    aga_time = aga_time(valid_idx);
    gs_time = gs_time(valid_idx);
    file_names = file_names(valid_idx);
    
    % Clean up filenames for cleaner x-axis labels
    file_names_clean = strrep(file_names, '_', ' ');
    file_names_clean = strrep(file_names_clean, '.MP4', '');
    file_names_clean = strrep(file_names_clean, 'DJI', '');
    
    n_videos = length(file_names_clean);
    if n_videos == 0
        disp('No valid data points found to plot.');
        return;
    end
    
    x = 1:n_videos;
    
    % 4. Create Figure (maximized, white background)
    fig = figure('Name', 'Fit Time Histogram', 'Units', 'normalized', 'Position', [0 0 1 1], 'Color', 'w');
    
    % Plot Grid Search first (Red, wider, background)
    color_gs = [0.9 0.2 0.2];
    b_gs = bar(x, gs_time, 0.6, 'FaceColor', color_gs, 'EdgeColor', 'k', 'LineWidth', 1);
    hold on;
    
    % Plot Adaptive GA second (Blue, narrower, foreground)
    color_aga = [0.15 0.45 0.95];
    b_aga = bar(x, aga_time, 0.3, 'FaceColor', color_aga, 'EdgeColor', 'k', 'LineWidth', 1);
    
    % 5. Formatting
    grid on;
    
    % Set axes colors and transparency
    ax = gca;
    ax.Color = 'w';
    ax.XColor = 'k';
    ax.YColor = 'k';
    ax.GridColor = 'k';
    ax.GridAlpha = 0.15;
    
    % X-axis ticks and labels
    xticks(x);
    xticklabels(file_names_clean);
    xtickangle(45);
    
    % Y-axis limits (Scale determined by max time)
    max_time = max([max(aga_time), max(gs_time)]);
    ylim([0, max_time * 1.1]);
    
    % Labels and Title
    ylabel('Current Fitting Time [seconds]', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k');
    title('Current Fitting Time Comparison: Adaptive GA vs Grid Search', 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'k');
    
    % Legend (White background, black text)
    lgd = legend([b_aga, b_gs], {'Adaptive GA', 'Grid Search'}, 'Location', 'northeast', 'FontSize', 12);
    set(lgd, 'Color', 'w', 'EdgeColor', 'k', 'TextColor', 'k');
    
    % 6. Export to PNG
    [~, name, ~] = fileparts(file);
    output_png = fullfile(path, [name, '_histogram.png']);
    exportgraphics(fig, output_png, 'Resolution', 300);
    
    disp(['Processing complete! Histogram saved to: ', output_png]);
end
