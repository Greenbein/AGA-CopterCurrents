function [base_results_dir, was_cancelled] = prompt_save_base_dir(video_fname, matlab_root)
was_cancelled = false;
[~, video_name] = fileparts(video_fname);
default_dir = fullfile(matlab_root, [video_name '_results']);

choice = questdlg(sprintf('Save results folder?\nDefault:\n%s', default_dir), ...
    'Output folder', ...
    'Use default', 'Choose custom', 'Cancel', 'Use default');

switch choice
    case 'Use default'
        base_results_dir = default_dir;
    case 'Choose custom'
        selected_parent = uigetdir(matlab_root, 'Select parent folder for results');
        if isequal(selected_parent, 0)
            base_results_dir = '';
            was_cancelled = true;
            return;
        end
        base_results_dir = fullfile(selected_parent, [video_name '_results']);
    otherwise
        base_results_dir = '';
        was_cancelled = true;
        return;
end
end
