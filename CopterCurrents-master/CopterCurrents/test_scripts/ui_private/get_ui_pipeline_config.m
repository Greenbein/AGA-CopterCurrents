function cfg = get_ui_pipeline_config(matlab_root)
% All tunable UI pipeline constants in one place.
%   Edit this function to change grid size, time window, calibration file,
%   map/SNR options, etc.

    % --- Calibration (under matlab_root / Documents/MATLAB) ---
    % cfg.calibration_mat_fname = 'Phantom4Prov2_FOV_manual_3840x2160.mat';
    % cfg.calibration_mat_fname = 'Phantom4_20220227_FOV_manual_4096x2160.mat';
    cfg.calibration_mat_fname = 'Phantom4pro20022022_Caltech_4096x2160.mat';
    cfg.calibration_file      = fullfile(matlab_root, cfg.calibration_mat_fname);

    % --- Video slice & rectification ---
    cfg.time_limits          = [5 35];   %V [s] start/end in video [5 35] for 2 minutes video
    cfg.dt                   = 0.03;    %V [s] frame spacing 0.03 for 2 minutes video
    cfg.offset_home2water_Z  = 0.5;     %V [m] 0.5 for 04.03.2022 too

    % --- STCFIT grid / fit-parameter defaults ---
    cfg.sq_size_m             = 10; %V
    cfg.sq_dist_m             = cfg.sq_size_m/2; %V
    cfg.mask_2D               = 1; %?
    cfg.water_depth_mask_2D   = 15; %V 14.5 for 04.03.2022
    cfg.waveLength_limits_m   = [0.125 10]; %V
    cfg.wavePeriod_limits_sec = [0.125 2.25]; %V

    cfg.nan_percentage_thr = 5;
    cfg.Ux_limits_FG       = [-2.0 2.0];
    cfg.Uy_limits_FG       = [-2.0 2.0];
    cfg.U_FG_res           = 0.1;
    cfg.w_width_FG         = 1;
    cfg.U_SG_res           = cfg.U_FG_res / 10;
    cfg.w_width_SG         = cfg.w_width_FG / 2;

    % --- Current maps / SNR ---
    cfg.currentdir_flag   = 1;
    cfg.SNR_thr           = 0;
    cfg.SNR_density_thr   = 0;
    cfg.arrow_scale       = 20; % 20

    % --- Timing plot labels (print_time_graphs) ---
    cfg.stage_names = { ...
        'Step 1: video and metadata', ...
        'Step 2: rectification', ...
        'Step 3: define fit params', ...
        'Step 4: run current fit', ...
        'Step 5: current maps'};
end
