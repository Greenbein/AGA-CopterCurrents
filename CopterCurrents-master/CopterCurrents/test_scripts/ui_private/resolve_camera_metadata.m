function CamPos_ST = resolve_camera_metadata(video_fname, matlab_root)
%RESOLVE_CAMERA_METADATA  Step-1 metadata: MediaInfo, cache, or manual dialog.
%
%   Tries get_Camera_Position_Struct(video). If required fields are missing,
%   loads [video_name]_metadata_cache.mat from matlab_root/metadata_cache/
%   and/or opens an input dialog. Result is saved back to the cache file.
%
%   Required fields: LATITUDE, LONGITUDE, Height, timestamp, yaw, pitch, roll.

if nargin < 2 || isempty(matlab_root)
    matlab_root = get_matlab_root();
end

try
    from_mediainfo = get_Camera_Position_Struct(video_fname);
catch ME
    warning('resolve_camera_metadata:ParseFailed', ...
        'MediaInfo parse failed (%s). Use the metadata dialog.', ME.message);
    from_mediainfo = empty_campos_struct();
end
cached = load_metadata_cache(video_fname, matlab_root);

% Video metadata first; cache fills only still-empty fields (for the dialog).
CamPos_ST = merge_campos_structs(from_mediainfo, cached);

% Full metadata in the video file — use it and refresh cache (no dialog).
if is_campos_metadata_complete(from_mediainfo)
    disp('There is valid metadata in the video, no need for user input.');
    fprintf('  - Latitude:  %.6f\n', from_mediainfo.LATITUDE);
    fprintf('  - Longitude: %.6f\n', from_mediainfo.LONGITUDE);
    fprintf('  - Height:    %.2f m\n', from_mediainfo.Height);
    fprintf('  - Yaw:       %.2f deg\n', from_mediainfo.yaw);
    fprintf('  - Pitch:     %.2f deg\n', from_mediainfo.pitch);
    fprintf('  - Roll:      %.2f deg\n', from_mediainfo.roll);
    
    CamPos_ST = from_mediainfo;
    save_metadata_cache(video_fname, matlab_root, CamPos_ST);
    return;
end

% Missing / partial MediaInfo — dialog prefilled from cache + any parsed fields.
fprintf(['Video has no complete DJI metadata.\n' ...
    'Enter values in the dialog (from original flight video or cache).\n']);
defaults = campos_to_dialog_defaults(CamPos_ST);
answer = prompt_camera_metadata_dialog(defaults);
if isempty(answer)
    error('resolve_camera_metadata:Cancelled', ...
        'Camera metadata entry cancelled by user.');
end

CamPos_ST = dialog_answers_to_campos(answer);
if ~is_campos_metadata_complete(CamPos_ST)
    error('resolve_camera_metadata:Incomplete', ...
        'One or more metadata fields are empty or invalid.');
end

save_metadata_cache(video_fname, matlab_root, CamPos_ST);
end

%% --- completeness / merge ---

function S = empty_campos_struct()
S = struct('LONGITUDE', [], 'LATITUDE', [], 'Height', [], ...
    'timestamp', [], 'yaw', [], 'pitch', [], 'roll', [], 'extra', '');
end

function ok = is_campos_metadata_complete(S)
ok = false;
if isempty(S) || ~isstruct(S)
    return;
end
req = {'LATITUDE', 'LONGITUDE', 'Height', 'timestamp', 'yaw', 'pitch', 'roll'};
for k = 1:numel(req)
    if ~isfield(S, req{k}) || isempty(S.(req{k}))
        return;
    end
    v = S.(req{k});
    if isnumeric(v) && any(~isfinite(v(:)))
        return;
    end
end
ok = true;
end

function out = merge_campos_structs(primary, secondary)
% primary wins; secondary fills only empty fields in primary.
out = struct();
if ~isempty(primary) && isstruct(primary)
    out = primary;
end
if isempty(secondary) || ~isstruct(secondary)
    return;
end
names = fieldnames(secondary);
for k = 1:numel(names)
    f = names{k};
    if ~isfield(out, f) || isempty(out.(f))
        out.(f) = secondary.(f);
    end
end
end

%% --- cache I/O ---

function cache_file = metadata_cache_file(video_fname, matlab_root)
[~, video_name, ~] = fileparts(video_fname);
safe_name = sanitize_cache_basename(video_name);
cache_dir = fullfile(matlab_root, 'metadata_cache');
cache_file = fullfile(cache_dir, [safe_name '_metadata_cache.mat']);
end

function save_metadata_cache(video_fname, matlab_root, CamPos_ST)
cache_file = metadata_cache_file(video_fname, matlab_root);
cache_dir = fileparts(cache_file);
if exist(cache_dir, 'dir') ~= 7
    mkdir(cache_dir);
end
[~, video_name, ~] = fileparts(video_fname);
metadata_cache = struct();
metadata_cache.CamPos_ST = CamPos_ST;
metadata_cache.video_name = video_name;
metadata_cache.video_fname = video_fname;
metadata_cache.saved_at = datestr(now, 31);
save(cache_file, 'metadata_cache', '-v7.3');
end

function CamPos_ST = load_metadata_cache(video_fname, matlab_root)
CamPos_ST = [];
cache_file = metadata_cache_file(video_fname, matlab_root);
if exist(cache_file, 'file') ~= 2
    return;
end
try
    loaded = load(cache_file, 'metadata_cache');
catch
    warning('resolve_camera_metadata:CacheLoadFailed', ...
        'Could not read metadata cache: %s', cache_file);
    return;
end
if ~isfield(loaded, 'metadata_cache') || ~isstruct(loaded.metadata_cache)
    return;
end
if isfield(loaded.metadata_cache, 'CamPos_ST')
    CamPos_ST = loaded.metadata_cache.CamPos_ST;
end
end

function safe = sanitize_cache_basename(name)
safe = regexprep(char(name), '[<>:"/\\|?*]', '_');
if isempty(safe)
    safe = 'video';
end
end

%% --- dialog ---

function defaults = campos_to_dialog_defaults(S)
defaults = repmat({''}, 1, 7);
if isempty(S) || ~isstruct(S)
    return;
end
defaults{1} = field_to_str(S, 'LATITUDE');
defaults{2} = field_to_str(S, 'LONGITUDE');
defaults{3} = field_to_str(S, 'Height');
defaults{4} = timestamp_to_str(S);
defaults{5} = field_to_str(S, 'yaw');
defaults{6} = field_to_str(S, 'pitch');
defaults{7} = field_to_str(S, 'roll');
end

function s = field_to_str(S, fname)
s = '';
if isfield(S, fname) && ~isempty(S.(fname)) && isnumeric(S.(fname))
    s = num2str(S.(fname));
end
end

function s = timestamp_to_str(S)
s = '';
if ~isfield(S, 'timestamp') || isempty(S.timestamp)
    return;
end
t = S.timestamp;
if isdatetime(t)
    s = datestr(t, 31);
elseif isnumeric(t) && isfinite(t)
    s = datestr(t, 31);
else
    s = char(string(t));
end
end

function answer = prompt_camera_metadata_dialog(defaults)
prompts = { ...
    'Latitude [deg] (xyz, 1st value):', ...
    'Longitude [deg] (xyz, 2nd value):', ...
    'Height / altitude [m] (xyz, 3rd value):', ...
    'Encoded date (e.g. 2022-03-04 08:12:08):', ...
    'Yaw / heading [deg] (gyw):', ...
    'Pitch [deg] (gpt, nadir ~ -90):', ...
    'Roll [deg] (grl):'};

dlg_title = 'Camera metadata (required for georeferencing)';

answer = inputdlg(prompts, dlg_title, [1 52], defaults);
end

function CamPos_ST = dialog_answers_to_campos(answer)
lat = str2double(answer{1});
lon = str2double(answer{2});
h = str2double(answer{3});
ts = parse_metadata_timestamp(answer{4});
yaw = str2double(answer{5});
pitch = str2double(answer{6});
roll = str2double(answer{7});

if any(~isfinite([lat, lon, h, yaw, pitch, roll])) || isempty(ts) || ~isfinite(ts)
    CamPos_ST = struct();
    return;
end

CamPos_ST = struct( ...
    'LONGITUDE', lon, ...
    'LATITUDE', lat, ...
    'Height', h, ...
    'timestamp', ts, ...
    'yaw', yaw, ...
    'pitch', pitch, ...
    'roll', roll, ...
    'extra', '');
end

function ts = parse_metadata_timestamp(s)
ts = [];
s = strtrim(char(s));
if isempty(s)
    return;
end
try
    ts = datenum(s); %#ok<DATNM>
catch
    ts = [];
end
if isempty(ts) || ~isfinite(ts)
    ts = [];
end
end
