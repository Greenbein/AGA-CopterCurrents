% Gradient Descent for fitting the dispersion relation
% Input:
%   Spectrum: spectrum structure
%   fit_param: fit parameters
%   water_depth: water depth
% Output:
%   fit_out: fit output

% I did not implemnted the smart regularization with penalty for large
% velocity variance
% However
% Here I did implemented:
    % 1.simple step decay when the loss is not improving
    % 2.the clipping of the gradient when it is too large
    % 3.the convergence check when the gradient is very small and the loss is not improving

function fit_out = Simple_Gradient_Ascent(Spectrum, fit_param, water_depth)

    % ============================================================================
    % CONSTANTS
    % ============================================================================
    DEBUG = false;   % flag for verbose output (for debugging)
    
    % Physical constants
    g = 9.81;        % gravitational acceleration [m/s^2]
    
    % Sigma (smoothing width) parameters
    SIGMA_MULTIPLIER = 0.5;      % sigma = w_width_FG * SIGMA_MULTIPLIER
    SIGMA_DEFAULT = 0.2;         % default sigma if invalid
    D_CLIP_MULTIPLIER = 10;      % D clipping: [-D_CLIP_MULTIPLIER*sigma, +D_CLIP_MULTIPLIER*sigma]
    
    % Gradient descent parameters
    STEP_INITIAL = 0.5;           % initial GD step size
    STEP_MIN = 0.01;              % minimum step for adaptive algorithm
    STEP_DECAY = 0.95;            % step reduction factor when no improvement
    MAX_ITER = 100;               % maximum number of iterations
    
    % Gradient clipping parameters
    GRAD_CLIP_THRESHOLD = 100;    % clip gradient if norm exceeds this value
    GRAD_CLIP_NORM = 100;         % maximum gradient norm after clipping
    
    % Convergence parameters
    CONV_GRAD_THRESHOLD = 1e-6;   % stop if gradient norm < this value
    CONV_LOSS_THRESHOLD = 1e-6;   % stop if loss change < this value * |L_prev|
    CONV_GRAD_MIN_ITER = 5;       % minimum iterations before checking gradient convergence
    CONV_LOSS_MIN_ITER = 10;      % minimum iterations before checking loss convergence
    
    % Adaptive step parameters
    NO_IMPROVE_THRESHOLD = 5;     % reduce step after this many iterations without improvement
    
    % Debug output parameters
    DEBUG_PRINT_FREQ = 10;         % print iteration info every N iterations
    
    % Initial guess
    U_INITIAL = [0, 0];           % initial guess for Ux, Uy [m/s]
    
    % ============================================================================
    % INITIALIZATION
    % ============================================================================
    
    % Compute sigma from fit parameters
    sigma = fit_param.w_width_FG * SIGMA_MULTIPLIER;
    if ~isfinite(sigma) || sigma <= 0
        warning('Simple_Gradient_Ascent: sigma invalid, using default %.2f', SIGMA_DEFAULT);
        sigma = SIGMA_DEFAULT;
    end
    
    % Initialize optimization variables
    step = STEP_INITIAL;
    max_iter = MAX_ITER;
    U = U_INITIAL;

    % === EXTRACT AND VECTORIZE SPECTRUM DATA ===
    P     = Spectrum.power_Spectrum(:);
    Kx    = Spectrum.Kx_3D(:);
    Ky    = Spectrum.Ky_3D(:);
    Wgrid = Spectrum.W_3D(:);

    % keep only finite values
    valid = isfinite(P) & isfinite(Kx) & isfinite(Ky) & isfinite(Wgrid);
    P     = P(valid);
    Kx    = Kx(valid);
    Ky    = Ky(valid);
    Wgrid = Wgrid(valid);

    if isempty(P)
        error('Simple_Gradient_Ascent: No valid spectral points after masking.');
    end

    % === PRECOMPUTE |k| ===
    K = sqrt(Kx.^2 + Ky.^2);

    % === DEPTH HANDLING ===
        % For high wavenumber regime, we can also neglect the
        % influence of water depth on wave dispersion as the hyperbolic
        % tangent converts to unity for large wavenumbers.
    h = water_depth;
    if ~isfinite(h) || h <= 0
        warning('Simple_Gradient_Ascent: invalid depth, using deep-water approx.');
        h = 0;
    end

    % === TIMING ARRAYS ===
    iter_times = zeros(max_iter,1);
    t_total_start = tic;
    
    % For tracking improvement
    % Initialize variables for tracking improvement
    L_prev = -inf;
    best_L = -inf;
    best_U = U;
    no_improve_count = 0;  % We use to monitor if the loss is improving
    % GD loop
    for it = 1:max_iter
        t_iter = tic;

        % ---- dispersion frequency omega0 ----
        if h == 0    % deep water: omega^2 = g k
            omega0 = sqrt(g .* K); % approximation for high wavenumber regime (was used in the article)
        else         % finite depth: omega^2 = g k tanh(kh)
            omega0 = sqrt(g .* K .* tanh(K .* h));
        end

        % ---- mismatch D ----
        % Distance between the measured spectrum and the predicted spectrum (according to the dispersion relation)
        D = Wgrid - (omega0 + Kx*U(1) + Ky*U(2));

        % ---- safe clipping of D for exponent ----
        D_clipped = max(min(D, D_CLIP_MULTIPLIER*sigma), -D_CLIP_MULTIPLIER*sigma);

        % ---- Gaussian kernel ----
        % Parzen window function (smoothed window function)
        W = exp(-(D_clipped.^2) ./ (2*sigma^2));

        % ---- Loss (smooth "energy on dispersion") ----
        L = sum(P .* W);

        % ---- gradient calculation ----
        common = P .* W .* (D_clipped ./ (sigma^2));
        dL_dUx = sum(common .* Kx);
        dL_dUy = sum(common .* Ky);
        grad   = [dL_dUx, dL_dUy];
        grad_norm = norm(grad);

        if DEBUG && it == 1
            fprintf('DEBUG sigma=%.4g, depth=%.4g\n', sigma, h);
            fprintf('DEBUG grad = [%.3e, %.3e], norm = %.3e\n', grad(1), grad(2), grad_norm);
        end

        % ---- gradient ascent ----
        % Use original gradient directly
        % If gradient is very large, clip it for stability
        if grad_norm > GRAD_CLIP_THRESHOLD
            grad = grad / grad_norm * GRAD_CLIP_NORM;  % limit maximum norm
            if DEBUG && it <= 3
                fprintf('DEBUG: Clipping large gradient, new norm = %.3e\n', norm(grad));
            end
        end
        
        U_new = U + step * grad;
        
        % Check for improvement
        if L > best_L
            best_L = L;
            best_U = U_new;
            no_improve_count = 0;
        else
            no_improve_count = no_improve_count + 1;
            % Reduce step if no improvement
            if no_improve_count > NO_IMPROVE_THRESHOLD && step > STEP_MIN
                step = max(step * STEP_DECAY, STEP_MIN);
                if DEBUG
                    fprintf('DEBUG: Reducing step to %.4f\n', step);
                end
            end
        end
        
        U = U_new;

        iter_times(it) = toc(t_iter);

        % Print iteration info (only in DEBUG mode)
        if DEBUG && (mod(it, DEBUG_PRINT_FREQ) == 0 || it == 1)
            fprintf("Iter %d: Loss = %.4f, U = [%.3f, %.3f], step = %.4f\n", ...
                    it, L, U(1), U(2), step);
        end
        
        % Convergence check: if gradient is very small, stop
        if grad_norm < CONV_GRAD_THRESHOLD && it > CONV_GRAD_MIN_ITER
            if DEBUG
                fprintf("Converged: gradient norm = %.3e < %.3e\n", grad_norm, CONV_GRAD_THRESHOLD);
            end
            break;
        end
        
        % Check: if improvement is very small, stop
        if it > CONV_LOSS_MIN_ITER && abs(L - L_prev) < CONV_LOSS_THRESHOLD * abs(L_prev)
            if DEBUG
                fprintf("Converged: loss change = %.3e < threshold\n", abs(L - L_prev));
            end
            break;
        end
        
        L_prev = L;
    end

    total_time = toc(t_total_start);
    
    % Use best found value
    U = best_U;

 
    Ux_fit = U(1);
    Uy_fit = U(2);
    
    % Compute SNR for found velocities
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
        'SNR_max',            SNR_max, ...           % FIXED: compute real SNR
        'SNR_density_max',    SNR_density_max, ...   % FIXED: compute real SNR_density
        'Ux_2D',              [], ...
        'Uy_2D',              [] );

    SG_fit = FG_fit;   % copy for compatibility with original format

    % Can add useful fields directly:
    fit_out = struct( ...
        'FG_fit',        FG_fit, ...
        'SG_fit',        SG_fit, ...
        'U',             U, ...
        'loss',          L, ...
        'timing',        struct( ...
            'total_time',     total_time, ...
            'iter_times',     iter_times, ...
            'mean_iter_time', mean(iter_times) ...
        ) ...
    );

    % Display result in the same format as original function
    disp(['Ux_SG: ' num2str(Ux_fit) ' m/s   Uy_SG: ' num2str(Uy_fit) ' m/s   SNR density: ' num2str(SNR_density_max) ]);
    
    % Print timing summary only in DEBUG mode
    if DEBUG
        fprintf("\n=== GD Timing Summary ===\n");
        fprintf("Total GD time: %.4f s\n", total_time);
        fprintf("Mean iteration time: %.4f s\n", mean(iter_times));
        fprintf("Iterations: %d\n", it);
        fprintf("==========================\n");
    end
end

% ============================================================================
% Local function: Compute SNR for given velocities
% ============================================================================
function [SNR_max, SNR_density_max] = compute_SNR_for_velocities(...
    Spectrum, water_depth, Ux_fit, Uy_fit, w_width_SG, DEBUG)
% Compute Signal-to-Noise Ratio for found velocity vector
%
% Inputs:
%   Spectrum: Spectrum structure with power_Spectrum field
%   water_depth: water depth in meters
%   Ux_fit: fitted velocity in x direction [m/s]
%   Uy_fit: fitted velocity in y direction [m/s]
%   w_width_SG: filter width for second guess [rad/s]
%   DEBUG: debug flag for verbose output
%
% Outputs:
%   SNR_max: signal-to-noise ratio (signal_sum / noise_sum)
%   SNR_density_max: signal-to-noise density ratio (average signal / average noise)

    % Get dispersion relation mask for found velocity vector
    DS_3D_mask = get_Dispersion_Relation_3D_mask(Spectrum, water_depth, Ux_fit, Uy_fit, w_width_SG);
    
    % Compute signal and noise
    signal = Spectrum.power_Spectrum(DS_3D_mask);
    noise = Spectrum.power_Spectrum(DS_3D_mask==0);
    
    % Sum signal and noise values
    signal_sum = nansum(signal(:)); % sum of signal values in the spectrum relation
    noise_sum = nansum(noise(:)); % sum of noise values in the spectrum relation
    
    % Count finite values
    signal_nvalues = sum(isfinite(signal(:))); % number of finite signal values
    noise_nvalues = sum(isfinite(noise(:))); % number of finite noise values
    
    % Compute SNR
    if noise_sum > 0 && signal_nvalues > 0 && noise_nvalues > 0
        SNR_max = signal_sum / noise_sum;
        SNR_density_max = (signal_sum / signal_nvalues) / (noise_sum / noise_nvalues);
    else
        SNR_max = 0;
        SNR_density_max = 0;
        warning('compute_SNR_for_velocities: Could not compute SNR, using zero values');
    end
    
    % Debug output
    if DEBUG
        fprintf('DEBUG: Computed SNR_max = %.4f, SNR_density_max = %.4f\n', SNR_max, SNR_density_max);
        fprintf('DEBUG: signal_sum = %.4e, noise_sum = %.4e\n', signal_sum, noise_sum);
        fprintf('DEBUG: signal_nvalues = %d, noise_nvalues = %d\n', signal_nvalues, noise_nvalues);
    end
end
