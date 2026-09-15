function export_compass_velocities_to_csv(window_velocities_compass, output_csv_path)
    % Export geographic (compass/UTM) velocities to CSV and compute statistics.
    %
    % Inputs:
    %   window_velocities_compass - Nx1 cell array; each cell holds [Ux, Uy]
    %   output_csv_path - output CSV path, e.g. 'compass_velocities.csv'

    N = length(window_velocities_compass);
    
    % Initialize arrays
    square_index = (1:N)';
    Ux = NaN(N, 1);
    Uy = NaN(N, 1);
    
    % Unpack cell array into numeric vectors
    for i = 1:N
        val = window_velocities_compass{i};
        if ~isempty(val) && numel(val) >= 2
            Ux(i) = val(1);
            Uy(i) = val(2);
        end
    end
    
    % --- Statistics ---
    % Use mean(..., 'omitnan') and std(..., 'omitnan') to skip empty (NaN) windows
    mean_Ux = mean(Ux, 'omitnan');
    mean_Uy = mean(Uy, 'omitnan');
    std_Ux = std(Ux, 'omitnan');
    std_Uy = std(Uy, 'omitnan');
    
    % Speed magnitude per window
    Speed = sqrt(Ux.^2 + Uy.^2);
    mean_Speed = mean(Speed, 'omitnan');
    std_Speed = std(Speed, 'omitnan');
    
    % Print statistics to the command window
    fprintf('\n=== UTM velocities statistics (compass) ===\n');
    fprintf('Ux: Average = %8.4f m/sec, Standard deviation = %8.4f m/sec\n', mean_Ux, std_Ux);
    fprintf('Uy: Average = %8.4f m/sec, Standard deviation = %8.4f m/sec\n', mean_Uy, std_Uy);
    fprintf('|U|: Average = %8.4f m/sec, Standard deviation = %8.4f m/sec\n', mean_Speed, std_Speed);
    fprintf('========================================\n\n');
    
    % --- Save CSV ---
    T = table(square_index, Ux, Uy, 'VariableNames', {'square_index', 'Ux', 'Uy'});
    
    % Default path if not provided
    if nargin < 2 || isempty(output_csv_path)
        output_csv_path = 'compass_velocities.csv';
    end
    
    writetable(T, output_csv_path);
    disp(['The UTM velocities table has been saved to: ', output_csv_path]);

end