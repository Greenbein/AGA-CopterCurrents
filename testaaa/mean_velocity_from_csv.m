function [mean_Ux, mean_Uy, mean_speed] = mean_velocity_from_csv()
% MEAN_VELOCITY_FROM_CSV Select a CSV with columns square_index, Ux, Uy and compute averages.
% Returns mean_Ux, mean_Uy, and mean speed magnitude. NaNs are ignored.
% Prints full table contents and stats.

    [file, path] = uigetfile('*.csv', 'Select CSV with square_index, Ux, Uy');
    if isequal(file, 0)
        disp('File selection canceled.');
        mean_Ux = NaN; mean_Uy = NaN; mean_speed = NaN;
        return;
    end
    fullpath = fullfile(path, file);
    disp(['Loading CSV: ', fullpath]);

    opts = detectImportOptions(fullpath, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
    tbl = readtable(fullpath, opts);

    % Normalize column names to match expected keys
    cols = lower(string(tbl.Properties.VariableNames));
    nameMap = containers.Map(cols, tbl.Properties.VariableNames);

    required = {'square_index','ux','uy'};
    for i = 1:numel(required)
        if ~isKey(nameMap, required{i})
            error('Missing required column: %s', required{i});
        end
    end

    Ux = tbl.(nameMap('ux'));
    Uy = tbl.(nameMap('uy'));

    % Convert strings to numeric if needed
    if iscellstr(Ux) || isstring(Ux)
        Ux = str2double(Ux);
    end
    if iscellstr(Uy) || isstring(Uy)
        Uy = str2double(Uy);
    end

    mean_Ux = mean(Ux, 'omitnan');
    mean_Uy = mean(Uy, 'omitnan');
    mean_speed = mean(sqrt(Ux.^2 + Uy.^2), 'omitnan');

    fprintf('\n=== Full table from %s ===\n', file);
    disp(tbl);

    fprintf('\n=== Mean velocities from %s ===\n', file);
    fprintf('Mean Ux: %.4f m/s\n', mean_Ux);
    fprintf('Mean Uy: %.4f m/s\n', mean_Uy);
    fprintf('Mean |U|: %.4f m/s\n', mean_speed);

    % Extra: print count stats
    fprintf('Count (non-NaN Ux): %d\n', sum(~isnan(Ux)));
    fprintf('Count (non-NaN Uy): %d\n', sum(~isnan(Uy)));
end
