function [cache_hit, IMG_SEQ] = try_load_georef_cache(cache_file, expected_meta, force_rebuild)
cache_hit = false;
IMG_SEQ = [];
if force_rebuild
    return;
end
if exist(cache_file, 'file') ~= 2
    return;
end

loaded = load(cache_file, 'IMG_SEQ', 'cache_meta');
if ~isfield(loaded, 'IMG_SEQ') || ~isfield(loaded, 'cache_meta')
    return;
end

if is_georef_cache_valid(loaded.cache_meta, expected_meta)
    cache_hit = true;
    IMG_SEQ = loaded.IMG_SEQ;
end
end
