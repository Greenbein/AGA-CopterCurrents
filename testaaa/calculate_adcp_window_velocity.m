function [mean_U, mean_V, U_window, V_window, time_window] = calculate_adcp_window_velocity()
% CALCULATE_ADCP_WINDOW_VELOCITY Extracts and averages ADCP data 
% within a specific time window [x + 5 sec, x + 35 sec] in Local Time.

    % 1. Open file dialog to select the ADCP .mat file
    [file, path] = uigetfile('*.mat', 'Select ADCP Near-Surface Velocity file');
    if isequal(file, 0)
        disp('File selection canceled.');
        mean_U = NaN; mean_V = NaN;
        return;
    end
    
    full_file_path = fullfile(path, file);
    disp(['Loading ADCP data from: ', full_file_path]);
    data = load(full_file_path);
    
    % Verify required variables are present
    req_vars = {'ve', 'vn', 'tdt', 've_windrift_i', 'vn_windrift_i'};
    if ~all(isfield(data, req_vars))
        error('The file does not contain all required ADCP/wind variables.');
    end
    
    % 2. Align array lengths defensively (Aviv files may differ in length)
    min_len = min([numel(data.ve), numel(data.vn), numel(data.tdt), ...
                   numel(data.ve_windrift_i), numel(data.vn_windrift_i)]);
    ve = data.ve(1:min_len);
    vn = data.vn(1:min_len);
    tdt = data.tdt(1:min_len);
    ve_windrift_i = data.ve_windrift_i(1:min_len);
    vn_windrift_i = data.vn_windrift_i(1:min_len);

    % 3. Prompt user whether to include wind drift
    wind_choice = questdlg('Include wind drift in total velocity?', ...
                           'Wind Drift Option', ...
                           'Yes (Current + Wind)', 'No (Current only)', 'Yes (Current + Wind)');
    if isempty(wind_choice)
        disp('Operation canceled by user.');
        mean_U = NaN; mean_V = NaN; U_window = []; V_window = []; time_window = [];
        return;
    end
    include_wind = strcmp(wind_choice, 'Yes (Current + Wind)');
    
    % 4. Calculate total surface current velocities
    if include_wind
        U_total = ve + ve_windrift_i;
        V_total = vn + vn_windrift_i;
    else
        U_total = ve;
        V_total = vn;
    end
    U_total = U_total(:);
    V_total = V_total(:);
    
    % 4. TIME CORRECTION: Shift ADCP UTC time to Israel Local Time (+2 hours)
    % MATLAB datenum uses 1 unit per day. 2 hours = 2 / 24 days.
    % Normalize time to datenum double, then shift to Local (+2h)
    time_local = normalize_time_to_datenum(tdt) + (2 / 24);
    time_local = time_local(:); % force column vector for consistent indexing
    
    % Dynamically fetch default date from the data to populate the dialog
    default_date = datestr(time_local(1), 'yyyy-mm-dd');
    
    % 5. Prompt user for Local Date and Time (matching UAV video metadata)
    prompt = {'Enter Date (yyyy-mm-dd):', 'Enter Local Time (HH:MM:SS):'};
    dlgtitle = 'Specify Exact UAV Timestamp';
    dims = [1 50];
    definput = {default_date, '08:12:08'};
    answer = inputdlg(prompt, dlgtitle, dims, definput);
    
    if isempty(answer)
        disp('Operation canceled by user.');
        mean_U = NaN; mean_V = NaN;
        return;
    end
    
    date_str = strtrim(answer{1});
    time_str = strtrim(answer{2});
    
    % Parse user string input into a standard MATLAB datenum
    try
        target_time_local = datenum([date_str ' ' time_str]);
    catch
        error('Invalid date or time format. Please use yyyy-mm-dd and HH:MM:SS.');
    end
    
    % 6. Define the 30-second window: [x + 5 seconds, x + 35 seconds]
    % 1 day = 86400 seconds. Convert seconds to datenum units.
    start_window = target_time_local + (5 / 86400);
    end_window = target_time_local + (35 / 86400);
    
    % Find indices falling precisely inside the interval
    idx = find(time_local >= start_window & time_local <= end_window);
    
    % Robust fallback: if window is too narrow or data is sparse, find the single nearest point
    if isempty(idx)
        warning('No ADCP samples found inside the exact window. Selecting the single closest timestamp.');
        [~, closest_idx] = min(abs(time_local - target_time_local));
        idx = closest_idx;
    end

    % Safety: ensure indices are column, within bounds, and non-empty
    idx = idx(:);
    idx = idx(idx >= 1 & idx <= numel(U_total));
    if isempty(idx)
        warning('Indexing failed after bounds check. Falling back to last available sample.');
        idx = numel(U_total);
    end
    
    % 7. Extract windowed data and compute mean values ignoring missing data (NaN)
    U_window = U_total(idx);
    V_window = V_total(idx);
    time_window = time_local(idx);
    mean_U = mean(U_window, 'omitnan');
    mean_V = mean(V_window, 'omitnan');
    
    % Print comprehensive results to Command Window
    fprintf('\n=========================================\n');
    fprintf('   ADCP WINDOW AVERAGING RESULTS (LOCAL)   \n');
    fprintf('=========================================\n');
    if include_wind
        fprintf('Configuration:     Including Wind Drift\n');
    else
        fprintf('Configuration:     Without Wind Drift\n');
    end
    fprintf('Input Local Time:  %s %s\n', date_str, time_str);
    fprintf('Window Start (+5s): %s\n', datestr(start_window, 'yyyy-mm-dd HH:MM:SS'));
    fprintf('Window End (+35s):  %s\n', datestr(end_window, 'yyyy-mm-dd HH:MM:SS'));
    fprintf('Data points found:  %d\n', numel(idx));
    fprintf('-----------------------------------------\n');
    fprintf('Mean Ux (Eastward): %.4f m/s\n', mean_U);
    fprintf('Mean Uy (Northward): %.4f m/s\n', mean_V);
    fprintf('=========================================\n');
end

function tnum = normalize_time_to_datenum(t)
% Converts various time array formats to datenum double
    if isdatetime(t)
        tnum = datenum(t);
    elseif isduration(t)
        % duration since some origin: convert to days
        tnum = days(t) + datenum(0);
    elseif isnumeric(t)
        tnum = t;
    else
        error('Unsupported time format for tdt.');
    end
end