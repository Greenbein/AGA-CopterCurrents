function [CamPos_ST, stage_times] = ui_step_01_camera_metadata(video_fname, stage_times, matlab_root)
% UI_STEP_01_CAMERA_METADATA  Step 1: video metadata (MediaInfo, cache, or dialog).
    t_stage = tic;
    if nargin < 3 || isempty(matlab_root)
        matlab_root = get_matlab_root();
    end
    CamPos_ST = resolve_camera_metadata(video_fname, matlab_root);
    stage_times(1) = toc(t_stage);
end
