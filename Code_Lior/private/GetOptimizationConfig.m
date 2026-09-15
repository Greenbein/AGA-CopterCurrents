function cfg = GetOptimizationConfig()
% GETOPTIMIZATIONCONFIG  Centralized configuration for the adaptive GA.
%   All tunable constants live here. To change a value, edit one line.
%   To make the algorithm parameterized externally, swap this function
%   for a builder that accepts overrides.
%
%   Returned struct fields (with units):
%     DEBUG                  : verbose logging toggle (logical)
%     g                      : gravitational acceleration, [m/s^2]
%     SIGMA_DEFAULT          : fallback sigma if W grid is degenerate, [rad/s]
%     D_CLIP_MULTIPLIER      : cap = this * sigma, dimensionless
%     MAX_ITER               : main loop cap, dimensionless
%     DEBUG_PRINT_FREQ       : print every N iters, dimensionless
%     MIN_POINTS_FOR_FISHER  : minimum points for RSM p-value, dimensionless
%     MAX_BACKTRACK_ITER     : backtracking halvings per outer iter, dimensionless
%
%     UPDATE_NORM_COEFFICIENT: fraction of max |U| targeted by the initial
%                              velocity update, dimensionless (0.2 = 20%)
%     STEP_MIN_BOUND         : lower clip for the adaptive INITIAL step, [m^2/s^2]
%     STEP_MAX_BOUND         : upper clip for the adaptive INITIAL step, [m^2/s^2]
%     STEP_MIN               : absolute step floor used in backtracking AND
%                              after a failed outer iteration, [m^2/s^2]
%     MIN_VEL_UPDATE         : physical noise floor for velocity update, [m/s]
%
%     TREND_P_VALUE_THRESH   : RSM convergence threshold, dimensionless
%     MIN_ITER_BEFORE_STOP   : warmup iterations before emergency stop kicks in
%
%   Units convention summary (kept here so it is co-located with the values):
%     omega0, Wgrid, D, D_eff, sigma, cap : [rad/s]
%     Kx, Ky, K                           : [rad/m]
%     U, U_MAX_X, U_MAX_Y, vel_update     : [m/s]
%     L, P, W                             : dimensionless (P is sum-normalized)
%     grad                                : [s/m] (= d(dimensionless)/d(m/s))

    cfg.DEBUG                 = true;
    cfg.g                     = 9.81;

    cfg.SIGMA_DEFAULT         = 0.2;    % used only when W grid has <2 unique values
    cfg.D_CLIP_MULTIPLIER     = 30; % NON ADAPTIVE
    cfg.MAX_ITER              = 100;

    cfg.DEBUG_PRINT_FREQ      = 10;
    cfg.MIN_POINTS_FOR_FISHER = 5;
    cfg.MAX_BACKTRACK_ITER    = 10;

    % --- Adaptive initial step (ChooseInitialStepFromGrad) ---
    cfg.UPDATE_NORM_COEFFICIENT = 0.2;   % target |U_update| ~ 20% of max |U|
    cfg.STEP_MIN_BOUND        = 1e-4;    % clip lower bound for initial step, [m^2/s^2]
    cfg.STEP_MAX_BOUND        = 1e4;     % clip upper bound for initial step, [m^2/s^2]

    % --- Backtracking / failure floor ---
    cfg.STEP_MIN              = 1e-6;    % absolute step floor [m^2/s^2] Used in Backtracking and ReduceStep
    cfg.MIN_VEL_UPDATE        = 1e-3;    % physical noise floor (1 mm/s), [m/s]
    
    % --- L convergence ---
    cfg.TREND_P_VALUE_THRESH  = 0.05;
    cfg.MIN_ITER_BEFORE_STOP  = 5;
end
