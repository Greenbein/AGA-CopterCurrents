% 1. Open file picker
[filename, pathname] = uigetfile('*.mat', 'Select window_velocities.mat');

% Cancelled selection
if isequal(filename,0)
    error('File selection cancelled. Script stopped.');
end

% Load data
fullpath = fullfile(pathname, filename);
data = load(fullpath);

V = data.window_velocities;

% Extract Ux and Uy depending on storage format
if iscell(V)
    % Unpack cell array into numeric matrix
    V_mat = vertcat(V{:}); 
    Ux_all = V_mat(:, 1);
    Uy_all = V_mat(:, 2);
elseif isstruct(V)
    Ux_all = [V.Ux]';
    Uy_all = [V.Uy]';
elseif isnumeric(V) && size(V, 2) >= 2
    Ux_all = V(:, 1);
    Uy_all = V(:, 2);
else
    disp('Contents of window_velocities:');
    disp(V);
    error('Unrecognized window_velocities format.');
end

% 2. Mean (omit NaN)
Ux_mean = mean(Ux_all, 'omitnan');
Uy_mean = mean(Uy_all, 'omitnan');

% 3. Standard deviation
Ux_std = std(Ux_all, 'omitnan');
Uy_std = std(Uy_all, 'omitnan');

% 4. Magnitude and direction of mean vector
Mag_mean = sqrt(Ux_mean^2 + Uy_mean^2);

% Oceanographic convention: direction from North, clockwise
Dir_mean = atan2d(Ux_mean, Uy_mean); 
if Dir_mean < 0
    Dir_mean = Dir_mean + 360; 
end

% 5. Print summary
fprintf('\n========================================\n');
fprintf('  ADAPTIVE GA RESULTS (AVERAGED)\n');
fprintf('========================================\n');
fprintf('Ux vector: %7.3f +/- %.3f m/s\n', Ux_mean, Ux_std);
fprintf('Uy vector: %7.3f +/- %.3f m/s\n', Uy_mean, Uy_std);
fprintf('----------------------------------------\n');
fprintf('ADCP comparison format:\n');
fprintf('Magnitude (Mag): %7.3f m/s\n', Mag_mean);
fprintf('Direction (Dir): %7.1f deg\n', Dir_mean);
fprintf('========================================\n');