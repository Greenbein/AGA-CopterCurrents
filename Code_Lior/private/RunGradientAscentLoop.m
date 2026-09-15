function state = RunGradientAscentLoop(U_initial, bounds, omega0, spec, sigma, cap, cfg)
% RUNGRADIENTASCENTLOOP  Main adaptive gradient-ascent optimization loop.
%
%   Performs at most cfg.MAX_ITER iterations. On each iteration:
%     1. Compute loss L and gradient grad at U via ComputeLossAndGradient.
%     2. (Iter 1 only) Fix L_initial = L and seed step via
%        ChooseInitialStepFromGrad (adaptive, physically-motivated).
%     3. Run BacktrackingTryStep to find a step that improves L.
%        Step uses the L_initial-normalized formula:
%            U_new = U + step * grad / L_initial
%     4. If improvement: accept, update best-so-far.
%        If no improvement: halve step and check emergency stop
%        (velocity update below physical noise floor).
%     5. Statistical convergence check (RSM F-test on (Ux, Uy, L) history).
%
%   Returns struct `state` with everything the caller needs to assemble
%   the output: best_U, best_L, timing, and adaptive parameters.

    % --- Local aliases for brevity ---
    P     = spec.P;
    Kx    = spec.Kx;
    Ky    = spec.Ky;
    Wgrid = spec.Wgrid;
    U_MAX_X = bounds.Ux_max;
    U_MAX_Y = bounds.Uy_max;
    max_iter = cfg.MAX_ITER;
    
    % --- Iteration state ---
    U = U_initial;
    L_initial = [];
    step = [];
    step_initial = [];
    
    best_L = -inf;
    best_U = U;
    
    % --- History for RSM convergence test ---
    L_history  = zeros(max_iter, 1);
    Ux_history = zeros(max_iter, 1);
    Uy_history = zeros(max_iter, 1);
    
    % --- Timing ---
    iter_times = zeros(max_iter, 1);
    t_total_start = tic;
    
    for it = 1:max_iter
        t_iter = tic;
        
        % 1) Loss and gradient at current U
        [L, grad, grad_norm] = ComputeLossAndGradient( ...
            U, omega0, Kx, Ky, Wgrid, P, cap, sigma);
        
        % 2) First-iteration setup. The initial step is derived from the
        % gradient magnitude so that the first update is ~20% of |U_max|.
        if it == 1
            L_initial    = L;
            step         = ChooseInitialStepFromGrad(grad_norm, L_initial, bounds, cfg);
            step_initial = step;
            best_L = L;
            best_U = U;
            if cfg.DEBUG
                fprintf('DEBUG sigma=%.4g\n', sigma);
                fprintf('DEBUG grad = [%.3e, %.3e], norm = %.3e\n', ...
                        grad(1), grad(2), grad_norm);
            end
        end
        
        % 3) Backtracking line search
        [U_new, L_new, step] = BacktrackingTryStep( ...
            U, grad, step, omega0, Kx, Ky, Wgrid, P, cap, sigma, L, L_initial, ...
            U_MAX_X, U_MAX_Y, cfg.MIN_VEL_UPDATE, cfg.STEP_MIN, cfg.MAX_BACKTRACK_ITER);
        
        % 4) Accept or shrink
        if L_new > L
            U = U_new;
            L = L_new;
            if L > best_L
                best_L = L;
                best_U = U;
            end
            iter_times(it) = toc(t_iter);
            if cfg.DEBUG && (mod(it, cfg.DEBUG_PRINT_FREQ) == 0 || it == 1)
                fprintf('Iter %d: Loss = %.4f, U = [%.3f, %.3f], step = %.4f\n', ...
                        it, L, U(1), U(2), step);
            end
        else
            step = ReduceStep(step, cfg.STEP_MIN);
            iter_times(it) = toc(t_iter);
            
            % Emergency stop: physical velocity update fell below noise floor
            vel_update_norm = norm(step * (grad / L_initial));
            if vel_update_norm < cfg.MIN_VEL_UPDATE && it >= cfg.MIN_ITER_BEFORE_STOP
                if cfg.DEBUG
                    fprintf('Stopping: velocity update reduced to noise level (< %.4f m/s) without improvement\n', ...
                            cfg.MIN_VEL_UPDATE);
                end
                break;
            end
        end
        
        % Record history for RSM check (only after the if/else above so that
        % the breaking iteration does not need to write here).
        L_history(it)  = L;
        Ux_history(it) = U(1);
        Uy_history(it) = U(2);
        
        % 5) Statistical convergence: F-test on local L(Ux, Uy) surface
        if it >= cfg.MIN_POINTS_FOR_FISHER
            if CheckSurfaceConvergence(L_history, Ux_history, Uy_history, it, U, cfg)
                break;
            end
        end
    end
    
    total_time = toc(t_total_start);
    iter_times = iter_times(1:it);
    
    state.best_U         = best_U;
    state.best_L         = best_L;
    state.L_initial      = L_initial;
    state.step_initial   = step_initial;
    state.n_iter         = it;
    state.iter_times     = iter_times;
    state.total_time     = total_time;
    state.mean_iter_time = mean(iter_times);
end

% ----- Local helper: kept here because it only makes sense inside the loop -----
function converged = CheckSurfaceConvergence(L_history, Ux_history, Uy_history, it, U, cfg)
% Returns true if the local L(Ux, Uy) surface is statistically flat,
% indicating we have reached the optimum.

    LOCAL_RADIUS = 0.1;  % [m/s] window around current U for the F-test
    
    Uc_x = U(1);
    Uc_y = U(2);
    
    valid_idx = (abs(Ux_history(1:it) - Uc_x) <= LOCAL_RADIUS) & ...
                (abs(Uy_history(1:it) - Uc_y) <= LOCAL_RADIUS);
    
    Ux_local = Ux_history(1:it);  Ux_local = Ux_local(valid_idx);
    Uy_local = Uy_history(1:it);  Uy_local = Uy_local(valid_idx);
    L_local  = L_history(1:it);   L_local  = L_local(valid_idx);
    
    if length(L_local) < cfg.MIN_POINTS_FOR_FISHER
        converged = false;
        return;
    end
    
    p_val = compute_surface_p_value(Ux_local, Uy_local, L_local);
    
    if cfg.DEBUG && (mod(it, cfg.DEBUG_PRINT_FREQ) == 0)
        fprintf('RSM Points: %d, p-value: %.4f\n', length(L_local), p_val);
    end
    
    converged = p_val > cfg.TREND_P_VALUE_THRESH;
    
    if converged && cfg.DEBUG
        fprintf('Converged statistically at iter %d (RSM p-value = %.3f > %.2f)\n', ...
                it, p_val, cfg.TREND_P_VALUE_THRESH);
    end
end
