function [grad, grad_norm] = ComputeGradientFromForward(P, W, D_eff, t, sigma, Kx, Ky)
% COMPUTEGRADIENTFROMFORWARD  Analytic dL/dU from cached forward-pass tensors.
% [grad, grad_norm] = ComputeGradientFromForward(P, W, D_eff, t, sigma, Kx, Ky)
% isolates the analytic dL/dU formula so changes to it happen in a single
% place. Caller must supply W, D_eff and t already computed by ComputeLossForward.
%
%   grad     : [dL/dUx, dL/dUy], units [s/m]
%   grad_norm: ||grad||_2

    dD_eff_dD = 1 - t.^2;  % Derivative of smooth clip (tanh-based)
    common = P .* W .* (D_eff ./ (sigma^2)) .* dD_eff_dD;
    dL_dUx = sum(common .* Kx);
    dL_dUy = sum(common .* Ky);
    grad = [dL_dUx, dL_dUy];
    grad_norm = norm(grad);
end
