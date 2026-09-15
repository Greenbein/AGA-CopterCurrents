function omega0 = PrecomputeOmega0(K, water_depth, g)
%   Inputs:
%     K           : wavenumber magnitudes, [rad/m]
%     water_depth : [m]; non-positive or non-finite triggers deep-water mode
%     g           : gravitational acceleration, [m/s^2]
%
%   Output:
%     omega0      : same shape as K, [rad/s]

    if ~isfinite(water_depth) || water_depth <= 0
        warning('Adaptive_Gradient_Ascent: invalid depth, using deep-water approx.');
        omega0 = sqrt(g .* K);
    else
        omega0 = sqrt(g .* K .* tanh(K .* water_depth));
    end
end