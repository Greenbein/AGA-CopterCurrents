function tf = is_georef_cache_valid(cached_meta, expected_meta)
tf = false;
required_fields = {'video_path','dt','time_limits','offset_home2water_Z', ...
    'calibration_path','video_info','calibration_info'};
for i = 1:numel(required_fields)
    if ~isfield(cached_meta, required_fields{i}) || ~isfield(expected_meta, required_fields{i})
        return;
    end
end

same_video = strcmp(cached_meta.video_path, expected_meta.video_path) && ...
    isequaln(cached_meta.video_info, expected_meta.video_info);
same_calib = strcmp(cached_meta.calibration_path, expected_meta.calibration_path) && ...
    isequaln(cached_meta.calibration_info, expected_meta.calibration_info);
same_params = isequaln(cached_meta.dt, expected_meta.dt) && ...
    isequaln(cached_meta.time_limits, expected_meta.time_limits) && ...
    isequaln(cached_meta.offset_home2water_Z, expected_meta.offset_home2water_Z);

tf = same_video && same_calib && same_params;
end
