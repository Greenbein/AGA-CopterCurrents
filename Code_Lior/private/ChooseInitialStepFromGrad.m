function step = ChooseInitialStepFromGrad(grad_norm, L_start, bounds, cfg)
% CHOOSEINITIALSTEPFROMGRAD  Physically-motivated initial step (iter 1 only).
%
%   We want the very first velocity update to have a magnitude on the
%   order of UPDATE_NORM_COEFFICIENT (e.g. 20%) of the maximum allowed
%   velocity. Since the update is
%
%       vel_update = step * grad / L_start          [m/s]
%
%   solving for step gives:
%
%       step = desired_update_norm / norm(grad / L_start)        [m^2/s^2]
%       desired_update_norm = sqrt(Ux_max^2 + Uy_max^2) * UPDATE_NORM_COEFFICIENT
%
%   The result is then clipped into [STEP_MIN_BOUND, STEP_MAX_BOUND] so
%   that pathological gradient magnitudes (very small or very large)
%   cannot make the first step explode or stall.
%
%   Inputs:
%     grad_norm : ||grad||_2 at U_initial, [s/m]
%     L_start   : L_initial (scalar, dimensionless)
%     bounds    : struct with Ux_max, Uy_max in [m/s]
%     cfg       : optimization config (see GetOptimizationConfig)
%
%   Output:
%     step      : initial step, [m^2/s^2], in [STEP_MIN_BOUND, STEP_MAX_BOUND]

    desired_update_norm = sqrt(bounds.Ux_max^2 + bounds.Uy_max^2) ...
                          * cfg.UPDATE_NORM_COEFFICIENT;
    
    % Effective gradient magnitude after the L_start normalization
    grad_over_L = grad_norm / L_start;     % [s/m]
    
    if grad_over_L > 0
        step = desired_update_norm / grad_over_L;
    else
        % Degenerate case: grad is exactly zero. Fall back to the lower clip.
        step = cfg.STEP_MIN_BOUND;
        warning('Adaptive_Gradient_Ascent: initial gradient is zero, using STEP_MIN_BOUND fallback');
    end
    
    % Clip to physical sanity range
    step = max(cfg.STEP_MIN_BOUND, min(cfg.STEP_MAX_BOUND, step));
    
    if cfg.DEBUG
        fprintf('ADAPTIVE: ||grad/L_start|| = %.3e, desired |dU| = %.3f m/s -> step = %.4g [m^2/s^2]\n', ...
                grad_over_L, desired_update_norm, step);
    end
end
