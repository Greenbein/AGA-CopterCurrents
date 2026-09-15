function matlab_root = get_matlab_root()
if ispc
    username = getenv('USERNAME');
    matlab_root = fullfile('C:', 'Users', username, 'Documents', 'MATLAB');
else
    username = getenv('USER');
    matlab_root = fullfile(filesep, 'home', username, 'Documents', 'MATLAB');
end
end
