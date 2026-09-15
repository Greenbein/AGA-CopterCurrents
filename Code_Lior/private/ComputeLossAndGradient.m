function [L, grad, grad_norm] = ComputeLossAndGradient(U, omega0, Kx, Ky, Wgrid, P, cap, sigma)
% COMPUTELOSSANDGRADIENT  Convenience wrapper: forward pass + gradient.
%   Computes the loss L and the analytic gradient dL/dU at U in one call,
%   reusing the forward-pass tensors so tanh/exp are evaluated only once.

    [L, D_eff, W, t] = ComputeLossForward(U, omega0, Kx, Ky, Wgrid, P, cap, sigma);
    [grad, grad_norm] = ComputeGradientFromForward(P, W, D_eff, t, sigma, Kx, Ky);
end
