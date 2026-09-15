function [STCFIT, window_timing, stage_times] = ui_step_04_fit(IMG_SEQ, STCFIT, fit_method, stage_times)
% UI_STEP_04_FIT  Step 4: run_current_fit for selected algorithm.
    t_stage = tic;
    [STCFIT, window_timing] = run_current_fit(IMG_SEQ, STCFIT, fit_method);
    stage_times(4) = toc(t_stage);
end
