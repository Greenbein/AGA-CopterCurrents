function sigma = ComputeAdaptiveSigma(Spectrum, cfg)
% Returns sigma in [rad/s]

    W_raw = Spectrum.W_3D(:);
    W_unique = unique(W_raw(isfinite(W_raw)));
    
    if length(W_unique) < 2
        warning('Adaptive_Gradient_Ascent: W grid has <2 unique values, using default sigma %.2f', ...
                cfg.SIGMA_DEFAULT);
        sigma = cfg.SIGMA_DEFAULT;
        return;
    end
    
    dw = W_unique(2) - W_unique(1);
    sigma = 2 * dw;
    
    if cfg.DEBUG
        fprintf('Adaptive Sigma: %.4f rad/s (= 2 * dw, dw = %.4f)\n', sigma, dw);
    end
end


% =============================================================================
% Previous implementation (kept for reference).
%
% The original logic took sigma from fit_param.w_width_FG and only raised it
% to 2*dw when the grid was too coarse:
%
%     sigma = max(w_width_FG * SIGMA_MULTIPLIER, 2 * dw)
%
% Empirically, for typical recording lengths (8-16 sec) we have dw > 0.25
% rad/s, so 2*dw > 0.5 > w_width_FG*0.5, and the second branch always won.
% The w_width_FG branch was therefore dead weight and removed.
% =============================================================================
%{
function sigma = ComputeAdaptiveSigma(fit_param, Spectrum, cfg)
    if ~isfield(fit_param, 'w_width_FG') || isempty(fit_param.w_width_FG)
        error('Adaptive_Gradient_Ascent:MissingField', ...
              'fit_param.w_width_FG is missing or empty');
    end
    if ~isfield(fit_param, 'w_width_SG') || isempty(fit_param.w_width_SG)
        error('Adaptive_Gradient_Ascent:MissingField', ...
              'fit_param.w_width_SG is missing or empty');
    end
    
    sigma = fit_param.w_width_FG * cfg.SIGMA_MULTIPLIER;
    if ~isfinite(sigma) || sigma <= 0
        warning('Adaptive_Gradient_Ascent: sigma invalid, using default %.2f', ...
                cfg.SIGMA_DEFAULT);
        sigma = cfg.SIGMA_DEFAULT;
    end
    
    % Adaptive widening against grid quantization
    W_raw = Spectrum.W_3D(:);
    W_valid = W_raw(isfinite(W_raw));
    if length(W_valid) <= 1
        return;
    end
    W_unique = unique(W_valid);
    if length(W_unique) <= 1
        return;
    end
    
    dw = W_unique(2) - W_unique(1);
    sigma_min = 2 * dw;  % Gaussian must cover at least 2 grid bins
    
    if sigma < sigma_min
        if cfg.DEBUG
            fprintf('Adaptive Sigma: Increased from %.4f to %.4f (dw=%.4f) to prevent grid gaps.\n', ...
                    sigma, sigma_min, dw);
        end
        sigma = sigma_min;
    end
end
%}
