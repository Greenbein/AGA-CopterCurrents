function plot_angle_differences(csv_path)
% PLOT_ANGLE_DIFFERENCES Reads a CSV table and plots the differences 
% between current direction angles (ADCP - AGA, ADCP - GS, AGA - GS).

    if nargin < 1
        [file, path] = uigetfile('*.csv', 'Select CSV file');
        if isequal(file, 0)
            disp('Cancelled by user.');
            return;
        end
        csv_path = fullfile(path, file);
    end
    
    disp(['Reading file: ', csv_path]);
    
    % Load table while preserving original column names
    opts = detectImportOptions(csv_path);
    opts.VariableNamingRule = 'preserve';
    T = readtable(csv_path, opts);
    headers = T.Properties.VariableNames;
    
    % Dynamic column search
    file_names = T{:, 1}; % Assuming file names are in the first column
    if iscell(file_names) || isstring(file_names)
        file_names = string(file_names);
    else
        file_names = string(num2cell(1:height(T)));
    end
    
    % Clean up names for better labeling
    file_names_clean = strrep(file_names, '_', ' ');
    file_names_clean = strrep(file_names_clean, '.MP4', '');
    file_names_clean = strrep(file_names_clean, 'DJI', '');
    
    idx_ang_adcp = find(contains(headers, 'angleADCP', 'IgnoreCase', true), 1);
    idx_ang_aga  = find(contains(headers, 'angleAGA', 'IgnoreCase', true), 1);
    idx_ang_gs   = find(contains(headers, 'angleGS', 'IgnoreCase', true), 1);
    
    if isempty(idx_ang_adcp) || isempty(idx_ang_aga) || isempty(idx_ang_gs)
        error('Could not find angleADCP, angleAGA, or angleGS columns. Please check the CSV.');
    end
    
    % Extract data
    ang_adcp = str2double(string(T{:, idx_ang_adcp}));
    ang_aga  = str2double(string(T{:, idx_ang_aga}));
    ang_gs   = str2double(string(T{:, idx_ang_gs}));
    
    valid_idx = isfinite(ang_adcp) & isfinite(ang_aga) & isfinite(ang_gs);
    
    ang_adcp = ang_adcp(valid_idx);
    ang_aga  = ang_aga(valid_idx);
    ang_gs   = ang_gs(valid_idx);
    file_names_clean = file_names_clean(valid_idx);
    
    n_videos = length(ang_adcp);
    x = 1:n_videos;
    
    % Calculate circular difference in degrees [-180, 180]
    % This handles wrap-around (e.g. difference between 350 and 10 is -20, not 340)
    circ_diff = @(a, b) mod((a - b) + 180, 360) - 180;
    
    diff_adcp_aga = circ_diff(ang_adcp, ang_aga);
    diff_adcp_gs  = circ_diff(ang_adcp, ang_gs);
    diff_aga_gs   = circ_diff(ang_aga, ang_gs);
    
    % Print Mean Absolute Errors to console
    mae_adcp_aga = mean(abs(diff_adcp_aga));
    mae_adcp_gs  = mean(abs(diff_adcp_gs));
    fprintf('Mean Absolute Error (ADCP vs AGA): %.2f degrees\n', mae_adcp_aga);
    fprintf('Mean Absolute Error (ADCP vs GS):  %.2f degrees\n', mae_adcp_gs);
    
    % Colors
    color_adcp_aga = [0.15 0.45 0.95]; % Blue (AGA)
    color_adcp_gs  = [0.9 0.2 0.2];    % Red (GS)
    color_aga_gs   = [0.5 0.2 0.8];    % Purple (AGA vs GS)
    
    % Plotting
    fig = figure('Name', 'Angle Differences', 'Position', [150, 150, 1200, 500], 'Color', 'w');
    
    plot(x, diff_adcp_aga, '-s', 'Color', color_adcp_aga, 'LineWidth', 2, 'MarkerSize', 7, 'MarkerFaceColor', color_adcp_aga);
    set(gca, 'Color', 'w');
    hold on;
    plot(x, diff_adcp_gs, '-d', 'Color', color_adcp_gs, 'LineWidth', 2, 'MarkerSize', 7, 'MarkerFaceColor', color_adcp_gs);
    plot(x, diff_aga_gs, '-o', 'Color', color_aga_gs, 'LineWidth', 2, 'MarkerSize', 7, 'MarkerFaceColor', color_aga_gs);
    
    % Add horizontal zero line
    plot([1, n_videos], [0, 0], 'k--', 'LineWidth', 1.5);
    
    grid on;
    
    % Set limits
    ylim([-180 180]);
    yticks(-180:45:180);
    
    % Aesthetics
    ax = gca;
    ax.XColor = 'k';
    ax.YColor = 'k';
    ax.GridColor = 'k';
    ax.GridAlpha = 0.3;
    
    xticks(x);
    xticklabels(file_names_clean);
    xtickangle(45);
    
    ylabel('Angle Difference [Degrees]', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k');
    title('Difference in Current Direction', 'FontSize', 14, 'Color', 'k');
    lgd = legend('ADCP - Adaptive GA', 'ADCP - Grid Search', 'Adaptive GA - Grid Search', 'Zero Difference (Perfect Match)', 'Location', 'best', 'FontSize', 11);
    set(lgd, 'Color', 'w', 'EdgeColor', 'k', 'TextColor', 'k');
    
    % Save graphs
    output_dir = fileparts(csv_path);
    exportgraphics(fig, fullfile(output_dir, 'angle_diffs_graphs.png'), 'Resolution', 300);
    savefig(fig, fullfile(output_dir, 'angle_diffs_graphs.fig'));
    
    fprintf('Processing complete!\nSaved graphs in folder: %s\n', output_dir);

end
