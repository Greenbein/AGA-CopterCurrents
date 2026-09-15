% function save_timing_plots(stage_fig, window_fig, algo_results_dir)
% if ~isempty(stage_fig) && isgraphics(stage_fig)
%     saveas(stage_fig, fullfile(algo_results_dir, 'stage_timing_histogram.png'));
% end
% if ~isempty(window_fig) && isgraphics(window_fig)
%     saveas(window_fig, fullfile(algo_results_dir, 'per_window_timing_graph.png'));
% end
% end
function save_timing_results(stage_fig, window_fig, stage_names, stage_times, window_timing, algo_results_dir)
% Save timing figures (PNG) and timing data (CSV).

    % ==========================================
    % 1. SAVE FIGURES (PNG)
    % ==========================================
    if ~isempty(stage_fig) && isgraphics(stage_fig)
        saveas(stage_fig, fullfile(algo_results_dir, 'stage_timing_histogram.png'));
    end
    if ~isempty(window_fig) && isgraphics(window_fig)
        saveas(window_fig, fullfile(algo_results_dir, 'per_window_timing_graph.png'));
    end

    % ==========================================
    % 2. SAVE STAGE TIMING CSV
    % ==========================================
    if ~isempty(stage_times)
        % Default stage names if not provided
        if nargin < 3 || isempty(stage_names)
            stage_names = arrayfun(@(x) sprintf('Stage %d', x), 1:numel(stage_times), 'UniformOutput', false);
        end
        
        T_stage = table(string(stage_names(:)), stage_times(:), ...
            'VariableNames', {'Stage_Name', 'Time_Seconds'});
        writetable(T_stage, fullfile(algo_results_dir, 'stage_timing.csv'));
    end

    % ==========================================
    % 3. SAVE PER-WINDOW TIMING CSV
    % ==========================================
    required_fields = {'t_window_cut','t_window_fft','t_window_fit','t_window_total'};
    
    if nargin >= 5 && ~isempty(window_timing) && all(isfield(window_timing, required_fields))
        n_windows = numel(window_timing.t_window_total);
        Window_Index = (1:n_windows)';
        
        Cut_Time_s = window_timing.t_window_cut(:);
        FFT_Time_s = window_timing.t_window_fft(:);
        Fit_Time_s = window_timing.t_window_fit(:);
        Total_Time_s = window_timing.t_window_total(:);
        
        T_window = table(Window_Index, Cut_Time_s, FFT_Time_s, Fit_Time_s, Total_Time_s);
        writetable(T_window, fullfile(algo_results_dir, 'per_window_timing.csv'));
    end
end