function outCsv = export_adcp_to_csv(matFilePath, outCsvPath)
% EXPORT_ADCP_TO_CSV Convert ADCP .mat measurements to a tidy CSV table.
% Usage:
%   export_adcp_to_csv;                          % choose .mat and .csv via dialogs
%   export_adcp_to_csv('in.mat');                 % choose only output path
%   export_adcp_to_csv('in.mat', 'out.csv');      % fully specified
%
% Columns in the CSV:
%   time_utc        - ISO string (UTC, as in source file)
%   time_local      - ISO string (UTC+2, Israel local)
%   ve, vn          - east/north currents (base)
%   ve_windrift_i   - eastward wind drift estimate
%   vn_windrift_i   - northward wind drift estimate
%   U_total, V_total- summed surface velocities (current + wind drift)
%
% Notes:
% - Lengths are aligned to the MAX length. Shorter arrays are padded with NaN/NaT.
% - Time conversion uses +2 hours to map UTC (ADCP) -> Local (Israel).

    if nargin < 1 || isempty(matFilePath)
        [file, path] = uigetfile('*.mat', 'Select ADCP Near-Surface Velocity file');
        if isequal(file, 0)
            disp('File selection canceled.');
            outCsv = "";
            return;
        end
        matFilePath = fullfile(path, file);
    end

    if nargin < 2 || isempty(outCsvPath)
        [file, path] = uiputfile('*.csv', 'Save CSV as', 'adcp_export.csv');
        if isequal(file, 0)
            disp('Save canceled.');
            outCsv = "";
            return;
        end
        outCsvPath = fullfile(path, file);
    end

    disp(['Loading ADCP data from: ', matFilePath]);
    data = load(matFilePath);

    req = {'ve','vn','tdt','ve_windrift_i','vn_windrift_i'};
    if ~all(isfield(data, req))
        error('Missing required variables. Need: %s', strjoin(req, ', '));
    end

    % The file has been fixed by Aviv, so lengths should match.
    % We will use min_len just to be perfectly safe, but they should all be 61.
    n_ve  = numel(data.ve);
    n_vn  = numel(data.vn);
    n_tdt = numel(data.tdt);
    n_vew = numel(data.ve_windrift_i);
    n_vnw = numel(data.vn_windrift_i);
    min_len = min([n_ve, n_vn, n_tdt, n_vew, n_vnw]);

    if min_len ~= n_tdt
        warning('Lengths still differ! Using minimum length: %d', min_len);
    end

    ve   = data.ve(1:min_len);
    vn   = data.vn(1:min_len);
    ve_w = data.ve_windrift_i(1:min_len);
    vn_w = data.vn_windrift_i(1:min_len);
    tdt_raw = data.tdt(1:min_len);

    % Normalize time to datetime (UTC) and local (+2h)
    t_utc = normalize_time_to_datetime(tdt_raw);
    t_local = t_utc + hours(2);

    % Compute totals (NaN-safe)
    U_total = ve(:) + ve_w(:);
    V_total = vn(:) + vn_w(:);

    % Build table with ISO strings for portability
    tbl = table( ...
        string(datestr(t_utc,   'yyyy-mm-dd HH:MM:SS.FFF')), ...
        string(datestr(t_local, 'yyyy-mm-dd HH:MM:SS.FFF')), ...
        ve(:), vn(:), ve_w(:), vn_w(:), U_total(:), V_total(:), ...
        'VariableNames', {'time_utc','time_local','ve','vn','ve_windrift_i','vn_windrift_i','U_total','V_total'});

    writetable(tbl, outCsvPath);
    disp(['CSV written: ', outCsvPath]);
    outCsv = outCsvPath;
end

function dt = normalize_time_to_datetime(t)
    if isdatetime(t)
        dt = t;
    elseif isnumeric(t)
        dt = datetime(t, 'ConvertFrom', 'datenum');
    elseif isduration(t)
        dt = datetime(days(t), 'ConvertFrom', 'datenum');
    else
        error('Unsupported time type for tdt.');
    end
end

