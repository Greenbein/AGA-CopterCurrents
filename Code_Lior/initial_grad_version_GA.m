function fit_out = Adaptive_Gradient_Ascent_OLD(Spectrum, fit_param, water_depth, U_initial)

    DEBUG = true;
    g = 9.81;
    
    % --- Optimization Constants ---
    SIGMA_MULTIPLIER = 0.5;
    SIGMA_DEFAULT = 0.2;
    D_CLIP_MULTIPLIER = 30; % originally 10

    STEP_MIN = 0.01;              % backtracking floor [m^2/s^2] (original)
    MAX_ITER = 100;
    GRAD_CLIP_THRESHOLD = 100;
    GRAD_CLIP_NORM = 100;
    UPDATE_NORM_COEFFICIENT = 0.2; % (~20% of max |U| scale for initial step)
    STEP_MIN_BOUND = 0.1;
    STEP_MAX_BOUND = 2.0;

    DEBUG_PRINT_FREQ = 10;
    MIN_POINTS_FOR_FISHER = 5;
    MAX_BACKTRACK_ITER = 10;

    MIN_VEL_UPDATE = 1e-3; % [m/s] emergency-stop velocity floor (1 mm/s)
    
    
    % --- Statistical Convergence Parameters ---
    TREND_P_VALUE_THRESH = 0.05;
    MIN_ITER_BEFORE_STOP = 5; % Minimum iterations before emergency stop
    
    % Set U_MAX_X and U_MAX_Y from fit_param limits (if available), otherwise use default
    if isfield(fit_param, 'Ux_limits_FG') && isfield(fit_param, 'Uy_limits_FG')
        U_MAX_X = max(abs(fit_param.Ux_limits_FG(:)));
        U_MAX_Y = max(abs(fit_param.Uy_limits_FG(:)));
    else
        U_MAX_X = 2.0;  % Fallback default
        U_MAX_Y = 2.0;
    end
    
    DESIRED_UPDATE_NORM = sqrt(U_MAX_X^2 + U_MAX_Y^2) .* UPDATE_NORM_COEFFICIENT;
    
    % Default initial velocity if not provided
    if nargin < 4 || isempty(U_initial)
        U_initial = [0, 0];
    end
    
    % Validate U_initial size
    if numel(U_initial) ~= 2
        error('Adaptive_Gradient_Ascent: U_initial must be a 2-element vector [Ux Uy]');
    end
    U_initial = U_initial(:).';  % Ensure row vector [Ux Uy]
    
    % Clamp initial velocity to limits
    U_initial = [max(min(U_initial(1), U_MAX_X), -U_MAX_X), ...
                 max(min(U_initial(2), U_MAX_Y), -U_MAX_Y)];
    
    % Validate fit_param fields
    if ~isfield(fit_param, 'w_width_FG') || isempty(fit_param.w_width_FG)
        error('Adaptive_Gradient_Ascent: fit_param.w_width_FG is missing or empty');
    end
    if ~isfield(fit_param, 'w_width_SG') || isempty(fit_param.w_width_SG)
        error('Adaptive_Gradient_Ascent: fit_param.w_width_SG is missing or empty');
    end
    
    sigma = fit_param.w_width_FG * SIGMA_MULTIPLIER;
    if ~isfinite(sigma) || sigma <= 0
        warning('Adaptive_Gradient_Ascent: sigma invalid, using default %.2f', SIGMA_DEFAULT);
        sigma = SIGMA_DEFAULT;
    end
    
    % =====================================================================
    % ====================================================================
    % Adaptive Gaussian width (protection against grid quantization)
    % =====================================================================
    % =====================================================================

    % Extract raw frequency grid to estimate its physical resolution
    W_raw = Spectrum.W_3D(:);
    W_valid = W_raw(isfinite(W_raw));
    if length(W_valid) > 1
        % Keep only unique frequency values
        W_unique = unique(W_valid);
        
        if length(W_unique) > 1
            % Compute frequency grid spacing dw.
            dw = W_unique(2) - W_unique(1);

            % Gaussian must cover at least 2 grid bins
            sigma_min = 2 * dw;
            
            % Increase sigma if it is too narrow
            if sigma < sigma_min
                if DEBUG
                    fprintf('Adaptive Sigma: Increased from %.4f to %.4f (dw=%.4f) to prevent grid gaps.\n', sigma, sigma_min, dw);
                end
                sigma = sigma_min;
            end
        end
    end
    % ========================================================================
    % Precompute cap (clip threshold) once - used throughout optimization
    cap = D_CLIP_MULTIPLIER * sigma;
    
    max_iter = MAX_ITER;
    U = U_initial;
    grad_norm_initial = [];
    L_initial = [];
    step = [];
    step_initial = [];  % Store initial step separately
    
    % Preallocate history arrays for statistical convergence
    L_history = zeros(max_iter, 1);
    Ux_history = zeros(max_iter, 1);
    Uy_history = zeros(max_iter, 1);
    
    % Convert to 1D array for computational speed
    % Cache memory for 1-D arrays is more effective
    P     = Spectrum.power_Spectrum(:);
    Kx    = Spectrum.Kx_3D(:);
    Ky    = Spectrum.Ky_3D(:);
    Wgrid = Spectrum.W_3D(:);
    

    % valid = isfinite(P) & isfinite(Kx) & isfinite(Ky) & isfinite(Wgrid);
    % (kx,ky,w) are FFT coordinates,so they are 100% finite -> check only F
    valid = isfinite(P);
    P     = P(valid);
    Kx    = Kx(valid);
    Ky    = Ky(valid);
    Wgrid = Wgrid(valid);
    
    if isempty(P)
        error('Adaptive_Gradient_Ascent: No valid spectral points after masking.');
    end
    
    % Safe Normalization
    sumP = sum(P);
    if ~isfinite(sumP) || sumP <= eps(class(sumP))
        error('Adaptive_Gradient_Ascent: Invalid spectrum normalization (sum(P)=%.3e).', sumP);
    end
    P = P / sumP;
    
    K = sqrt(Kx.^2 + Ky.^2);
    
    h = water_depth;
    if ~isfinite(h) || h <= 0
        warning('Adaptive_Gradient_Ascent: invalid depth, using deep-water approx.');
        h = 0;
    end
    
    iter_times = zeros(max_iter,1);
    t_total_start = tic;
    
    % Precompute omega0 (doesn't depend on U, only on K and h)
    if h == 0
        omega0 = sqrt(g .* K);
    else
        omega0 = sqrt(g .* K .* tanh(K .* h));
    end
    
    best_L = -inf;
    best_U = U;
    
    % ========================================================================
    % MAIN OPTIMIZATION LOOP
    % ========================================================================
    for it = 1:max_iter
        t_iter = tic;
        
        % 1) Compute loss L(U) and gradient grad(U)
        [L, grad, grad_norm] = ComputeLossAndGradient(U, omega0, Kx, Ky, Wgrid, P, cap, sigma);
        
        % 2) Clip gradient if too large
        [grad, grad_norm] = ClipGradientIfTooBig(grad, grad_norm, GRAD_CLIP_THRESHOLD, GRAD_CLIP_NORM, DEBUG, it);

        % 3) On first iteration: choose initial step from gradient scale
        if it == 1
            grad_norm_initial = grad_norm;
            L_initial = L;

            step = ChooseInitialStepFromGrad(grad_norm_initial, DESIRED_UPDATE_NORM, ...
                STEP_MIN_BOUND, STEP_MAX_BOUND, DEBUG);
            step_initial = step;

            best_L = L;
            best_U = U;

            if DEBUG
                fprintf('DEBUG sigma=%.4g, depth=%.4g\n', sigma, h);
                fprintf('DEBUG grad = [%.3e, %.3e], norm = %.3e\n', grad(1), grad(2), grad_norm);
            end
        end

        % 4) Line search (backtracking): find step that improves loss
        [U_new, L_new, step, backtrack_data] = BacktrackingTryStep(U, grad, step, ...
            omega0, Kx, Ky, Wgrid, P, cap, sigma, L, U_MAX_X, U_MAX_Y, STEP_MIN, MAX_BACKTRACK_ITER);

        % 5) If improvement found: accept step and update "best"
        if L_new > L
            U = U_new;
            L = L_new;
            
            if L > best_L
                best_L = L;
                best_U = U;
            end
            
            % Recompute gradient at new point for next iteration
            if ~isempty(backtrack_data.D_new_accepted) && ~isempty(backtrack_data.W_new_accepted) && ...
               ~isempty(backtrack_data.D_eff_new_accepted) && ~isempty(backtrack_data.t_new_accepted)
                [grad_new, ~] = RecomputeGradientFromBacktrackData(backtrack_data, Kx, Ky, P, cap, sigma);
                grad = grad_new;  
            end
            
            iter_times(it) = toc(t_iter);
            
            if DEBUG && (mod(it, DEBUG_PRINT_FREQ) == 0 || it == 1)
                fprintf("Iter %d: Loss = %.4f, U = [%.3f, %.3f], step = %.4f\n", ...
                        it, L, U(1), U(2), step);
            end
            
        else
            % 6) If no improvement: reduce step
            step = ReduceStep(step, 1e-8); % Provide very little number 
            % s.t. ReduceStep won't block the devision
            iter_times(it) = toc(t_iter);
            
            % Emergency stop checking physical velocity update
            if norm(step * (grad / L)) < MIN_VEL_UPDATE && it > MIN_ITER_BEFORE_STOP
                if DEBUG
                    fprintf("Stopping: velocity update reduced to noise level (< %.4f m/s) without improvement\n", MIN_VEL_UPDATE);
                end
                
                L_history(it) = L;
                Ux_history(it) = U(1);
                Uy_history(it) = U(2);
                break;
            end
        end
        
        % ====================================================================
        % Record history at the end of iteration for ALL cases 
        % ====================================================================
        L_history(it) = L;
        Ux_history(it) = U(1);
        Uy_history(it) = U(2);
        
        % =================================================================
        % 7) RSM 3D Convergence Check
        % =================================================================
        if it >= MIN_POINTS_FOR_FISHER
            % Current [Ux,Uy]
            Uc_x = U(1);
            Uc_y = U(2);
            
            % Mask for (10 cm/sec range)
            valid_idx = (abs(Ux_history(1:it) - Uc_x) <= 0.1) & ...
                        (abs(Uy_history(1:it) - Uc_y) <= 0.1);
            
            % Find 
            Ux_local = Ux_history(1:it);
            Uy_local = Uy_history(1:it);
            L_local  = L_history(1:it);
            Ux_local = Ux_local(valid_idx);
            Uy_local = Uy_local(valid_idx);
            L_local  = L_local(valid_idx);
            
            if length(L_local) >= MIN_POINTS_FOR_FISHER
                % Calcualate F_value and p_value
                p_val_surface = compute_surface_p_value(Ux_local, Uy_local, L_local);
                
                if DEBUG && (mod(it, DEBUG_PRINT_FREQ) == 0)
                    fprintf('RSM Points: %d, p-value: %.4f\n', length(L_local), p_val_surface);
                end
                % If the tilt is identical to noise, we are in the optimum
                if p_val_surface > TREND_P_VALUE_THRESH
                    if DEBUG
                        fprintf('Converged statistically at iter %d (RSM p-value = %.3f > %.2f)\n', ...
                            it, p_val_surface, TREND_P_VALUE_THRESH);
                    end
                    break;
                end
            end
        end
    end
    
    total_time = toc(t_total_start);
    U = best_U;
    L = best_L;
    
    % Trim iter_times to actual iterations before computing mean
    iter_times = iter_times(1:it);
    mean_iter_time = mean(iter_times);
    
    Ux_fit = U(1);
    Uy_fit = U(2);
    
    [SNR_max, SNR_density_max] = compute_SNR_for_velocities(...
        Spectrum, water_depth, Ux_fit, Uy_fit, fit_param.w_width_SG, DEBUG);
    
    FG_fit = struct( ...
        'signal_2D',          [], ...
        'noise_2D',           [], ...
        'signal_nvalues_2D',  [], ...
        'noise_nvalues_2D',   [], ...
        'SNR_2D',             [], ...
        'SNR_density_2D',     [], ...
        'Ux_fit',             Ux_fit, ...
        'Uy_fit',             Uy_fit, ...
        'SNR_max',            SNR_max, ...
        'SNR_density_max',    SNR_density_max, ...
        'Ux_2D',              [], ...
        'Uy_2D',              [] );
    
    SG_fit = FG_fit;
    
    fit_out = struct( ...
        'FG_fit',        FG_fit, ...
        'SG_fit',        SG_fit, ...
        'U',             U, ...
        'loss',          L, ...
        'adaptive_params', struct( ...
            'grad_norm_initial',    grad_norm_initial, ...
            'L_initial',            L_initial, ...
            'step_initial',         step_initial ...  
        ), ...
        'timing',        struct( ...
            'total_time',     total_time, ...
            'iter_times',     iter_times, ...
            'mean_iter_time', mean_iter_time ...  
        ) ...
    );
    
    disp(['Ux_SG: ' num2str(Ux_fit) ' m/s   Uy_SG: ' num2str(Uy_fit) ' m/s   SNR density: ' num2str(SNR_density_max) ]);
    
    if DEBUG
        fprintf("\n=== Adaptive GD Timing Summary ===\n");
        fprintf("Total GD time: %.4f s\n", total_time);
        fprintf("Mean iteration time: %.4f s\n", mean_iter_time);
        fprintf("Iterations: %d\n", it);
        fprintf("Initial step: %.4f\n", step_initial);
        fprintf("==========================\n");
    end
end

% ============================================================================
% Helper functions for main optimization loop
% ============================================================================

function [L, grad, grad_norm] = ComputeLossAndGradient(U, omega0, Kx, Ky, Wgrid, P, cap, sigma)
    % Calcualte L and temp variables
    [L, D_eff, W, t] = ComputeLossForward(U, omega0, Kx, Ky, Wgrid, P, cap, sigma);
    
    % Calculate gradient
    dD_eff_dD = 1 - t.^2;  % Derivative of smooth clip
    common = P .* W .* (D_eff ./ (sigma^2)) .* dD_eff_dD;
    dL_dUx = sum(common .* Kx);
    dL_dUy = sum(common .* Ky);
    grad = [dL_dUx, dL_dUy];
    grad_norm = norm(grad);
end

function [grad_clipped, grad_norm_clipped] = ClipGradientIfTooBig(grad, grad_norm, GRAD_CLIP_THRESHOLD, GRAD_CLIP_NORM, DEBUG, it)
    grad_clipped = grad;
    grad_norm_clipped = grad_norm;

    if grad_norm > GRAD_CLIP_THRESHOLD
        grad_clipped = grad / grad_norm * GRAD_CLIP_NORM;
        grad_norm_clipped = norm(grad_clipped);
        fprintf('Gradient clipping at iter %d: norm %.3e -> %.3e (threshold %.3e)\n', ...
            it, grad_norm, grad_norm_clipped, GRAD_CLIP_THRESHOLD);
    end
end

function step = ChooseInitialStepFromGrad(grad_norm_initial, desired_update_norm, step_min_bound, step_max_bound, DEBUG)
    if grad_norm_initial > 0
        step = desired_update_norm / grad_norm_initial;
        step = max(step_min_bound, min(step_max_bound, step));

        if DEBUG
            fprintf('ADAPTIVE: Initial gradient norm = %.3e\n', grad_norm_initial);
            fprintf('ADAPTIVE: Computed initial step = %.4f\n', step);
        end
    else
        step = step_min_bound;
        warning('ChooseInitialStepFromGrad: Initial gradient norm is zero, using fallback step');
    end
end

function [U_new, L_new, step_accepted, backtrack_data] = BacktrackingTryStep(U, grad, step, ...
    omega0, Kx, Ky, Wgrid, P, cap, sigma, L, U_MAX_X, U_MAX_Y, STEP_MIN, MAX_BACKTRACK_ITER)

    step_current = step;
    L_new = -inf;
    U_new = U;
    step_accepted = step;

    backtrack_data = struct('D_new_accepted', [], 'D_eff_new_accepted', [], ...
        'W_new_accepted', [], 't_new_accepted', []);

    % Tolerance for numerical noise in backtracking acceptance
    tol = 1e-12 + 1e-10 * abs(L);

    for backtrack_it = 1:MAX_BACKTRACK_ITER
        U_candidate = U + step_current * grad;
        U_candidate(1) = max(min(U_candidate(1), U_MAX_X), -U_MAX_X);
        U_candidate(2) = max(min(U_candidate(2), U_MAX_Y), -U_MAX_Y);

        D_new = Wgrid - (omega0 + Kx*U_candidate(1) + Ky*U_candidate(2));

        z_new = D_new / cap;
        t_new = tanh(z_new);
        D_eff_new = cap * t_new;
        W_new = exp(-(D_eff_new.^2) ./ (2*sigma^2));
        L_candidate = sum(P .* W_new);

        % Accept any numerically meaningful improvement
        required_improvement = tol;

        if L_candidate >= L + required_improvement
            L_new = L_candidate;
            U_new = U_candidate;
            step_accepted = step_current;

            backtrack_data.D_new_accepted = D_new;
            backtrack_data.D_eff_new_accepted = D_eff_new;
            backtrack_data.W_new_accepted = W_new;
            backtrack_data.t_new_accepted = t_new;
            break;
        else
            step_current = step_current * 0.5;
            if step_current < STEP_MIN
                break;
            end
        end
    end
end

function [grad_new, grad_norm] = RecomputeGradientFromBacktrackData(backtrack_data, Kx, Ky, P, cap, sigma)
    if ~isempty(backtrack_data.D_new_accepted) && ~isempty(backtrack_data.W_new_accepted) && ...
       ~isempty(backtrack_data.D_eff_new_accepted) && ~isempty(backtrack_data.t_new_accepted)
        
        dD_eff_dD_new = 1 - backtrack_data.t_new_accepted.^2;
        common_new = P .* backtrack_data.W_new_accepted .* ...
            (backtrack_data.D_eff_new_accepted ./ (sigma^2)) .* dD_eff_dD_new;
            
        dL_dUx_new = sum(common_new .* Kx);
        dL_dUy_new = sum(common_new .* Ky);
        grad_new = [dL_dUx_new, dL_dUy_new];
        grad_norm = norm(grad_new);
    else
        grad_new = [];
        grad_norm = inf;
    end
end

function step_reduced = ReduceStep(step, min_bound)
    step_reduced = max(step * 0.5, min_bound);
end

function [SNR_max, SNR_density_max] = compute_SNR_for_velocities(Spectrum, water_depth, Ux_fit, Uy_fit, w_width_SG, DEBUG)
    DS_3D_mask = get_Dispersion_Relation_3D_mask(Spectrum, water_depth, Ux_fit, Uy_fit, w_width_SG);
    
    signal = Spectrum.power_Spectrum(DS_3D_mask);
    noise = Spectrum.power_Spectrum(DS_3D_mask==0);
    
    signal_sum = nansum(signal(:));
    noise_sum = nansum(noise(:));
    
    signal_nvalues = sum(isfinite(signal(:)));
    noise_nvalues = sum(isfinite(noise(:)));
    
    if noise_sum > 0 && signal_nvalues > 0 && noise_nvalues > 0
        SNR_max = signal_sum / noise_sum;
        SNR_density_max = (signal_sum / signal_nvalues) / (noise_sum / noise_nvalues);
    else
        SNR_max = 0;
        SNR_density_max = 0;
        warning('compute_SNR_for_velocities: Could not compute SNR, using zero values');
    end
    
    if DEBUG
        fprintf('DEBUG: Computed SNR_max = %.4f, SNR_density_max = %.4f\n', SNR_max, SNR_density_max);
    end
end

% ============================= NEW =======================================
    % The function solves linear regression problem analitically
    % B vector describes the sample plane
    % With z_mean, SS_tot and SS_res we can compute a Fisher value
    % p_value is an integreal of Fisher function from the Fisher value to +inf
    % comparing the p_value with TREND_P_VALUE_THRESH enables check convergence
    % instead of 

function p_val = compute_surface_p_value(Ux, Uy, L)

    % Calculate p-value for L = b0 + b1*Ux + b2*Uy
    % H0: b1 = 0 and b2 = 0 (horizontal surface)

    n = length(L);
    if n < 4
        p_val = 0.0; % Not enough data points
        return;
    end
    
    % Prepare arrays
    x = Ux(:);
    y = Uy(:);
    z = L(:);
    
    X = [ones(n, 1), x, y]; % A natrix for linear regression
    beta = X \ z; % [b0, b1, b2]
    
    z_fit = X * beta;

    residuals = z - z_fit;
    
    % Calculations for Fisher value
    z_mean = mean(z);
    SS_tot = sum((z - z_mean).^2);  % Total chaos
    SS_res = sum(residuals.^2);     % Residual noise
    
    if SS_tot < eps(max(abs(z)))
        p_val = 1.0;
        return;
    end
    if SS_res < eps(max(abs(z)))
        p_val = 0.0;
        return;
    end
    
    SS_model = SS_tot - SS_res;
    
    % Calcualte Fisher value
    df1 = 2;
    df2 = n - 3;
    MS_model = SS_model / df1;
    MS_res   = SS_res / df2;
    F_stat = MS_model / MS_res;
    
    % Calculate p value (Integral (x from Fvalue to infinity) of Fisher d.)
    % use betainc MATLAB function
    x_beta = df2 / (df2 + df1 * F_stat);
    p_val = betainc(x_beta, df2/2, df1/2); 
end

function [L, D_eff, W, t] = ComputeLossForward(U, omega0, Kx, Ky, Wgrid, P, cap, sigma)
    D = Wgrid - (omega0 + Kx*U(1) + Ky*U(2));
    z = D / cap;
    t = tanh(z);
    D_eff = cap * t;
    W = exp(-(D_eff.^2) ./ (2*sigma^2));
    L = sum(P .* W);
end
