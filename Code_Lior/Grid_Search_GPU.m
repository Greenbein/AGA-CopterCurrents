function fit_out = Grid_Search_GPU(Spectrum, fit_param, water_depth)
% FIT_SPECTRUM2DISPERSIONRELATION Fit Spectrum to the waves dispersion relation.
% Accelerated with sequential GPU computing to avoid VRAM Out-of-Memory.

    % =========================================================================
    % 0. PRE-ALLOCATE AND TRANSFER DATA TO GPU (VRAM)
    % =========================================================================
    disp('Initializing Grid Search on RTX 4080 SUPER...');
    
    % Flatten and convert spectrum data to single precision for GPU
    P_gpu  = gpuArray(single(Spectrum.power_Spectrum(:)));
    Kx_gpu = gpuArray(single(Spectrum.Kx_3D(:)));
    Ky_gpu = gpuArray(single(Spectrum.Ky_3D(:)));
    W_gpu  = gpuArray(single(Spectrum.W_3D(:)));
    
    % Mask out non-finite values to prevent NaN propagation
    % valid_mask = isfinite(P_gpu) & isfinite(Kx_gpu) & isfinite(Ky_gpu) & isfinite(W_gpu);
    valid_mask = isfinite(P_gpu);
    P_gpu  = P_gpu(valid_mask);
    Kx_gpu = Kx_gpu(valid_mask);
    Ky_gpu = Ky_gpu(valid_mask);
    W_gpu  = W_gpu(valid_mask);
    
    % Pre-compute absolute wavenumber |K| and fundamental frequency omega0 on GPU
    K_gpu = sqrt(Kx_gpu.^2 + Ky_gpu.^2);
    g = 9.81;
    
    if water_depth == 0 || ~isfinite(water_depth)
        omega0_gpu = sqrt(g .* K_gpu); % Deep water
    else
        omega0_gpu = sqrt(g .* K_gpu .* tanh(K_gpu .* water_depth)); % Finite depth
    end

    % =========================================================================
    % 1. FIRST GUESS (FG) GRID SEARCH
    % =========================================================================
    Ux_FG_vec = fit_param.Ux_FG_2D(:);
    Uy_FG_vec = fit_param.Uy_FG_2D(:);
    w_width_FG = fit_param.w_width_FG;
    
    N_FG = length(Ux_FG_vec);
    signal_vec_FG     = nan(N_FG, 1, 'single');
    noise_vec_FG      = nan(N_FG, 1, 'single');
    signal_nvalues_FG = nan(N_FG, 1, 'single');
    noise_nvalues_FG  = nan(N_FG, 1, 'single');
    
    % Standard FOR loop, but all heavy math operates on gpuArrays
    for i1 = 1:N_FG
        Ux = single(Ux_FG_vec(i1));
        Uy = single(Uy_FG_vec(i1));
        
        % Calculate distance to the dispersion shell natively on GPU
        D_gpu = W_gpu - (omega0_gpu + Kx_gpu .* Ux + Ky_gpu .* Uy);
        
        % Create binary mask for the signal (within filter width)
        DS_mask = abs(D_gpu) <= w_width_FG;
        
        % Extract signal and noise subsets
        signal = P_gpu(DS_mask);
        noise  = P_gpu(~DS_mask);
        
        % Summation and counting directly on GPU, then gather to CPU loop array
        signal_vec_FG(i1)     = gather(sum(signal));
        noise_vec_FG(i1)      = gather(sum(noise));
        signal_nvalues_FG(i1) = gather(sum(DS_mask));
        noise_nvalues_FG(i1)  = gather(sum(~DS_mask));
    end
    
    % Reshape vectors back to 2D CPU matrices
    signal_FG_2D      = double(reshape(signal_vec_FG, size(fit_param.Ux_FG_2D)));
    noise_FG_2D       = double(reshape(noise_vec_FG, size(fit_param.Ux_FG_2D)));
    signal_nvalues_2D = double(reshape(signal_nvalues_FG, size(fit_param.Ux_FG_2D)));
    noise_nvalues_2D  = double(reshape(noise_nvalues_FG, size(fit_param.Ux_FG_2D)));
    
    % Calculate Signal-to-Noise Ratios
    SNR_FG         = signal_FG_2D ./ noise_FG_2D;
    SNR_density_FG = (signal_FG_2D ./ signal_nvalues_2D) ./ (noise_FG_2D ./ noise_nvalues_2D);
    
    % Retrieve best fit
    [Ux_fit_FG, Uy_fit_FG, ~, lin_ind] = retrieve_best_fit_from_SNR_2D(SNR_density_FG, fit_param.Ux_FG_2D, fit_param.Uy_FG_2D, 0, 0);
    SNR_FG_max         = SNR_FG(lin_ind);
    SNR_density_FG_max = SNR_density_FG(lin_ind);
    
    disp(['Ux_FG: ' num2str(Ux_fit_FG) ' m/s   Uy_FG: ' num2str(Uy_fit_FG) ' m/s   SNR density: ' num2str(SNR_density_FG_max)]);
    
    FG_fit = struct('signal_2D', signal_FG_2D, 'noise_2D', noise_FG_2D, ...
           'signal_nvalues_2D', signal_nvalues_2D, 'noise_nvalues_2D', noise_nvalues_2D, ...
           'SNR_2D', SNR_FG, 'SNR_density_2D', SNR_density_FG, ...
           'Ux_fit', Ux_fit_FG, 'Uy_fit', Uy_fit_FG, ...
           'SNR_max', SNR_FG_max, 'SNR_density_max', SNR_density_FG_max, ...
           'Ux_2D', fit_param.Ux_FG_2D, 'Uy_2D', fit_param.Uy_FG_2D);

    % =========================================================================
    % 2. SECOND GUESS (SG) GRID SEARCH
    % =========================================================================
    Ux_SG_2D = fit_param.Ux_SG_2D + Ux_fit_FG;
    Uy_SG_2D = fit_param.Uy_SG_2D + Uy_fit_FG;
    Ux_SG_vec = Ux_SG_2D(:);
    Uy_SG_vec = Uy_SG_2D(:);
    w_width_SG = fit_param.w_width_SG;
    
    N_SG = length(Ux_SG_vec);
    signal_vec_SG     = nan(N_SG, 1, 'single');
    noise_vec_SG      = nan(N_SG, 1, 'single');
    signal_nvalues_SG = nan(N_SG, 1, 'single');
    noise_nvalues_SG  = nan(N_SG, 1, 'single');
    
    % Second Pass GPU Loop
    for i1 = 1:N_SG
        Ux = single(Ux_SG_vec(i1));
        Uy = single(Uy_SG_vec(i1));
        
        % Native GPU calculations for the second grid
        D_gpu = W_gpu - (omega0_gpu + Kx_gpu .* Ux + Ky_gpu .* Uy);
        DS_mask = abs(D_gpu) <= w_width_SG;
        
        signal = P_gpu(DS_mask);
        noise  = P_gpu(~DS_mask);
        
        signal_vec_SG(i1)     = gather(sum(signal));
        noise_vec_SG(i1)      = gather(sum(noise));
        signal_nvalues_SG(i1) = gather(sum(DS_mask));
        noise_nvalues_SG(i1)  = gather(sum(~DS_mask));
    end
    
    % Reshape vectors back to 2D CPU matrices
    signal_SG_2D      = double(reshape(signal_vec_SG, size(Ux_SG_2D)));
    noise_SG_2D       = double(reshape(noise_vec_SG, size(Ux_SG_2D)));
    signal_nvalues_2D = double(reshape(signal_nvalues_SG, size(Ux_SG_2D)));
    noise_nvalues_2D  = double(reshape(noise_nvalues_SG, size(Ux_SG_2D)));
    
    SNR_SG         = signal_SG_2D ./ noise_SG_2D;
    SNR_density_SG = (signal_SG_2D ./ signal_nvalues_2D) ./ (noise_SG_2D ./ noise_nvalues_2D);
    
    [Ux_fit_SG, Uy_fit_SG, ~, lin_ind] = retrieve_best_fit_from_SNR_2D(SNR_density_SG, Ux_SG_2D, Uy_SG_2D, 0, 0);
    SNR_SG_max         = SNR_SG(lin_ind);
    SNR_density_SG_max = SNR_density_SG(lin_ind);
    
    disp(['Ux_SG: ' num2str(Ux_fit_SG) ' m/s   Uy_SG: ' num2str(Uy_fit_SG) ' m/s   SNR density: ' num2str(SNR_density_SG_max)]);
    
    SG_fit = struct('signal_2D', signal_SG_2D, 'noise_2D', noise_SG_2D, ...
           'signal_nvalues_2D', signal_nvalues_2D, 'noise_nvalues_2D', noise_nvalues_2D, ...
           'SNR_2D', SNR_SG, 'SNR_density_2D', SNR_density_SG, ...
           'Ux_fit', Ux_fit_SG, 'Uy_fit', Uy_fit_SG, ...
           'SNR_max', SNR_SG_max, 'SNR_density_max', SNR_density_SG_max, ...
           'Ux_2D', Ux_SG_2D, 'Uy_2D', Uy_SG_2D);
   
    % =========================================================================
    % 3. GENERATE OUTPUT
    % =========================================================================
    fit_out = struct('FG_fit', FG_fit, 'SG_fit', SG_fit);
end