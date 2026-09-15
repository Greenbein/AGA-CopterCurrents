function save_georef_cache(cache_file, IMG_SEQ, cache_meta)
try
    save(cache_file, 'IMG_SEQ', 'cache_meta', '-v7.3', '-nocompression');
catch ME
    warning('UI_CopterCurrents:CacheSaveFailed', ...
        'Could not save georeference cache (%s)', ME.message);
end
end
