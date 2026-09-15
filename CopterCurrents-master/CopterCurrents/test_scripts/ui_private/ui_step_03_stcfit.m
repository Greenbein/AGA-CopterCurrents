function [STCFIT, stage_times] = ui_step_03_stcfit(IMG_SEQ, base_results_dir, cfg, stage_times)
% UI_STEP_03_STCFIT  Step 3: build STCFIT grid and save overview figures.
    t_stage = tic;
    STCFIT = generate_STCFIT_from_IMG_SEQ(IMG_SEQ, cfg.sq_size_m, cfg.sq_dist_m, cfg.mask_2D, ...
        cfg.nan_percentage_thr, cfg.water_depth_mask_2D, cfg.Ux_limits_FG, cfg.Uy_limits_FG, ...
        cfg.U_FG_res, cfg.w_width_FG, cfg.U_SG_res, cfg.w_width_SG, cfg.waveLength_limits_m, ...
        cfg.wavePeriod_limits_sec);

    h = plot_STCFIT(STCFIT);
    saveas(h, fullfile(base_results_dir, 'STCFIT_squares_distribution.png'));
    saveas(h, fullfile(base_results_dir, 'Grid_image.png'));
    close(h);
    stage_times(3) = toc(t_stage);
end
