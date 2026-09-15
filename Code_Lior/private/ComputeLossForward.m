function [L, D_eff, W, t] = ComputeLossForward(U, omega0, Kx, Ky, Wgrid, P, cap, sigma)
% COMPUTELOSSFORWARD  Forward pass of the dispersion-matching loss.
%   [L, D_eff, W, t] = ComputeLossForward(U, omega0, Kx, Ky, Wgrid, P, cap, sigma)
%   computes L = sum(P .* W) where W = exp(-D_eff^2 / (2*sigma^2)) and
%   D_eff = cap * tanh(D/cap) is the smoothly clipped dispersion residual.
%
%   Inputs:
%     U      : [Ux, Uy] velocity, [m/s]
%     omega0 : intrinsic dispersion-relation frequency, [rad/s]
%     Kx, Ky : wavenumber components, [rad/m]
%     Wgrid  : observed angular frequencies, [rad/s]
%     P      : normalized spectral power (sum(P)=1), dimensionless
%     cap    : smooth-clip cap (D_CLIP_MULTIPLIER * sigma), [rad/s]
%     sigma  : Gaussian width, [rad/s]
%
%   Outputs (intermediate tensors are returned so callers can reuse them
%   when computing the analytic gradient):
%     L      : loss, dimensionless
%     D_eff  : smoothly clipped residual, [rad/s]
%     W      : Gaussian weights, dimensionless
%     t      : tanh(D/cap), dimensionless
    D = Wgrid - (omega0 + Kx*U(1) + Ky*U(2));
    z = D / cap;
    t = tanh(z);
    D_eff = cap * t;
    W = exp(-(D_eff.^2) ./ (2*sigma^2));
    L = sum(P .* W);
end
