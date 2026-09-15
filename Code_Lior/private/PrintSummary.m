function PrintSummary(state, SNR_density_max, cfg)
% PRINTSUMMARY  Console output: final fit and timing breakdown.
%   Always prints the one-line fit result; the timing block prints only
%   when cfg.DEBUG is true.

    fprintf('Ux_SG: %s m/s   Uy_SG: %s m/s   SNR density: %s\n', ...
            num2str(state.best_U(1)), ...
            num2str(state.best_U(2)), ...
            num2str(SNR_density_max));
    
    if ~cfg.DEBUG
        return;
    end
    
    fprintf('\n=== Adaptive GD Timing Summary ===\n');
    fprintf('Total GD time: %.4f s\n', state.total_time);
    fprintf('Mean iteration time: %.4f s\n', state.mean_iter_time);
    fprintf('Iterations: %d\n', state.n_iter);
    fprintf('Initial step: %.4f\n', state.step_initial);
    fprintf('==========================\n');
end