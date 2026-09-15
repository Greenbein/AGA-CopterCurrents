function [IMG_SEQ, stage_times] = ui_step_02_georeference(video_fname, CamPos_ST, georef_cache_file, ...
    force_rebuild_cache, cfg, stage_times)
% UI_STEP_02_GEOREFERENCE  Step 2: load or build georeferenced IMG_SEQ cache.
    t_stage = tic;
    cache_meta = build_georef_cache_metadata(video_fname, cfg.dt, cfg.time_limits, ...
        cfg.offset_home2water_Z, cfg.calibration_file);
    [cache_hit, IMG_SEQ] = try_load_georef_cache(georef_cache_file, cache_meta, force_rebuild_cache);
    if cache_hit
        disp('Step 2 skipped: valid georeference cache loaded.');
    else
        if force_rebuild_cache
            disp('Step 2 forced: rebuilding georeference cache...');
        else
            disp('Georeference cache miss: running rectification...');
        end
        Georeference_Struct_config = create_georeference_struct( ...
            video_fname, cfg.dt, cfg.time_limits, cfg.offset_home2water_Z, ...
            cfg.calibration_file, CamPos_ST);
        IMG_SEQ = run_Georeference_Struct_config(Georeference_Struct_config);
        validate_img_seq(IMG_SEQ, cfg.dt, cfg.time_limits);
        save_georef_cache(georef_cache_file, IMG_SEQ, cache_meta);
    end
    stage_times(2) = toc(t_stage);
end

function validate_img_seq(IMG_SEQ, dt, time_limits)
if ~isstruct(IMG_SEQ) || ~isfield(IMG_SEQ, 'IMG') || isempty(IMG_SEQ.IMG)
    error('ui_step_02_georeference:EmptyIMG_SEQ', [ ...
        'Georeferencing produced no image sequence (IMG_SEQ.IMG missing).' newline newline ...
        'Common causes:' newline ...
        '  - dt = 0 or time_limits incompatible with video (use dt = 1/FPS, e.g. 0.1 for 10 fps)' newline ...
        '  - time_limits outside duration (for ~12 s light video try [0 11])' newline ...
        'Current cfg.dt = %g, cfg.time_limits = [%g %g]. Delete georeference_cache.mat and retry.'], ...
        dt, time_limits(1), time_limits(2));
end
end
