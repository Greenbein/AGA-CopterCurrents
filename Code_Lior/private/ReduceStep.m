function step_reduced = ReduceStep(step, min_bound)
% REDUCESTEP  Halve the step,but not below min_bound.
% Used after a failed iteration to shrink the step before next attempt
    step_reduced = max(step * 0.5, min_bound);
end
