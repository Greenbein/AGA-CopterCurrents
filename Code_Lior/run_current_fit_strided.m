function [STCFIT] = run_current_fit_strided(IMG_SEQ, STCFIT, USE_GD, results_dir, file_tag)
%RUN_CURRENT_FIT_STRIDED Strided computation with neighbor averaging
%
%   Performs expensive fitting (GD/GS) only on strided grid positions,
%   then fills remaining windows using neighbor averaging with SNR computation.
%
%   Input:
%     IMG_SEQ: Image sequence structure
%     STCFIT: Structure with fit parameters and window definitions
%     USE_GD: true for Gradient Descent, false for Grid Search
%     results_dir: (optional) folder path to save results; if empty, uses MATLAB folder
%     file_tag: (optional) string [algorithm]_[video_name] for filenames
%
%   Output:
%     STCFIT: Updated structure with fit results

% ============================================================================
% CONFIGURATION
% ============================================================================
if nargin < 3 || isempty(USE_GD)
    USE_GD = false;  % flag: true = gradient descent, false = grid search
end
if nargin < 4
    results_dir = [];
end
if nargin < 5 || isempty(file_tag)
    file_tag = [];
end

% ============================================================================
% INITIALIZATION
% ============================================================================
N = STCFIT.Windows.N_fit_windows;
t_cut = zeros(N,1);
t_fft = zeros(N,1);
t_fit = zeros(N,1);
velocities_array = zeros(N, 2);  % N windows x 2 (Ux, Uy)

% ============================================================================
% SETUP GRID MAPPING
% ============================================================================
[Nx, Ny, row_idx, col_idx] = setup_grid_mapping(STCFIT, N);

fprintf('\n=== Strided Computation ===\n');
fprintf('Grid dimensions: %d x %d (Nx x Ny)\n', Nx, Ny);
fprintf('Total windows: %d\n', N);
fprintf('Strategy: Pattern b-d-b-d with b on first/last rows and last 2 cols\n');
fprintf('b = compute via GA, d = interpolate from 4 diagonal neighbors\n');
fprintf('================================\n\n');

% ============================================================================
% FIRST PASS: Compute strided windows only
% ============================================================================
fprintf('=== First Pass: Computing strided windows ===\n');

is_computed = false(N, 1);
is_skipped = false(N, 1);
is_neighbor_initialized = false(N, 1);  % Track windows that used neighbor average as initial velocity
Spectrum_store = cell(N, 1);
% Initialize out_fit structure with all possible fields to match both formats:
% Grid Search returns: FG_fit, SG_fit
% Adaptive_Gradient_Ascent returns: FG_fit, SG_fit, U, loss, adaptive_params, timing
% Create template structure with all fields
template = struct('FG_fit', [], 'SG_fit', [], 'U', [], 'loss', [], 'adaptive_params', [], 'timing', []);
% Pre-allocate array using repmat
out_fit = repmat(template, N, 1);

% Create row-col to linear index mapping (needed for neighbor lookup)
rowcol_to_linear = create_rowcol_mapping(row_idx, col_idx, N);

for i1 = 1:N
    [out_fit, velocities_array, is_computed, is_skipped, is_neighbor_initialized, Spectrum_store, t_cut, t_fft, t_fit] = ...
        process_window_computation(i1, N, IMG_SEQ, STCFIT, USE_GD, ...
        row_idx, col_idx, Nx, Ny, rowcol_to_linear, out_fit, velocities_array, ...
        is_computed, is_skipped, is_neighbor_initialized, Spectrum_store, t_cut, t_fft, t_fit);
end

fprintf('First pass completed: %d computed, %d skipped\n', sum(is_computed), sum(is_skipped));
fprintf('  Windows with neighbor-based initial velocity: %d\n\n', sum(is_neighbor_initialized));

% ============================================================================
% SECOND PASS: Fill remaining skipped windows using neighbor averaging + compute SNR
% (Only for windows that couldn't use neighbor-based fit in first pass)
% ============================================================================
if sum(is_skipped) > 0
    fprintf('=== Second Pass: Filling remaining skipped windows ===\n');
    fprintf('Filling %d skipped windows using neighbor averaging (no fit)...\n', sum(is_skipped));
    
    % Note: rowcol_to_linear already created before first pass
    
    for i1 = 1:N
        if ~is_skipped(i1)
            continue;
        end
        
        % Fill remaining skipped windows (those without neighbors or not using GD)
        [out_fit, velocities_array] = fill_skipped_window(i1, row_idx, col_idx, ...
            Nx, Ny, rowcol_to_linear, is_computed, velocities_array, ...
            out_fit, Spectrum_store, STCFIT);
    end
    
    fprintf('Second pass completed.\n\n');
else
    fprintf('=== Second Pass: No skipped windows to fill ===\n\n');
end

STCFIT.out_fit = out_fit;

% ============================================================================
% SAVE RESULTS AND PLOTS
% ============================================================================
save_velocities_and_timing(velocities_array, USE_GD, t_cut, t_fft, t_fit, ...
    is_computed, is_skipped, is_neighbor_initialized, N, results_dir, file_tag);

end

% ============================================================================
% HELPER FUNCTION: Setup grid mapping
% ============================================================================
function [Nx, Ny, row_idx, col_idx] = setup_grid_mapping(STCFIT, N)
% Setup 2D grid mapping from window centers
    
    % Get window centers to determine grid layout
    centers_x = zeros(N, 1);
    centers_y = zeros(N, 1);
    for i1 = 1:N
        IND_center = sub2ind(size(STCFIT.Generic.gridX), ...
            STCFIT.Windows.w_corners_dim1(1,i1), ...
            STCFIT.Windows.w_corners_dim2(1,i1));
        centers_x(i1) = STCFIT.Generic.gridX(IND_center);
        centers_y(i1) = STCFIT.Generic.gridY(IND_center);
    end
    
    % Find unique coordinates to determine grid size
    x_unique = unique(centers_x);
    y_unique = unique(centers_y);
    Nx = length(x_unique);
    Ny = length(y_unique);
    
    % If Nx and Ny are already in STCFIT.Windows, use them
    if isfield(STCFIT.Windows, 'Nx') && isfield(STCFIT.Windows, 'Ny')
        Nx = STCFIT.Windows.Nx;
        Ny = STCFIT.Windows.Ny;
    end
    
    % Create mapping: linear index -> (row, col) in 2D grid
    row_idx = zeros(N, 1);
    col_idx = zeros(N, 1);
    for i1 = 1:N
        [~, col_idx(i1)] = min(abs(x_unique - centers_x(i1)));
        [~, row_idx(i1)] = min(abs(y_unique - centers_y(i1)));
    end
end

% ============================================================================
% HELPER FUNCTION: Determine if window should be computed
% ============================================================================
function should_compute = should_compute_window(row, col, Nx, Ny)
% Determine if window should be computed based on b-d pattern
% Pattern: b = compute, d = interpolate
% - Row 1: all b
% - Rows 2 to (Ny-1): alternating b-d-b-d..., but last 2 columns are all b
% - Last row: all b
    
    is_first_row = (row == 1);
    is_last_row = (row == Ny);
    is_last_two_cols = (col > Nx - 2);
    
    if is_first_row || is_last_row
        % First and last rows: always compute (all b)
        should_compute = true;
    elseif is_last_two_cols
        % Last 2 columns: always compute (all b)
        should_compute = true;
    else
        % Middle rows, not in last 2 cols: alternating pattern
        % b if odd column, d if even column
        should_compute = (mod(col, 2) == 1);
    end
end

% ============================================================================
% HELPER FUNCTION: Create placeholder structure
% ============================================================================
function out_fit_placeholder = create_placeholder_structure(USE_GD)
% Create placeholder structure matching fit output format
    
    FG_fit_placeholder = struct( ...
        'signal_2D',          [], ...
        'noise_2D',           [], ...
        'signal_nvalues_2D',  [], ...
        'noise_nvalues_2D',   [], ...
        'SNR_2D',             [], ...
        'SNR_density_2D',     [], ...
        'Ux_fit',             NaN, ...
        'Uy_fit',             NaN, ...
        'SNR_max',            NaN, ...
        'SNR_density_max',    NaN, ...
        'Ux_2D',              [], ...
        'Uy_2D',              [] );
    
    SG_fit_placeholder = FG_fit_placeholder;
    
    if USE_GD
        % Match Adaptive_Gradient_Ascent format
        out_fit_placeholder = struct( ...
            'FG_fit', FG_fit_placeholder, ...
            'SG_fit', SG_fit_placeholder, ...
            'U', [NaN, NaN], ...
            'loss', NaN, ...
            'adaptive_params', struct( ...
                'grad_norm_initial',    NaN, ...
                'L_initial',            NaN, ...
                'step_initial',         NaN, ...
                'conv_grad_threshold',  NaN, ...
                'conv_loss_threshold',  NaN ...
            ), ...
            'timing', struct('total_time', 0, 'iter_times', [], 'mean_iter_time', 0));
    else
        % Match fit_Spectrum2dispersionRelation format
        out_fit_placeholder = struct( ...
            'FG_fit', FG_fit_placeholder, ...
            'SG_fit', SG_fit_placeholder);
    end
end

% ============================================================================
% HELPER FUNCTION: Process single window in first pass
% ============================================================================
function [out_fit, velocities_array, is_computed, is_skipped, is_neighbor_initialized, Spectrum_store, t_cut, t_fft, t_fit] = ...
    process_window_computation(i1, N, IMG_SEQ, STCFIT, USE_GD, ...
    row_idx, col_idx, Nx, Ny, rowcol_to_linear, out_fit, velocities_array, ...
    is_computed, is_skipped, is_neighbor_initialized, Spectrum_store, t_cut, t_fft, t_fit)
% Process single window: extract, compute spectrum, and optionally fit
    
    disp(['Window ' num2str(i1) ' of ' num2str(N)]);
    
    % STEP 1: Cut window
    tic;
    IMG_SEQ_Window = double(IMG_SEQ.IMG( ...
        STCFIT.Windows.w_corners_dim1(2,i1):STCFIT.Windows.w_corners_dim1(3,i1), ...
        STCFIT.Windows.w_corners_dim2(2,i1):STCFIT.Windows.w_corners_dim2(3,i1), :));
    t_cut(i1) = toc;
    
    % STEP 2: FFT / Spectrum
    tic;
    Spectrum = retrieve_power_spectrum(IMG_SEQ_Window, ...
        IMG_SEQ.dx, IMG_SEQ.dy, IMG_SEQ.dt, ...
        STCFIT.fit_param.K_limits, STCFIT.fit_param.W_limits);
    t_fft(i1) = toc;
    
    Spectrum_store{i1} = Spectrum;
    
    % STEP 3: Determine if should compute
    row = row_idx(i1);
    col = col_idx(i1);
    should_compute = should_compute_window(row, col, Nx, Ny);
    
    if should_compute
        % Compute expensive fit
        tic;
        if USE_GD
            disp("Start using Adaptive Gradient Ascent");
            out_fit_i = Adaptive_Gradient_Ascent(Spectrum, STCFIT.fit_param, STCFIT.Windows.average_depth_win(i1), [0, 0]);
        else
            disp("Start using Grid Search");
            out_fit_i = fit_Spectrum2dispersionRelation(Spectrum, STCFIT.fit_param, STCFIT.Windows.average_depth_win(i1));
        end
        t_fit(i1) = toc;
        
        out_fit(i1) = out_fit_i;
        velocities_array(i1, 1) = out_fit_i.SG_fit.Ux_fit;
        velocities_array(i1, 2) = out_fit_i.SG_fit.Uy_fit;
        is_computed(i1) = true;
    else
        % Skip expensive fit, but use neighbor average as initial velocity for fit
        tic;
        row = row_idx(i1);
        col = col_idx(i1);
        
        % Find 4 diagonal neighbors
        [neighbor_Ux, neighbor_Uy] = find_4_diagonal_neighbors(row, col, Nx, Ny, ...
            rowcol_to_linear, is_computed, velocities_array);
        
        % Compute mean of available neighbors as initial velocity
        if ~isempty(neighbor_Ux) && USE_GD
            % Use mean of neighbors as initial velocity for fit
            U_initial = [mean(neighbor_Ux, 'omitnan'), mean(neighbor_Uy, 'omitnan')];
            
            % Check if U_initial is valid (not NaN and finite)
            if all(isfinite(U_initial)) && ~any(isnan(U_initial))
                disp(sprintf("Skipped window %d: using neighbor average [%.4f, %.4f] as initial velocity", ...
                    i1, U_initial(1), U_initial(2)));
                
                % Perform fit with neighbor-based initial velocity
                out_fit_i = Adaptive_Gradient_Ascent(Spectrum, STCFIT.fit_param, ...
                    STCFIT.Windows.average_depth_win(i1), U_initial);
                
                t_fit(i1) = toc;
                out_fit(i1) = out_fit_i;
                velocities_array(i1, 1) = out_fit_i.SG_fit.Ux_fit;
                velocities_array(i1, 2) = out_fit_i.SG_fit.Uy_fit;
                is_computed(i1) = true;  % Mark as computed since we did a fit
                is_skipped(i1) = false;
                is_neighbor_initialized(i1) = true;  % Mark that this window used neighbor-based initial velocity
            else
                % Neighbors found but mean is NaN/invalid - skip fit
                t_fit(i1) = 0;
                out_fit(i1) = create_placeholder_structure(USE_GD);
                velocities_array(i1, 1) = NaN;
                velocities_array(i1, 2) = NaN;
                is_skipped(i1) = true;
                disp(sprintf("Skipped window %d: neighbors found but mean is invalid (NaN)", i1));
            end
        else
            % No neighbors available or not using GD - skip fit
            t_fit(i1) = 0;
            out_fit(i1) = create_placeholder_structure(USE_GD);
            velocities_array(i1, 1) = NaN;
            velocities_array(i1, 2) = NaN;
            is_skipped(i1) = true;
            if isempty(neighbor_Ux)
                disp(sprintf("Skipped window %d: no computed neighbors found", i1));
            else
                disp(sprintf("Skipped window %d: not using GD (neighbors available but USE_GD=false)", i1));
            end
        end
    end
    
    % Print timing
    fprintf("\nWindow %d timing:\n", i1);
    fprintf("    Cut window       = %.5f s\n", t_cut(i1));
    fprintf("    FFT / Spectrum   = %.5f s\n", t_fft(i1));
    fprintf("    Fit currents     = %.5f s\n", t_fit(i1));
    fprintf("--------------------------------------------------\n");
end

% ============================================================================
% HELPER FUNCTION: Create row-col to linear index mapping
% ============================================================================
function rowcol_to_linear = create_rowcol_mapping(row_idx, col_idx, N)
% Create mapping from (row, col) to linear index
    
    rowcol_to_linear = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for i1 = 1:N
        key = sprintf('%d,%d', row_idx(i1), col_idx(i1));
        if ~isKey(rowcol_to_linear, key)
            rowcol_to_linear(key) = i1;
        end
    end
end

% ============================================================================
% HELPER FUNCTION: Find 4 diagonal neighbors
% ============================================================================
function [neighbor_Ux, neighbor_Uy] = find_4_diagonal_neighbors(row, col, Nx, Ny, ...
    rowcol_to_linear, is_computed, velocities_array)
% Find 4 diagonal neighbors for given window
% Diagonals: top-left, top-right, bottom-left, bottom-right
    
    neighbor_Ux = [];
    neighbor_Uy = [];
    
    % Define 4 diagonal neighbor offsets: [row_offset, col_offset]
    diagonal_offsets = [
        -1, -1;  % top-left
        -1,  1;  % top-right
         1, -1;  % bottom-left
         1,  1;  % bottom-right
    ];
    
    % Check all 4 diagonal neighbors
    for n = 1:size(diagonal_offsets, 1)
        n_row = row + diagonal_offsets(n, 1);
        n_col = col + diagonal_offsets(n, 2);
        
        % Check bounds
        if n_row >= 1 && n_row <= Ny && n_col >= 1 && n_col <= Nx
            n_key = sprintf('%d,%d', n_row, n_col);
            if isKey(rowcol_to_linear, n_key)
                n_linear = rowcol_to_linear(n_key);
                if is_computed(n_linear)
                    neighbor_Ux = [neighbor_Ux; velocities_array(n_linear, 1)];
                    neighbor_Uy = [neighbor_Uy; velocities_array(n_linear, 2)];
                end
            end
        end
    end
end

% ============================================================================
% HELPER FUNCTION: Fill skipped window with interpolation
% ============================================================================
function [out_fit, velocities_array] = fill_skipped_window(i1, row_idx, col_idx, ...
    Nx, Ny, rowcol_to_linear, is_computed, velocities_array, ...
    out_fit, Spectrum_store, STCFIT)
% Fill skipped window using 4-diagonal-neighbor averaging and compute SNR
    
    row = row_idx(i1);
    col = col_idx(i1);
    
    % Find 4 diagonal neighbors
    [neighbor_Ux, neighbor_Uy] = find_4_diagonal_neighbors(row, col, Nx, Ny, ...
        rowcol_to_linear, is_computed, velocities_array);
    
    % Compute mean of available neighbors
    if ~isempty(neighbor_Ux)
        velocities_array(i1, 1) = mean(neighbor_Ux, 'omitnan');
        velocities_array(i1, 2) = mean(neighbor_Uy, 'omitnan');
        
        % Update fit structure
        out_fit(i1).FG_fit.Ux_fit = velocities_array(i1, 1);
        out_fit(i1).FG_fit.Uy_fit = velocities_array(i1, 2);
        out_fit(i1).SG_fit.Ux_fit = velocities_array(i1, 1);
        out_fit(i1).SG_fit.Uy_fit = velocities_array(i1, 2);
        
        % Update U field if it exists
        if isfield(out_fit(i1), 'U')
            out_fit(i1).U = [velocities_array(i1, 1), velocities_array(i1, 2)];
        end
        
        % Compute SNR and SNR_density
        Spectrum = Spectrum_store{i1};
        
        % Verify Spectrum is a structure
        if ~isstruct(Spectrum)
            warning('Window %d: Spectrum is not a structure, skipping SNR computation', i1);
            SNR_max = NaN;
            SNR_density_max = NaN;
        else
            [SNR_max, SNR_density_max] = compute_SNR_for_interpolated(...
                Spectrum, ...
                STCFIT.Windows.average_depth_win(i1), ...
                velocities_array(i1, 1), ...
                velocities_array(i1, 2), ...
                STCFIT.fit_param.w_width_SG);
        end
        
        % Update SNR values
        out_fit(i1).SG_fit.SNR_max = SNR_max;
        out_fit(i1).SG_fit.SNR_density_max = SNR_density_max;
        out_fit(i1).FG_fit.SNR_max = SNR_max;
        out_fit(i1).FG_fit.SNR_density_max = SNR_density_max;
        
        % Silent fill - no verbose output (these are rare cases without neighbors or not using GD)
    else
        warning('Window %d (row=%d, col=%d): no computed neighbors found, keeping NaN', ...
            i1, row, col);
    end
end

% ============================================================================
% HELPER FUNCTION: Save velocities and timing results
% ============================================================================
function save_velocities_and_timing(velocities_array, USE_GD, t_cut, t_fft, t_fit, ...
    is_computed, is_skipped, is_neighbor_initialized, N, results_dir, file_tag)
% Save velocities array and create timing plots
    if nargin < 8 || isempty(is_neighbor_initialized)
        is_neighbor_initialized = false(size(is_computed));
    end
    if nargin < 10
        results_dir = [];
    end
    if nargin < 11 || isempty(file_tag)
        file_tag = [];
    end
    
    if USE_GD
        base_vel = 'velocities_array_strided_gradient_descent';
        suffix_base = 'GD_strided';
        timing_base = 'time_graphs_for_GD_strided';
    else
        base_vel = 'velocities_array_strided_grid_search';
        suffix_base = 'GS_strided';
        timing_base = 'time_graphs_for_GS_strided';
    end
    if ~isempty(file_tag)
        filename = ['velocities_array_' file_tag '.mat'];
        suffix = file_tag;
        timing_fn = ['time_graphs_' file_tag];
    else
        filename = [base_vel '.mat'];
        suffix = suffix_base;
        timing_fn = timing_base;
    end
    
    if ~isempty(results_dir)
        filename = fullfile(results_dir, filename);
    end
    
    velocities_array_strided = velocities_array;
    save(filename, 'velocities_array', 'velocities_array_strided', '-v7.3');
    fprintf('\n=== Velocities saved ===\n');
    fprintf('File: %s\n', filename);
    fprintf('Variables: velocities_array, velocities_array_strided\n');
    fprintf('Array size: %d x %d (windows x [Ux, Uy])\n', size(velocities_array, 1), size(velocities_array, 2));
    fprintf('========================\n');
    
    % Timing report
    fprintf("\n=== FINAL Timing Report ===\n");
    fprintf("Cut window:        mean = %.4f s, total = %.4f s\n", mean(t_cut), sum(t_cut));
    fprintf("3D FFT spectrum:   mean = %.4f s, total = %.4f s\n", mean(t_fft), sum(t_fft));
    fprintf("Fit currents:      mean = %.4f s, total = %.4f s\n", mean(t_fit), sum(t_fit));
    fprintf("Computed windows:  %d (%.1f%%)\n", sum(is_computed), 100*sum(is_computed)/N);
    fprintf("Skipped windows:   %d (%.1f%%)\n", sum(is_skipped), 100*sum(is_skipped)/N);
    if USE_GD
        fprintf("Windows with neighbor-based initial velocity: %d (%.1f%%)\n", ...
            sum(is_neighbor_initialized), 100*sum(is_neighbor_initialized)/N);
    end
    fprintf("=================================================================\n");
    
    % Plot timing graphs
    fh = figure('Name','Timing per window','NumberTitle','off');
    
    subplot(3,1,1);
    plot(1:N, t_cut, 'LineWidth', 2);
    title('Cut window time');
    xlabel('Window index');
    ylabel('Time [s]');
    grid on;
    
    subplot(3,1,2);
    plot(1:N, t_fft, 'LineWidth', 2);
    title('FFT / Spectrum time');
    xlabel('Window index');
    ylabel('Time [s]');
    grid on;
    
    subplot(3,1,3);
    plot(1:N, t_fit, 'LineWidth', 2);
    title('Fit currents time');
    xlabel('Window index');
    ylabel('Time [s]');
    grid on;
    
    if ~isempty(results_dir)
        timing_dir = results_dir;
    else
        if ispc
            username = getenv('USERNAME');
            timing_dir = fullfile('C:', 'Users', username, 'Documents', 'MATLAB');
        else
            username = getenv('USER');
            timing_dir = fullfile(filesep, 'home', username, 'Documents', 'MATLAB');
        end
        if ~strcmp(timing_dir(end), filesep)
            timing_dir = [timing_dir filesep];
        end
    end
    if ~exist(timing_dir, 'dir')
        mkdir(timing_dir);
    end
    saveas(fh, fullfile(timing_dir, [timing_fn '.png']));
    save(fullfile(timing_dir, ['t_cut_', suffix, '.mat']), 't_cut');
    save(fullfile(timing_dir, ['t_fft_', suffix, '.mat']), 't_fft');
    save(fullfile(timing_dir, ['t_fit_', suffix, '.mat']), 't_fit');
    
    fprintf('Timing matrices saved:\n');
    fprintf('  t_cut_%s.mat - cut window time for each square\n', suffix);
    fprintf('  t_fft_%s.mat - FFT/spectrum time for each square\n', suffix);
    fprintf('  t_fit_%s.mat - fit currents time for each square\n', suffix);
end

% ============================================================================
% HELPER FUNCTION: Compute SNR for interpolated velocities
% ============================================================================
function [SNR_max, SNR_density_max] = compute_SNR_for_interpolated(...
    Spectrum, water_depth, Ux_fit, Uy_fit, w_width_SG)
% Compute Signal-to-Noise Ratio for interpolated velocity vector
%
% Inputs:
%   Spectrum: Spectrum structure with power_Spectrum field
%   water_depth: water depth in meters
%   Ux_fit: fitted velocity in x direction [m/s]
%   Uy_fit: fitted velocity in y direction [m/s]
%   w_width_SG: filter width for second guess [rad/s]
%
% Outputs:
%   SNR_max: signal-to-noise ratio (signal_sum / noise_sum)
%   SNR_density_max: signal-to-noise density ratio (average signal / average noise)

    % Get dispersion relation mask for given velocity vector
    DS_3D_mask = get_Dispersion_Relation_3D_mask(Spectrum, water_depth, Ux_fit, Uy_fit, w_width_SG);
    
    % Compute signal and noise
    signal = Spectrum.power_Spectrum(DS_3D_mask);
    noise = Spectrum.power_Spectrum(DS_3D_mask==0);
    
    % Sum signal and noise values
    signal_sum = nansum(signal(:));
    noise_sum = nansum(noise(:));
    
    % Count finite values
    signal_nvalues = sum(isfinite(signal(:)));
    noise_nvalues = sum(isfinite(noise(:)));
    
    % Compute SNR
    if noise_sum > 0 && signal_nvalues > 0 && noise_nvalues > 0
        SNR_max = signal_sum / noise_sum;
        SNR_density_max = (signal_sum / signal_nvalues) / (noise_sum / noise_nvalues);
    else
        SNR_max = 0;
        SNR_density_max = 0;
    end
end
