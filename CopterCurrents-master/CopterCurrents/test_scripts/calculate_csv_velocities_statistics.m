function calculate_csv_velocities_statistics()
    % Select a velocity CSV file and compute summary statistics.
    % The CSV must contain columns 'Ux' and 'Uy'.

    % File picker
    [file, path] = uigetfile('*.csv', 'Select CSV file with velocities');
    if isequal(file, 0)
        disp('User canceled file selection.');
        return;
    end
    
    full_path = fullfile(path, file);
    disp(['Reading data from: ', full_path]);
    
    % Read table
    try
        T = readtable(full_path);
    catch ME
        warning('Failed to read the CSV file. Make sure it is a valid CSV.');
        disp(ME.message);
        return;
    end
    
    % Required columns
    if ~ismember('Ux', T.Properties.VariableNames) || ~ismember('Uy', T.Properties.VariableNames)
        error('The selected CSV file must contain "Ux" and "Uy" columns.');
    end
    
    Ux = T.Ux;
    Uy = T.Uy;
    
    % Mean and std (omit NaN)
    mean_Ux = mean(Ux, 'omitnan');
    mean_Uy = mean(Uy, 'omitnan');
    std_Ux = std(Ux, 'omitnan');
    std_Uy = std(Uy, 'omitnan');
    
    % Speed magnitude per row
    Speed = sqrt(Ux.^2 + Uy.^2);
    mean_Speed = mean(Speed, 'omitnan');
    std_Speed = std(Speed, 'omitnan');
    
    % Mean vector direction
    % Math angle (0 = East, 90 = North)
    mean_Angle_Math = mod(atan2d(mean_Uy, mean_Ux), 360);
    % Compass angle (0 = North, 90 = East)
    mean_Angle_Compass = mod(atan2d(mean_Ux, mean_Uy), 360);
    
    % Print statistics
    fprintf('\n=== Velocities statistics from CSV ===\n');
    fprintf('File: %s\n', file);
    fprintf('Valid data points: %d\n', sum(~isnan(Ux) & ~isnan(Uy)));
    fprintf('----------------------------------------\n');
    fprintf('Ux: Average = %8.4f m/sec, Standard deviation = %8.4f m/sec\n', mean_Ux, std_Ux);
    fprintf('Uy: Average = %8.4f m/sec, Standard deviation = %8.4f m/sec\n', mean_Uy, std_Uy);
    fprintf('|U|: Average = %8.4f m/sec, Standard deviation = %8.4f m/sec\n', mean_Speed, std_Speed);
    fprintf('----------------------------------------\n');
    fprintf('Mean Vector Direction (Math: 0=East, 90=North)   = %8.2f deg\n', mean_Angle_Math);
    fprintf('Mean Vector Direction (Compass: 0=North, 90=East) = %8.2f deg\n', mean_Angle_Compass);
    fprintf('========================================\n\n');
end