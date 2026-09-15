function reset_folder_contents(folder_path)
entries = dir(folder_path);
for i = 1:numel(entries)
    name = entries(i).name;
    if strcmp(name, '.') || strcmp(name, '..')
        continue;
    end
    target = fullfile(folder_path, name);
    if entries(i).isdir
        rmdir(target, 's');
    else
        delete(target);
    end
end
end
