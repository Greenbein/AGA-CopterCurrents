function fit_out = Adaptive_Gradient_Ascent(Spectrum, fit_param, water_depth, U_initial)
% ADAPTIVE_GRADIENT_ASCENT  Fit (Ux, Uy) by maximizing the dispersion-relation
%   match score over the wave spectrum, using adaptive gradient ascent with
%   backtracking line search and statistical (F-test) convergence.
%
%   USAGE:
%       fit_out = Adaptive_Gradient_Ascent(Spectrum, fit_param, water_depth)
%       fit_out = Adaptive_Gradient_Ascent(Spectrum, fit_param, water_depth, U_initial)
%
%   INPUTS:
%       Spectrum    - struct with fields power_Spectrum, Kx_3D, Ky_3D, W_3D
%       fit_param   - struct with fields:
%                       w_width_SG (required) - SG filter width for SNR
%                       Ux_limits_FG, Uy_limits_FG (optional) - velocity bounds
%                     Note: w_width_FG is accepted (CopterCurrents compatibility)
%                     but no longer used; sigma is derived from the W grid.
%       water_depth - scalar, [m]; non-positive triggers deep-water mode
%       U_initial   - optional [Ux Uy] starting velocity, [m/s]. Default [0 0].
%
%   OUTPUT:
%       fit_out     - struct with fields U, loss, FG_fit, SG_fit,
%                     adaptive_params, timing  (legacy CopterCurrents shape)
%
%   This file is a facade. The pipeline is:
%       config -> bounds -> initial U -> sigma -> spectrum prep -> omega0
%       -> optimization loop -> SNR -> output assembly -> summary
%
%   Each step lives in its own file under ./private/.

    if nargin < 4, U_initial = []; end

    cfg     = GetOptimizationConfig();
    ValidateFitParam(fit_param);
    bounds  = GetVelocityBounds(fit_param);
    U_init  = PrepareInitialVelocity(U_initial, bounds);
    sigma   = ComputeAdaptiveSigma(Spectrum, cfg);
    cap     = cfg.D_CLIP_MULTIPLIER * sigma;
    spec    = PrepareSpectrumData(Spectrum);
    omega0  = PrecomputeOmega0(spec.K, water_depth, cfg.g);

    state   = RunGradientAscentLoop(U_init, bounds, omega0, spec, sigma, cap, cfg);

    [SNR_max, SNR_density_max] = compute_SNR_for_velocities( ...
        Spectrum, water_depth, state.best_U(1), state.best_U(2), ...
        fit_param.w_width_SG, cfg.DEBUG);

    fit_out = BuildOutputStruct(state, SNR_max, SNR_density_max);
    PrintSummary(state, SNR_density_max, cfg);
end
