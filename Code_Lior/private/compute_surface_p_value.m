function p_val = compute_surface_p_value(Ux, Uy, L)
% COMPUTE_SURFACE_P_VALUE  F-test p-value for the slope of L over (Ux, Uy).
%
%   Fits the linear model L = b0 + b1*Ux + b2*Uy by least squares and
%   tests the null hypothesis H0: b1 = b2 = 0 (i.e. L surface is flat).
%   Returns the right-tail p-value of the F statistic.
%
%   The function solves the regression problem analytically: the betas come
%   from the normal equations, then the Fisher statistic is built from
%   SS_total, SS_residual, and the p-value is the regularized incomplete
%   beta function (betainc) at the corresponding tail.
%
%   Used as a statistical convergence criterion: when the local surface
%   slope is indistinguishable from zero, we have converged to the optimum.

    n = length(L);
    if n < 4
        p_val = 0.0; % Not enough data points
        return;
    end
    
    x = Ux(:);
    y = Uy(:);
    z = L(:);
    
    X = [ones(n, 1), x, y];   % design matrix for linear regression
    % beta = X \ z;             % [b0, b1, b2]
    

    %=====================================================================
    %
    %                   X\z is a slow operation
    %               Here we use (X' * X) \ (X' * z) instead
    %
    %=====================================================================
    beta = (X' * X) \ (X' * z);
    
    z_fit = X * beta;
    residuals = z - z_fit;
    
    z_mean = mean(z);
    SS_tot = sum((z - z_mean).^2);  % Total variance
    SS_res = sum(residuals.^2);     % Residual variance
    
    if SS_tot < eps(max(abs(z)))
        p_val = 1.0;
        return;
    end
    if SS_res < eps(max(abs(z)))
        p_val = 0.0;
        return;
    end
    
    SS_model = SS_tot - SS_res;
    
    df1 = 2;
    df2 = n - 3;
    MS_model = SS_model / df1;
    MS_res   = SS_res / df2;
    F_stat = MS_model / MS_res;
    
    % Right-tail p-value of the F distribution via betainc
    x_beta = df2 / (df2 + df1 * F_stat);
    p_val = betainc(x_beta, df2/2, df1/2);
end