function ValidateFitParam(fit_param)
    if ~isfield(fit_param, 'w_width_SG') || isempty(fit_param.w_width_SG)
        error('Adaptive_Gradient_Ascent:MissingField', ...
              'fit_param.w_width_SG is missing or empty');
    end
end
