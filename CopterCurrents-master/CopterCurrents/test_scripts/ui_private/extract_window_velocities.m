function window_velocities = extract_window_velocities(STCFIT)
n = STCFIT.Windows.N_fit_windows;
window_velocities = cell(n, 1);
for i = 1:n
    Ux = NaN;
    Uy = NaN;
    if isfield(STCFIT, 'out_fit') && numel(STCFIT.out_fit) >= i
        fit_i = STCFIT.out_fit(i);
        if isfield(fit_i, 'SG_fit') && isfield(fit_i.SG_fit, 'Ux_fit') && isfield(fit_i.SG_fit, 'Uy_fit')
            Ux = fit_i.SG_fit.Ux_fit;
            Uy = fit_i.SG_fit.Uy_fit;
        elseif isfield(fit_i, 'FG_fit') && isfield(fit_i.FG_fit, 'Ux_fit') && isfield(fit_i.FG_fit, 'Uy_fit')
            Ux = fit_i.FG_fit.Ux_fit;
            Uy = fit_i.FG_fit.Uy_fit;
        end
    end
    window_velocities{i} = [Ux, Uy];
end
end
