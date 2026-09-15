function [U_new, L_new, step_accepted] = BacktrackingTryStep(U, grad, step, ...
    omega0, Kx, Ky, Wgrid, P, cap, sigma, L, L_start, U_MAX_X, U_MAX_Y, ...
    MIN_VEL_UPDATE, STEP_MIN, MAX_BACKTRACK_ITER)

    step_current = step;
    L_new = -inf;
    U_new = U;
    step_accepted = step;
    
    % Tolerance for numerical noise in backtracking acceptance
    tol = 1e-12 + 1e-10 * abs(L);
    
    for backtrack_it = 1:MAX_BACKTRACK_ITER
        % Stop if the step itself fell below the absolute floor
        if step_current < STEP_MIN
            break;
        end
        
        % Adaptive update normalized by L_start (initial loss).
        % Units: [step]*[grad]/[L_start] = (m^2/s^2)*(s/m)/(1) = m/s.
        vel_update = step_current * (grad / L_start);
        
        % Stop condition: shift is below physical noise floor (e.g. 1 mm/s)
        if norm(vel_update) < MIN_VEL_UPDATE
            break;
        end
        
        U_candidate = U + vel_update;
        
        % Clamp candidate to physical bounds from video metadata
        U_candidate(1) = max(min(U_candidate(1), U_MAX_X), -U_MAX_X);
        U_candidate(2) = max(min(U_candidate(2), U_MAX_Y), -U_MAX_Y);
        
        % Forward pass: loss at U_candidate (intermediate tensors unused here)
        L_candidate = ComputeLossForward(U_candidate, omega0, Kx, Ky, Wgrid, P, cap, sigma);
        
        if L_candidate >= L + tol
            L_new = L_candidate;
            U_new = U_candidate;
            step_accepted = step_current;
            return;
        end
        
        % No improvement: shrink the base step coefficient. The next
        % iteration recomputes vel_update with the smaller step; if either
        % the step or the velocity update falls below its floor, we exit.
        step_current = step_current * 0.5;
    end
end
