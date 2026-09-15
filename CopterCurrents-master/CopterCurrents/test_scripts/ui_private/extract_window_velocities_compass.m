function window_velocities = extract_window_velocities_compass(STCFIT)
n = STCFIT.Windows.N_fit_windows;
window_velocities = cell(n, 1);

% Transformation parameters
heading = STCFIT.Generic.heading; % Drone heading relative to north [deg]
currentdir_flag = 1;              % 1 = "flow toward" direction (map convention)

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
    
    % Geographic transformation (camera frame -> compass/UTM)
    if isfinite(Ux) && isfinite(Uy)
        % 1. Sign flip for "flow toward" convention
        if currentdir_flag == 1
            Ux = -Ux;
            Uy = -Uy;
        end
        
        % 2. Rotate velocity vector by drone heading
        % rotatePoint3d expects a single row vector [1 x 3]
        rot_vector = rotatePoint3d([Ux, Uy, 0], heading, 0, 0);
        Ux = rot_vector(1);
        Uy = rot_vector(2);
    end
    
    window_velocities{i} = [Ux, Uy];
end
end