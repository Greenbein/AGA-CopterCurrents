function U_initial = PrepareInitialVelocity(U_initial, bounds)
%   Inputs:
%     U_initial : [] or [Ux Uy] (row or column), [m/s]
%     bounds    : struct with fields Ux_max, Uy_max, [m/s]
%
%   Output:
%     U_initial : 1x2 row vector, clamped, [m/s]

    if isempty(U_initial)
        U_initial = [0, 0];
    end
    
    if numel(U_initial) ~= 2
        error('Adaptive_Gradient_Ascent:BadInitialU', ...
              'U_initial must be a 2-element vector [Ux Uy]');
    end
    U_initial = U_initial(:).';  % Ensure row vector
    
    U_initial(1) = max(min(U_initial(1),  bounds.Ux_max), -bounds.Ux_max);
    U_initial(2) = max(min(U_initial(2),  bounds.Uy_max), -bounds.Uy_max);
end