function info = safe_file_info(file_path)
info = struct('bytes', NaN, 'datenum', NaN);
if exist(file_path, 'file') ~= 2
    return;
end
d = dir(file_path);
if isempty(d)
    return;
end
info.bytes = d(1).bytes;
info.datenum = d(1).datenum;
end
