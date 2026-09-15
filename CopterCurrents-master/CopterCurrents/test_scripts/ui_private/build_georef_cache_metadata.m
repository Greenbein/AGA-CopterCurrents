function cache_meta = build_georef_cache_metadata(video_fname, dt, time_limits, offset_home2water_Z, calib_file)
cache_meta = struct();
cache_meta.video_path = char(string(video_fname));
cache_meta.video_info = safe_file_info(video_fname);
cache_meta.dt = dt;
cache_meta.time_limits = time_limits(:).';
cache_meta.offset_home2water_Z = offset_home2water_Z;
cache_meta.calibration_path = char(string(calib_file));
cache_meta.calibration_info = safe_file_info(calib_file);
end
