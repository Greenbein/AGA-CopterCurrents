function bounds = GetVelocityBounds(fit_param)
% GETVELOCITYBOUNDS  Extract physical velocity limits from fit_param.
%   If fit_param has Ux_limits_FG / Uy_limits_FG, use those as bounds;
%   otherwise fall back to +/- 2.0 m/s.
%
%   Returns struct: bounds.Ux_max, bounds.Uy_max  (both positive scalars, [m/s])

    FALLBACK_MAX = 2.0;  % [m/s]
    
    if isfield(fit_param, 'Ux_limits_FG') && isfield(fit_param, 'Uy_limits_FG')
        bounds.Ux_max = max(abs(fit_param.Ux_limits_FG(:)));
        bounds.Uy_max = max(abs(fit_param.Uy_limits_FG(:)));
    else
        bounds.Ux_max = FALLBACK_MAX;
        bounds.Uy_max = FALLBACK_MAX;
    end
end
