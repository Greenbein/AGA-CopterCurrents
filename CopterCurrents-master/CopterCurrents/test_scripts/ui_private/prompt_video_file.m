function video_fname = prompt_video_file(matlab_root)
video_fname = '';
[f, p] = uigetfile({'*.mp4;*.mov;*.avi;*.mkv','Video files';'*.*','All files'}, ...
    'Select video file', matlab_root);
if isequal(f, 0)
    answer = inputdlg({'Video file full path:'}, 'Manual video path', [1 80], {''});
    if isempty(answer) || isempty(strtrim(answer{1}))
        return;
    end
    candidate = strtrim(answer{1});
else
    candidate = fullfile(p, f);
end

if exist(candidate, 'file') ~= 2
    errordlg(['File not found: ' candidate], 'Invalid video path');
    return;
end
video_fname = candidate;
end
