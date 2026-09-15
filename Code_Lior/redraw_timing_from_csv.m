function redraw_timing_from_csv()
    % Open a dialog box to select the CSV file
    [file, path] = uigetfile('*.csv', 'Select a CSV file with timing results');
    
    % Check if the user clicked "Cancel"
    if isequal(file, 0)
        disp('File selection canceled.');
        return;
    end
    
    full_file_path = fullfile(path, file);
    disp(['Reading file: ', full_file_path]);
    
    % Load the table robustly
    try
        % Force MATLAB to ONLY use commas and ignore underscores completely
        T = readtable(full_file_path, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
    catch ME
        error('Error reading file: %s', ME.message);
    end
    
    num_cols = size(T, 2);
    
    % --- LOGIC 1: Per-window graphs (Window Timing) ---
    if num_cols >= 4 
        disp('Window Timing format recognized. Plotting...');
        
        idx_total = num_cols;
        last_col = T{:, idx_total};
        
        % Accurately identify a true phantom column (all NaNs or all empty text)
        if (isnumeric(last_col) && all(isnan(last_col))) || ...
           ((iscell(last_col) || isstring(last_col)) && all(strlength(strtrim(string(last_col))) == 0))
            idx_total = idx_total - 1;
        end
        
        % Extract and strictly force numeric conversion to avoid 'bar' / 'plot' errors
        x = str2double(string(T{:, idx_total - 4}));
        y1 = str2double(string(T{:, idx_total - 3}));
        y2 = str2double(string(T{:, idx_total - 2}));
        y3 = str2double(string(T{:, idx_total - 1}));
        y4 = str2double(string(T{:, idx_total}));
        
        n_windows = max(x);
        
        % Plotted exactly as in print_time_graphs
        fig_win = figure('Name', 'CopterCurrents Window Timing Re-plot', ...
                         'NumberTitle', 'off', ...
                         'Position', [100, 100, 1200, 900], 'Color', 'w');
        
        subplot(4,1,1);
        plot(x, y1, 'LineWidth', 1.5);
        grid on;
        title('Per-window cut time');
        ylabel('Time [s]');
        xlim([1 max(1, n_windows)]);
        
        subplot(4,1,2);
        plot(x, y2, 'LineWidth', 1.5);
        grid on;
        title('Per-window spectrum time');
        ylabel('Time [s]');
        xlim([1 max(1, n_windows)]);
        
        subplot(4,1,3);
        plot(x, y3, 'LineWidth', 1.5);
        grid on;
        title('Per-window fit time');
        ylabel('Time [s]');
        xlim([1 max(1, n_windows)]);
        
        subplot(4,1,4);
        plot(x, y4, 'LineWidth', 1.5);
        grid on;
        title('Per-window total time');
        ylabel('Time [s]');
        xlabel('Window index');
        xlim([1 max(1, n_windows)]);
        
        % Save in high resolution (300 DPI)
        save_path = fullfile(path, 'per_window_timing_graph.png');
        exportgraphics(fig_win, save_path, 'Resolution', 300);
        disp(['Graph successfully saved: ', save_path]);
        
        return;
        
    % --- LOGIC 2: Stage graphs (Stage Timing) ---
    elseif num_cols == 2 || num_cols == 3
        disp('Stage Timing format recognized. Plotting...');
        
        idx_time = num_cols;
        last_col = T{:, idx_time};
        
        % Accurately identify a true phantom column (all NaNs or all empty text)
        if (isnumeric(last_col) && all(isnan(last_col))) || ...
           ((iscell(last_col) || isstring(last_col)) && all(strlength(strtrim(string(last_col))) == 0))
            idx_time = idx_time - 1;
        end
        
        stage_names_data = T{:, idx_time - 1}; 
        % Force numeric conversion for the bar chart
        time_data = str2double(string(T{:, idx_time})); 
        
        % Plotted exactly as in print_time_graphs
        fig_stage = figure('Name', 'CopterCurrents Stage Timing', ...
                           'NumberTitle', 'off', ...
                           'Position', [150, 150, 800, 600], 'Color', 'w');
        
        bar(time_data);
        grid on;
        ylabel('Time [s]');
        title('Pipeline stage timing');
        xticks(1:numel(time_data));
        
        if ~isempty(stage_names_data)
            clean_names = strrep(string(stage_names_data), '_', ' ');
            xticklabels(clean_names);
            xtickangle(25);
        end
        
        % Save in high resolution (300 DPI)
        save_path = fullfile(path, 'stage_timing_histogram.png');
        exportgraphics(fig_stage, save_path, 'Resolution', 300);
        disp(['Graph successfully saved: ', save_path]);
        
        return;
    end
    
    error('CSV format not recognized. Found %d columns. Please check the file contents.', num_cols);
end