function [SNR_max, SNR_density_max] = compute_SNR_for_velocities( ...
    Spectrum, water_depth, Ux_fit, Uy_fit, w_width_SG, DEBUG)
% COMPUTE_SNR_FOR_VELOCITIES  Evaluate SNR at the fitted velocity.
%   Builds the dispersion-relation mask for (Ux_fit, Uy_fit) and water_depth,
%   then computes the ratio of in-band power to out-of-band power.

    DS_3D_mask = get_Dispersion_Relation_3D_mask( ...
        Spectrum, water_depth, Ux_fit, Uy_fit, w_width_SG);
    
    signal = Spectrum.power_Spectrum(DS_3D_mask);
    noise = Spectrum.power_Spectrum(DS_3D_mask==0);
    
    signal_sum = nansum(signal(:));
    noise_sum = nansum(noise(:));
    
    signal_nvalues = sum(isfinite(signal(:)));
    noise_nvalues = sum(isfinite(noise(:)));
    
    if noise_sum > 0 && signal_nvalues > 0 && noise_nvalues > 0
        SNR_max = signal_sum / noise_sum;
        SNR_density_max = (signal_sum / signal_nvalues) / (noise_sum / noise_nvalues);
    else
        SNR_max = 0;
        SNR_density_max = 0;
        warning('compute_SNR_for_velocities: Could not compute SNR, using zero values');
    end
    
    if DEBUG
        fprintf('DEBUG: Computed SNR_max = %.4f, SNR_density_max = %.4f\n', ...
            SNR_max, SNR_density_max);
    end
end
