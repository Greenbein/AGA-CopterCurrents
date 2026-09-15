function [STCFIT, timing_info] = run_current_fit(IMG_SEQ, STCFIT, fit_method)
% RUN_CURRENT_FIT Facade for wave dispersion relation current fit
% Includes Adaptive Sampling (AMR) to speed up calculations:
% heavy FFT/Gradient Ascent runs in a checkerboard pattern and where neighbor
% gradients are high. The remaining cells are interpolated by SNR.

    % 1. Initialization and method validation
    if nargin < 3
        fit_method = [];
    end
    method_str = parse_fit_method(fit_method);

    % 2. Build a 2D index map to handle sparse grids
    [GridToLinear, idx_r, idx_c, num_r, num_c] = build_grid_mapping(STCFIT);
    N_fit_windows = STCFIT.Windows.N_fit_windows;

    % 3. Memory allocation
    t_window_cut   = zeros(N_fit_windows, 1);
    t_window_fft   = zeros(N_fit_windows, 1);
    t_window_fit   = zeros(N_fit_windows, 1);
    t_window_total = zeros(N_fit_windows, 1);
    
    out_fit_cell   = cell(N_fit_windows, 1); 

    % Storage for neighbor results
    Ux_grid = NaN(num_r, num_c);
    Uy_grid = NaN(num_r, num_c);
    SNR_grid = NaN(num_r, num_c);
    Computed_mask = false(num_r, num_c);

    % GRADIENT THRESHOLD (tune for your data)
    GRAD_THRESH = 0.5; % [m/s] 

    % =====================================================================
    % STAGE 1: Baseline calculation (checkerboard pattern)
    % =====================================================================
    fprintf('--- STAGE 1: Fit algorithm for chess board ---\n');
    for k = 1:N_fit_windows
        r = idx_r(k); 
        c = idx_c(k);
        
        % If row+col is even, run the full computation
        if mod(r + c, 2) == 0
            fprintf('Fit alg: window %d of %d\n',k,N_fit_windows);
            [out_fit_cell{k}, t_cut, t_fft, t_fit, t_tot] = ...
                run_single_window_heavy(k, IMG_SEQ, STCFIT, method_str);
            
            t_window_cut(k) = t_cut; t_window_fft(k) = t_fft;
            t_window_fit(k) = t_fit; t_window_total(k) = t_tot;
            
            % Save into grid for future interpolation
            Ux_grid(r, c) = out_fit_cell{k}.SG_fit.Ux_fit;
            Uy_grid(r, c) = out_fit_cell{k}.SG_fit.Uy_fit;
            SNR_grid(r, c) = out_fit_cell{k}.SG_fit.SNR_density_max;
            Computed_mask(r, c) = true;
        end
    end

    % =====================================================================
    % STAGE 2: Interpolation for empty cells if the grad is less than GRAD_THRESH
    % =====================================================================
    fprintf('--- STAGE 2: Interpolation ---\n');
    heavy_count = 0;
    interp_count = 0;

    for k = 1:N_fit_windows
        r = idx_r(k); 
        c = idx_c(k);
        
        % Process only the "empty" (odd) cells
        if mod(r + c, 2) ~= 0
            
            % Find computed neighbors with boundary and hole checks
            [n_Ux, n_Uy, n_SNR, n_outfit] = find_valid_neighbors(...
                r, c, num_r, num_c, GridToLinear, Computed_mask, Ux_grid, Uy_grid, SNR_grid, out_fit_cell);
            
            % If there are at least 2 neighbors, check the gradient
            if numel(n_Ux) >= 2
                grad = (max(n_Ux) - min(n_Ux)) + (max(n_Uy) - min(n_Uy));
                
                if grad > GRAD_THRESH
                    % Strong velocity change -> need full computation
                    fprintf('Large grad(U) -> Fit algorithm: window %d of %d\n',k,N_fit_windows);
                    [out_fit_cell{k}, t_cut, t_fft, t_fit, t_tot] = ...
                        run_single_window_heavy(k, IMG_SEQ, STCFIT, method_str);
                    t_window_cut(k) = t_cut; t_window_fft(k) = t_fft;
                    t_window_fit(k) = t_fit; t_window_total(k) = t_tot;
                    heavy_count = heavy_count + 1;
                else
                    fprintf('Small grad(U) -> INTERPOLATION: window %d of %d\n',k,N_fit_windows);
                    % Smooth field -> interpolate (weighted by SNR)
                    t0 = tic;
                    out_fit_cell{k} = create_interpolated_out_fit(n_Ux, n_Uy, n_SNR, n_outfit);
                    t_window_total(k) = toc(t0);
                    interp_count = interp_count + 1;
                end
            else
                % On boundary / few neighbors -> run full computation
                [out_fit_cell{k}, t_cut, t_fft, t_fit, t_tot] = ...
                    run_single_window_heavy(k, IMG_SEQ, STCFIT, method_str);
                t_window_cut(k) = t_cut; t_window_fft(k) = t_fft;
                t_window_fit(k) = t_fit; t_window_total(k) = t_tot;
                heavy_count = heavy_count + 1;
            end
        end
    end

    fprintf('Optimization: %d extra full computations, %d interpolated.\n', heavy_count, interp_count);

    % 5. Assemble results
    STCFIT.out_fit = cat(1, out_fit_cell{:});
    
    timing_info = struct(...
        't_window_cut', t_window_cut, ...
        't_window_fft', t_window_fft, ...
        't_window_fit', t_window_fit, ...
        't_window_total', t_window_total, ...
        'total_fit_time', sum(t_window_total), ...
        'mean_window_time', mean(t_window_total));
end

%% =========================================================================
%  LOCAL FUNCTIONS (HELPERS)
%  =========================================================================

function [GridToLinear, idx_r, idx_c, num_r, num_c] = build_grid_mapping(STCFIT)
% Rebuilds a 2D index structure from the linear list of window centers.
% Helps avoid edge errors and "holes" where windows were filtered out.
    centers_r = round(STCFIT.Windows.w_corners_dim1(1, :));
    centers_c = round(STCFIT.Windows.w_corners_dim2(1, :));
    
    [~, ~, idx_r] = unique(centers_r);
    [~, ~, idx_c] = unique(centers_c);
    
    num_r = max(idx_r);
    num_c = max(idx_c);
    
    GridToLinear = zeros(num_r, num_c);
    for k = 1:STCFIT.Windows.N_fit_windows
        GridToLinear(idx_r(k), idx_c(k)) = k;
    end
end

function [out_fit_i, t_cut, t_fft, t_fit, t_tot] = run_single_window_heavy(k, IMG_SEQ, STCFIT, method_str)
% Isolated heavy run for a single window (with GPU support)
    t_start = tic;
    
    % Prepare data
    r1 = STCFIT.Windows.w_corners_dim1(2, k);
    r2 = STCFIT.Windows.w_corners_dim1(3, k);
    c1 = STCFIT.Windows.w_corners_dim2(2, k);
    c2 = STCFIT.Windows.w_corners_dim2(3, k);
    depth = STCFIT.Windows.average_depth_win(k);
    
    % Step A: Cut
    t0 = tic;
    window_data = IMG_SEQ.IMG(r1:r2, c1:c2, :);
    t_cut = toc(t0);
    
    % Step B: FFT
    global USE_GPU_FLAG;
    if isempty(USE_GPU_FLAG)
        USE_GPU_FLAG = true;
    end
    
    t0 = tic;
    if USE_GPU_FLAG
        window_data_arr = gpuArray(window_data); 
    else
        window_data_arr = window_data;
    end
    
    Spectrum_raw = retrieve_power_spectrum(window_data_arr, IMG_SEQ.dx, IMG_SEQ.dy, IMG_SEQ.dt, STCFIT.fit_param.K_limits, STCFIT.fit_param.W_limits); 
    Spectrum = gather_spectrum_struct(Spectrum_raw);
    t_fft = toc(t0);
    
    % Step C: Fit
    t0 = tic;
    out_fit_i = apply_fit_algorithm(Spectrum, STCFIT.fit_param, depth, method_str);
    % not interpolated -> blue arrow
    out_fit_i.SG_fit.is_interpolated = false;

    t_fit = toc(t0);
    
    t_tot = toc(t_start);
end

function [n_Ux, n_Uy, n_SNR, n_outfit] = find_valid_neighbors(r, c, num_r, num_c, GridToLinear, Computed_mask, Ux_grid, Uy_grid, SNR_grid, out_fit_cell)
% Finds neighbors in a cross pattern (up, down, left, right)
    dr = [-1, 1, 0, 0];
    dc = [ 0, 0,-1, 1];
    
    n_Ux = []; n_Uy = []; n_SNR = []; n_outfit = {};
    
    for i = 1:4
        nr = r + dr(i);
        nc = c + dc(i);
        
        % Boundary check
        if nr >= 1 && nr <= num_r && nc >= 1 && nc <= num_c
            % Check if window was computed and not a hole
            if Computed_mask(nr, nc) && GridToLinear(nr, nc) > 0
                k_neighbor = GridToLinear(nr, nc);
                n_Ux(end+1) = Ux_grid(nr, nc);
                n_Uy(end+1) = Uy_grid(nr, nc);
                n_SNR(end+1) = SNR_grid(nr, nc);
                n_outfit{end+1} = out_fit_cell{k_neighbor};
            end
        end
    end
end

function out_fit_i = create_interpolated_out_fit(n_Ux, n_Uy, n_SNR, n_outfit)
% Creates a fake fit structure, weighted by neighbors' SNR
    if sum(n_SNR) > 0
        weights = n_SNR / sum(n_SNR);
    else
        weights = ones(1, numel(n_SNR)) / numel(n_SNR); % Fallback if SNR is zero
    end
    
    interp_Ux = sum(n_Ux .* weights);
    interp_Uy = sum(n_Uy .* weights);
    interp_SNR = mean(n_SNR); % Average confidence
    
    % Clone the first neighbor structure to keep 2D arrays and formats
    % (needed so plot_currents_map keeps working)
    out_fit_i = n_outfit{1};
    
    % Overwrite only key scalars
    out_fit_i.FG_fit.Ux_fit = interp_Ux;
    out_fit_i.FG_fit.Uy_fit = interp_Uy;
    out_fit_i.FG_fit.SNR_density_max = interp_SNR;
    
    out_fit_i.SG_fit.Ux_fit = interp_Ux;
    out_fit_i.SG_fit.Uy_fit = interp_Uy;
    out_fit_i.SG_fit.SNR_density_max = interp_SNR;
    % interpolated -> green arrow
    out_fit_i.SG_fit.is_interpolated = true;
end

function method_str = parse_fit_method(fit_method)
    if isempty(fit_method)
        method_str = 'grid';
    elseif islogical(fit_method) || (isnumeric(fit_method) && isscalar(fit_method))
        if fit_method
            method_str = 'adaptive_ga';
        else
            method_str = 'grid';
        end
    else
        method_str = lower(strtrim(char(string(fit_method))));
    end
    
    valid_methods = {'grid', 'adaptive_ga', 'simple_ga'};
    if ~ismember(method_str, valid_methods)
        error('unknown fit_method "%s". Use grid, adaptive_ga, simple_ga.', method_str);
    end
end

function S = gather_spectrum_struct(S_gpu)
    S = S_gpu;
    fields = fieldnames(S);
    for k = 1:numel(fields)
        if isa(S.(fields{k}), 'gpuArray')
            S.(fields{k}) = gather(S.(fields{k}));
        end
    end
end

function out_fit_i = apply_fit_algorithm(Spectrum, fit_param, depth, method_str)
    global USE_GPU_FLAG;
    if isempty(USE_GPU_FLAG)
        USE_GPU_FLAG = true;
    end
    
    switch method_str
        case 'grid'
            if USE_GPU_FLAG
                out_fit_i = Grid_Search_GPU(Spectrum, fit_param, depth);
            else
                out_fit_i = fit_Spectrum2dispersionRelation(Spectrum, fit_param, depth);
            end
        case 'adaptive_ga'
            out_fit_i = Adaptive_Gradient_Ascent(Spectrum, fit_param, depth, [0, 0]);
        case 'simple_ga'
            out_fit_i = Simple_Gradient_Ascent(Spectrum, fit_param, depth);
    end
end