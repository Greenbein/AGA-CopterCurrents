function stage_times = ui_step_05_maps_and_velocity_save(STCFIT, algo_results_dir, cfg, stage_times)
% Step 5: currents maps, window_velocities.mat.
    t_stage = tic;
    [UTM_currents, Camera_currents] = get_currents_from_STCFIT( ...
        STCFIT, cfg.SNR_thr, cfg.SNR_density_thr, cfg.currentdir_flag);
    h1 = plot_currents_map(Camera_currents, STCFIT, cfg.arrow_scale);
    saveas(h1, fullfile(algo_results_dir, 'Current_map_arrows_not_rotated.png'));
    close(h1);
    if ~isempty(UTM_currents)
        h2 = plot_currents_map(UTM_currents, STCFIT, cfg.arrow_scale);
        saveas(h2, fullfile(algo_results_dir, 'Current_map_arrows_rotated.png'));
        close(h2);
    end
    
    % Save raw window velocities, i.e. vectors in DJI camera system
    window_velocities = extract_window_velocities(STCFIT);
    save(fullfile(algo_results_dir, 'window_velocities.mat'), 'window_velocities');
    
    % Save velocity vectors relatively to a compass (UTM/North vecs)
    window_velocities_compass = extract_window_velocities_compass(STCFIT);
    save(fullfile(algo_results_dir, 'window_velocities_compass.mat'), 'window_velocities_compass');
    
    % Build full CSV path inside the algorithm results folder
    csv_output_path = fullfile(algo_results_dir, 'window_velocities_compass_table.csv');
    export_compass_velocities_to_csv(window_velocities_compass, csv_output_path);
    
    % Optional: save processing_output.mat for compare_algorithms — do it from
    % UI_CopterCurrents where stage_times, window_timing, algorithm_name exist.
    stage_times(5) = toc(t_stage);
end