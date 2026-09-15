function compare_aga_vs_adcp_full()
% Compares Adaptive GA and ADCP results across all processed videos.
% Generates line plots for velocity and angles, as well as a Scatter Plot.

    % 0. Ask user about wind impact
    wind_choice = questdlg('Select the data type for comparison:', ...
        'Wind Impact', ...
        'With wind impact', 'Without wind impact', 'Cancel', 'With wind impact');
        
    if isempty(wind_choice) || strcmp(wind_choice, 'Cancel')
        disp('Cancelled by user.');
        return;
    end
    
    is_with_wind = strcmp(wind_choice, 'With wind impact');
    
    % 1. Open file dialog
    [file, path] = uigetfile('*.csv', 'Select CSV file');
    if isequal(file, 0)
        disp('Cancelled by user.');
        return;
    end
    
    full_path = fullfile(path, file);
    disp(['Reading file: ', full_path]);
    
    % Create output directory for graphs based on user choice
    if is_with_wind
        output_dir = fullfile(path, 'ADCP_vs_algs_wind');
        adcp_legend_str = 'ADCP (Ground Truth + Wind)';
        adcp_label_str = 'ADCP Velocity (with Wind) [m/s]';
        wind_title_suffix = 'with wind';
        file_prefix = 'wind_';
    else
        output_dir = fullfile(path, 'ADCP_vs_algs_no_wind');
        adcp_legend_str = 'ADCP (Ground Truth)';
        adcp_label_str = 'ADCP Velocity [m/s]';
        wind_title_suffix = 'without wind';
        file_prefix = 'no_wind_';
    end
    
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    % Load table while preserving original column names
    opts = detectImportOptions(full_path);
    opts.VariableNamingRule = 'preserve';
    T = readtable(full_path, opts);
    headers = T.Properties.VariableNames;
    
    % 2. Dynamic column search (Ignoring Grid Search)
    file_names = T{:, 1}; % Assuming file names are in the first column
    if iscell(file_names) || isstring(file_names)
        file_names = string(file_names);
    else
        file_names = string(num2cell(1:height(T)));
    end
    
    % Clean up names for better labeling (remove '.MP4' and '_')
    file_names_clean = strrep(file_names, '_', ' ');
    file_names_clean = strrep(file_names_clean, '.MP4', '');
    file_names_clean = strrep(file_names_clean, 'DJI', '');
    
    idx_u_adcp = find(contains(headers, 'Mean|U|adcp', 'IgnoreCase', true), 1);
    idx_u_aga  = find(contains(headers, 'Mean|U|aga', 'IgnoreCase', true), 1);
    idx_ang_adcp = find(contains(headers, 'angleADCP', 'IgnoreCase', true), 1);
    idx_ang_aga  = find(contains(headers, 'angleAGA', 'IgnoreCase', true), 1);
    
    idx_u_gs   = find(contains(headers, 'Mean|U|gs', 'IgnoreCase', true), 1);
    idx_ang_gs   = find(contains(headers, 'angleGS', 'IgnoreCase', true), 1);
    
    if isempty(idx_u_adcp) || isempty(idx_u_aga) || isempty(idx_u_gs)
        error('Could not find Mean|U|adcp, Mean|U|aga, or Mean|U|gs columns. Please check the CSV.');
    end
    
    % 3. Extract data and filter out empty rows
    % If the algorithm hasn't processed some videos yet, they will be NaN - remove them
    u_adcp = str2double(string(T{:, idx_u_adcp}));
    u_aga  = str2double(string(T{:, idx_u_aga}));
    u_gs   = str2double(string(T{:, idx_u_gs}));
    ang_adcp = str2double(string(T{:, idx_ang_adcp}));
    ang_aga  = str2double(string(T{:, idx_ang_aga}));
    ang_gs   = str2double(string(T{:, idx_ang_gs}));
    
    valid_idx = isfinite(u_aga) & isfinite(u_adcp) & isfinite(u_gs);
    
    u_adcp = u_adcp(valid_idx);
    u_aga  = u_aga(valid_idx);
    u_gs   = u_gs(valid_idx);
    ang_adcp = ang_adcp(valid_idx);
    ang_aga  = ang_aga(valid_idx);
    ang_gs   = ang_gs(valid_idx);
    file_names_clean = file_names_clean(valid_idx);
    
    n_videos = length(u_adcp);
    x = 1:n_videos;
    
    % Calculate and print Mean Absolute Errors to Console
    mae_u_adcp_aga = mean(abs(u_adcp - u_aga));
    mae_u_adcp_gs  = mean(abs(u_adcp - u_gs));
    
    circ_diff = @(a, b) mod((a - b) + 180, 360) - 180;
    mae_ang_adcp_aga = mean(abs(circ_diff(ang_adcp, ang_aga)));
    mae_ang_adcp_gs  = mean(abs(circ_diff(ang_adcp, ang_gs)));
    
    fprintf('\n==========================================\n');
    fprintf('           ERROR ANALYSIS (MAE)           \n');
    fprintf('==========================================\n');
    fprintf('VELOCITY MAGNITUDE (|U|):\n');
    fprintf('  ADCP vs Adaptive GA : %.4f m/s\n', mae_u_adcp_aga);
    fprintf('  ADCP vs Grid Search : %.4f m/s\n', mae_u_adcp_gs);
    fprintf('\nCURRENT DIRECTION (Angles):\n');
    fprintf('  ADCP vs Adaptive GA : %.2f degrees\n', mae_ang_adcp_aga);
    fprintf('  ADCP vs Grid Search : %.2f degrees\n', mae_ang_adcp_gs);
    fprintf('==========================================\n\n');
    
    % Colors (Black for ADCP, Blue for Adaptive GA, Red for Grid Search)
    color_adcp = [0 0 0];    
    color_aga  = [0.15 0.45 0.95]; 
    color_gs   = [0.9 0.2 0.2];
    
    % ==========================================
    % GRAPH 1: VELOCITY MAGNITUDE (Mean|U|)
    % ==========================================
    fig_vel = figure('Name', 'mean |U|', 'Position', [100, 100, 1200, 500], 'Color', 'w');
    
    plot(x, u_adcp, '-o', 'Color', color_adcp, 'LineWidth', 2, 'MarkerSize', 7, 'MarkerFaceColor', color_adcp);
    set(gca, 'Color', 'w');
    hold on;
    plot(x, u_aga, '-s', 'Color', color_aga, 'LineWidth', 2, 'MarkerSize', 7, 'MarkerFaceColor', color_aga);
    plot(x, u_gs, '-d', 'Color', color_gs, 'LineWidth', 2, 'MarkerSize', 7, 'MarkerFaceColor', color_gs);
    
    grid on;
    ylim([0 2.5]);
    
    % Force axes, text, and grid to be purely black
    ax = gca;
    ax.XColor = 'k';
    ax.YColor = 'k';
    ax.GridColor = 'k';
    ax.GridAlpha = 0.15;
    
    xticks(x);
    xticklabels(file_names_clean);
    xtickangle(45);
    
    ylabel(' Mean|U| [m/s]', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k');
    title(sprintf('Mean |U|: ADCP vs Algorithms (Processed videos: %d)', n_videos), 'FontSize', 14, 'Color', 'k');
    lgd1 = legend(adcp_legend_str, 'Adaptive GA', 'Grid Search', 'Location', 'best', 'FontSize', 11);
    set(lgd1, 'Color', 'w', 'EdgeColor', 'k', 'TextColor', 'k');
    
    exportgraphics(fig_vel, fullfile(output_dir, [file_prefix, 'AGA_vs_ADCP_Magnitude.png']), 'Resolution', 300);
    savefig(fig_vel, fullfile(output_dir, [file_prefix, 'AGA_vs_ADCP_Magnitude.fig']));
    
    % ==========================================
    % GRAPH 2: DIRECTION (ANGLE)
    % ==========================================
    fig_ang = figure('Name', 'Angle Comparison', 'Position', [150, 150, 1200, 500], 'Color', 'w');
    
    plot(x, ang_adcp, '-o', 'Color', color_adcp, 'LineWidth', 2, 'MarkerSize', 7, 'MarkerFaceColor', color_adcp);
    set(gca, 'Color', 'w');
    hold on;
    plot(x, ang_aga, '-s', 'Color', color_aga, 'LineWidth', 2, 'MarkerSize', 7, 'MarkerFaceColor', color_aga);
    plot(x, ang_gs, '-d', 'Color', color_gs, 'LineWidth', 2, 'MarkerSize', 7, 'MarkerFaceColor', color_gs);
    
    grid on;
    
    % Force axes, text, and grid to be purely black
    ax = gca;
    ax.XColor = 'k';
    ax.YColor = 'k';
    ax.GridColor = 'k';
    ax.GridAlpha = 0.15;
    
    xticks(x);
    xticklabels(file_names_clean);
    xtickangle(45);
    
    ylabel('Current Direction [Degrees]', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k');
    title('Current Direction Comparison (Angles)', 'FontSize', 14, 'Color', 'k');
    lgd2 = legend(adcp_legend_str, 'Adaptive GA', 'Grid Search', 'Location', 'best', 'FontSize', 11);
    set(lgd2, 'Color', 'w', 'EdgeColor', 'k', 'TextColor', 'k');
    
    exportgraphics(fig_ang, fullfile(output_dir, [file_prefix, 'AGA_vs_ADCP_Angles.png']), 'Resolution', 300);
    savefig(fig_ang, fullfile(output_dir, [file_prefix, 'AGA_vs_ADCP_Angles.fig']));
    
    % ==========================================
    % GRAPH 3: SCATTER PLOT (ADCP vs Adaptive GA)
    % ==========================================
    fig_scatter_aga = figure('Name', 'Scatter Comparison AGA', 'Position', [200, 100, 600, 600], 'Color', 'w');
    movegui(fig_scatter_aga, 'center');
    scatter(u_adcp, u_aga, 60, color_aga, 'filled', 'MarkerEdgeColor', 'k', 'MarkerFaceAlpha', 0.8);
    set(gca, 'Color', 'w');
    hold on;
    
    min_val = 0;
    max_val = 2.5;
    plot([min_val, max_val], [min_val, max_val], 'k--', 'LineWidth', 1.5);
    
    grid on;
    axis equal;
    xlim([min_val max_val]);
    ylim([min_val max_val]);
    
    ax = gca;
    ax.XColor = 'k';
    ax.YColor = 'k';
    ax.GridColor = 'k';
    ax.GridAlpha = 0.15;
    
    xlabel(adcp_label_str, 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k');
    ylabel('Adaptive GA Velocity [m/s]', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k');
    title(sprintf('Adaptive GA vs ADCP Comparison (%s)', wind_title_suffix), 'FontSize', 14, 'Color', 'k');
    lgd3 = legend('Adaptive GA', 'Perfect Agreement', 'Location', 'northwest', 'FontSize', 11);
    set(lgd3, 'Color', 'w', 'EdgeColor', 'k', 'TextColor', 'k');
    
    exportgraphics(fig_scatter_aga, fullfile(output_dir, [file_prefix, 'AGA_vs_ADCP_Scatter.png']), 'Resolution', 300);
    savefig(fig_scatter_aga, fullfile(output_dir, [file_prefix, 'AGA_vs_ADCP_Scatter.fig']));

    % ==========================================
    % GRAPH 4: SCATTER PLOT (ADCP vs Grid Search)
    % ==========================================
    fig_scatter_gs = figure('Name', 'Scatter Comparison GS', 'Position', [250, 150, 600, 600], 'Color', 'w');
    movegui(fig_scatter_gs, 'center');
    scatter(u_adcp, u_gs, 60, color_gs, 'filled', 'MarkerEdgeColor', 'k', 'MarkerFaceAlpha', 0.8);
    set(gca, 'Color', 'w');
    hold on;
    
    plot([min_val, max_val], [min_val, max_val], 'k--', 'LineWidth', 1.5);
    
    grid on;
    axis equal;
    xlim([min_val max_val]);
    ylim([min_val max_val]);
    
    ax = gca;
    ax.XColor = 'k';
    ax.YColor = 'k';
    ax.GridColor = 'k';
    ax.GridAlpha = 0.15;
    
    xlabel(adcp_label_str, 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k');
    ylabel('Grid Search Velocity [m/s]', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k');
    title(sprintf('Grid Search vs ADCP Comparison (%s)', wind_title_suffix), 'FontSize', 14, 'Color', 'k');
    lgd4 = legend('Grid Search', 'Perfect Agreement', 'Location', 'northwest', 'FontSize', 11);
    set(lgd4, 'Color', 'w', 'EdgeColor', 'k', 'TextColor', 'k');
    
    exportgraphics(fig_scatter_gs, fullfile(output_dir, [file_prefix, 'GS_vs_ADCP_Scatter.png']), 'Resolution', 300);
    savefig(fig_scatter_gs, fullfile(output_dir, [file_prefix, 'GS_vs_ADCP_Scatter.fig']));

    % ==========================================
    % GRAPH 5: SCATTER PLOT (Adaptive GA vs Grid Search)
    % ==========================================
    fig_scatter_aga_gs = figure('Name', 'Scatter Comparison AGA vs GS', 'Position', [300, 200, 600, 600], 'Color', 'w');
    movegui(fig_scatter_aga_gs, 'center');
    scatter(u_aga, u_gs, 60, [0.5 0.2 0.8], 'filled', 'MarkerEdgeColor', 'k', 'MarkerFaceAlpha', 0.8);
    set(gca, 'Color', 'w');
    hold on;
    
    plot([min_val, max_val], [min_val, max_val], 'k--', 'LineWidth', 1.5);
    
    grid on;
    axis equal;
    xlim([min_val max_val]);
    ylim([min_val max_val]);
    
    ax = gca;
    ax.XColor = 'k';
    ax.YColor = 'k';
    ax.GridColor = 'k';
    ax.GridAlpha = 0.15;
    
    xlabel('Adaptive GA Velocity [m/s]', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k');
    ylabel('Grid Search Velocity [m/s]', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k');
    title(sprintf('Adaptive GA vs Grid Search Comparison (%s)', wind_title_suffix), 'FontSize', 14, 'Color', 'k');
    lgd5 = legend('Velocities Comparison', 'Perfect Agreement', 'Location', 'northwest', 'FontSize', 11);
    set(lgd5, 'Color', 'w', 'EdgeColor', 'k', 'TextColor', 'k');
    
    exportgraphics(fig_scatter_aga_gs, fullfile(output_dir, [file_prefix, 'AGA_vs_GS_Scatter.png']), 'Resolution', 300);
    savefig(fig_scatter_aga_gs, fullfile(output_dir, [file_prefix, 'AGA_vs_GS_Scatter.fig']));
    
    fprintf('Processing complete!\nSaved 5 graphs in folder: %s\n', output_dir);
end