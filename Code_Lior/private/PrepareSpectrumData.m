function spec = PrepareSpectrumData(Spectrum)
    % 1) Flatten and validate the power spectrum first.
    P = Spectrum.power_Spectrum(:);
    if isempty(P)
        error('Adaptive_Gradient_Ascent:EmptySpectrum', ...
              'Spectrum.power_Spectrum is empty.');
    end
    
    % 2) Build validity mask. Coordinates are always finite (FFT-based).
    valid = isfinite(P);
    if ~any(valid)
        error('Adaptive_Gradient_Ascent:NoValidPoints', ...
              'All power spectrum values are non-finite.');
    end
    P = P(valid);
    
    % 3) Normalize to a discrete pmf so that sum(P) = 1.
    sumP = sum(P);
    if ~isfinite(sumP) || sumP <= eps(class(sumP))
        error('Adaptive_Gradient_Ascent:BadNormalization', ...
              'Invalid spectrum normalization (sum(P)=%.3e).', sumP);
    end
    P = P / sumP;
    
    % 4) Now flatten coordinates and apply the same mask.
    Kx    = Spectrum.Kx_3D(:);
    Ky    = Spectrum.Ky_3D(:);
    Wgrid = Spectrum.W_3D(:);
    Kx    = Kx(valid);
    Ky    = Ky(valid);
    Wgrid = Wgrid(valid);
    
    % 5) Assemble output.
    global USE_GPU_FLAG;
    if isempty(USE_GPU_FLAG)
        USE_GPU_FLAG = true; % Default to GPU if not set
    end
    
    if USE_GPU_FLAG
        spec.P     = gpuArray(single(P));
        spec.Kx    = gpuArray(single(Kx));
        spec.Ky    = gpuArray(single(Ky));
        spec.Wgrid = gpuArray(single(Wgrid));
        spec.K     = gpuArray(single(sqrt(Kx.^2 + Ky.^2)));
    else
        spec.P     = single(P);
        spec.Kx    = single(Kx);
        spec.Ky    = single(Ky);
        spec.Wgrid = single(Wgrid);
        spec.K     = single(sqrt(Kx.^2 + Ky.^2));
    end
end