function print_adcp_contents(matFilePath)
% PRINT_ADCP_CONTENTS Utility to inspect ADCP .mat files in detail.
% Usage:
%   print_adcp_contents;              % opens file picker
%   print_adcp_contents('file.mat');  % loads specified file

    if nargin < 1 || isempty(matFilePath)
        [file, path] = uigetfile('*.mat', 'Select ADCP Near-Surface Velocity file');
        if isequal(file, 0)
            disp('File selection canceled.');
            return;
        end
        matFilePath = fullfile(path, file);
    end

    disp(['Loading ADCP data from: ', matFilePath]);

    if ~isfile(matFilePath)
        error('File not found: %s', matFilePath);
    end

    % Summary of variables in file
    fileVars = whos('-file', matFilePath);
    disp('--- Variables in file ---');
    for k = 1:numel(fileVars)
        fv = fileVars(k);
        disp(sprintf('%s | class=%s | size=%s', fv.name, fv.class, size2str(fv.size)));
    end
    disp('-------------------------');

    data = load(matFilePath);
    varNames = fieldnames(data);

    for i = 1:numel(varNames)
        name = varNames{i};
        v = data.(name);
        fprintf('\n[%s]\n', name);
        fprintf('  class: %s\n', class(v));
        fprintf('  size : %s\n', size2str(size(v)));

        if isnumeric(v) || islogical(v)
            print_numeric_summary(v, name);
        elseif isdatetime(v)
            print_datetime_summary(v);
        elseif isduration(v)
            print_duration_summary(v);
        elseif ischar(v) || (isstring(v) && isscalar(v))
            fprintf('  value: %s\n', string(v));
        elseif isstruct(v)
            fprintf('  struct fields: %s\n', strjoin(fieldnames(v), ', '));
            % If struct fields hold numeric vectors (common for ADCP), print summaries for each field
            flds = fieldnames(v);
            for f = 1:numel(flds)
                fn = flds{f};
                fv = v.(fn);
                fprintf('    [%s.%s]\n', name, fn);
                fprintf('      class: %s\n', class(fv));
                fprintf('      size : %s\n', size2str(size(fv)));
                if isnumeric(fv) || islogical(fv)
                    print_numeric_summary(fv, fn, 6); % show a few more samples
                elseif isdatetime(fv)
                    print_datetime_summary(fv, 3, '      ');
                elseif isduration(fv)
                    print_duration_summary(fv, 3, '      ');
                elseif iscell(fv)
                    fprintf('      cell length: %d\n', numel(fv));
                else
                    fprintf('      (unhandled nested class preview)\n');
                end
            end
        elseif iscell(v)
            fprintf('  cell length: %d\n', numel(v));
        else
            fprintf('  (unhandled class preview)\n');
        end
    end

    % Extra: print aligned values of ve/vn and wind-drift inside fixed window
    required = {'tdt','ve','vn','ve_windrift_i','vn_windrift_i'};
    if all(isfield(data, required))
        try
            tdt_dt = to_datetime(data.tdt);
            ve = data.ve(:);
            vn = data.vn(:);
            ve_w = data.ve_windrift_i(:);
            vn_w = data.vn_windrift_i(:);
            min_len = min([numel(tdt_dt), numel(ve), numel(vn), numel(ve_w), numel(vn_w)]);
            tdt_dt = tdt_dt(1:min_len);
            ve = ve(1:min_len); vn = vn(1:min_len);
            ve_w = ve_w(1:min_len); vn_w = vn_w(1:min_len);

            window_start = datetime(2022,4,3,6,10,0);
            window_end   = datetime(2022,4,3,6,20,0);
            mask = tdt_dt >= window_start & tdt_dt <= window_end;

            fprintf('\n--- Aligned window values (2022-04-03 06:10:00 to 06:20:00) ---\n');
            if any(mask)
                fprintf('Total points in window: %d\n', nnz(mask));
                disp(table(tdt_dt(mask), ve(mask), vn(mask), ve_w(mask), vn_w(mask), ...
                    'VariableNames', {'tdt','ve','vn','ve_windrift_i','vn_windrift_i'}));
            else
                fprintf('No aligned points found in this interval after length matching.\n');
            end
            fprintf('----------------------------------------------------------------\n');
        catch err
            fprintf('Could not print aligned window values: %s\n', err.message);
        end
    end
end

function s = size2str(sz)
    s = sprintf('%dx', sz);
    s(end) = []; % drop trailing 'x'
end

function print_numeric_summary(v, name, sampleCount)
    if nargin < 3, sampleCount = 5; end
    vflat = v(:);
    fprintf('  nan count: %d\n', sum(isnan(vflat)));
    fprintf('  min / max: %g / %g\n', min(vflat, [], 'omitnan'), max(vflat, [], 'omitnan'));

    if numel(vflat) <= 200
        fprintf('  values: %s\n', mat2str(vflat'));
    else
        fprintf('  sample (first %d): %s\n', sampleCount, mat2str(vflat(1:min(sampleCount, numel(vflat)))'));
        tailSample = vflat(max(1, numel(vflat)-sampleCount+1):end);
        fprintf('  sample (last  %d): %s\n', numel(tailSample), mat2str(tailSample'));
    end

    % Special pretty-print for time arrays likely stored as datenum
    if contains(lower(name), 'tdt') || contains(lower(name), 'time')
        try
            dtSample = datetime(vflat(1:min(3, numel(vflat))), 'ConvertFrom', 'datenum');
            fprintf('  datetime sample: %s\n', strjoin(cellstr(dtSample), ', '));
        catch %#ok<CTCH>
        end
    end
end

function print_datetime_summary(dt, ~, indent)
    if nargin < 3, indent = '  '; end
    dt = dt(:);
    fprintf('%smin / max: %s / %s\n', indent, datestr(min(dt)), datestr(max(dt)));
    fprintf('%svalues (all):\n', indent);
    disp(dt);

    % Extra: print values in a fixed interval for quick inspection
    interval_start = datetime(2022, 4, 3, 6, 10, 0);
    interval_end   = datetime(2022, 4, 3, 6, 20, 0);
    in_range = dt >= interval_start & dt <= interval_end;
    fprintf('%svalues in [%s .. %s]:\n', indent, datestr(interval_start), datestr(interval_end));
    disp(dt(in_range));
end

function print_duration_summary(dur, sampleCount, indent)
    if nargin < 2, sampleCount = 5; end
    if nargin < 3, indent = '  '; end
    dur = dur(:);
    fprintf('%smin / max: %s / %s\n', indent, char(min(dur)), char(max(dur)));
    if numel(dur) <= 200
        fprintf('%svalues:\n', indent);
        disp(dur);
    else
        head = dur(1:min(sampleCount, numel(dur)));
        tail = dur(max(1, numel(dur)-sampleCount+1):end);
        fprintf('%ssample first %d:\n', indent, numel(head)); disp(head);
        fprintf('%ssample last  %d:\n', indent, numel(tail));  disp(tail);
    end
end

function dt = to_datetime(t)
    if isdatetime(t)
        dt = t;
    elseif isnumeric(t)
        dt = datetime(t, 'ConvertFrom', 'datenum');
    elseif isduration(t)
        dt = datetime(days(t), 'ConvertFrom', 'datenum');
    else
        error('Unsupported time type for tdt');
    end
end
