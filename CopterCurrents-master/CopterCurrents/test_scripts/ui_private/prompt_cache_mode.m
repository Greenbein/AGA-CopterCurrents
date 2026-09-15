function [force_rebuild, was_cancelled] = prompt_cache_mode()
force_rebuild = false;
was_cancelled = false;
choice = questdlg(['Georeference cache mode:' newline ...
    '- Use cache if valid: skip Step 2 when possible.' newline ...
    '- Force rebuild: always run Step 2 and overwrite cache.'], ...
    'Georeference cache', ...
    'Use cache if valid', 'Force rebuild', 'Cancel', 'Use cache if valid');

switch choice
    case 'Use cache if valid'
        force_rebuild = false;
    case 'Force rebuild'
        force_rebuild = true;
    otherwise
        was_cancelled = true;
end
end
