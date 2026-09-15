function ui_validate_inputs(video_fname, cfg)
% UI_VALIDATE_INPUTS  Assert required files exist before long steps.
    assert(exist(video_fname, 'file') == 2, ['Video file not found: ' video_fname]);
    assert(exist(cfg.calibration_file, 'file') == 2, ...
        ['Calibration file not found: ' cfg.calibration_file]);
end
