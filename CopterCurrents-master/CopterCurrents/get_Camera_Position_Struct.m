function [CamPos_ST] = get_Camera_Position_Struct(video_filename)
% Retrieve camera position struct.
% Use mediainfo application to retrieve video metadata information.
%   get_mediainfo_information was designed expecifically for DJI 
%   Phamtom 3 videos, and should be compatible with any DJI metadata 
%   video information.
%   
%   Note: MediaInfo is not part of CopterCurrents, and must be installed manually.
%         Media info can be found in the following links:
%
%   Media info used: MediaInfoLib - v0.7.82
%   https://mediaarea.net/en/MediaInfo/Download/Ubuntu
%   https://mediaarea.net/en/MediaInfo/Download/Windows
%
%   In the case that MediaInfo can not be installed, a work around solution 
%   will be edit the lines 108-115 manually for every video (Not recomended).  
%
%   Input:
%     video_filename: video file name
%
%   Output:
%     LON: metadata video longitude in degrees
%     LAT: metadata video latitude in degrees
%     Height: metadata  video altitude in degrees
%     timestamp: metadata Encoded date timestamp
%     mediainfo_string: raw metadata string
%     yaw: metadata yaw in degrees (heading)
%     pitch: metadata pitch in degrees 
%     roll: metadata roll in degrees 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% (C) 2019, Ruben Carrasco <ruben.carrasco@hzg.de>
%
% This file is part of CopterCurrents
%
% CopterCurrents has been developed by Department of Radar Hydrography, at
% Helmholtz-Zentrum Geesthacht Centre for Materials and Coastal Research 
% (Germany), based in the work exposed in: 
% 
% M. Streßer, R. Carrasco and J. Horstmann, "Video-Based Estimation 
% of Surface Currents Using a Low-Cost Quadcopter," in IEEE Geoscience 
% and Remote Sensing Letters, vol. 14, no. 11, pp. 2027-2031, Nov. 2017.
% doi: 10.1109/LGRS.2017.2749120
%
%
% CopterCurrents is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% CopterCurrents is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with CopterCurrents.  If not, see <http://www.gnu.org/licenses/>.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

command_media_info = ['mediainfo "' video_filename '"'];

% read mediainfo information 

[status,mediainfo_string] = system(command_media_info);

LON = [];
LAT = [];
Height = [];
timestamp = [];
yaw = [];
pitch = [];
roll = [];

if status == 0
    C = strsplit(mediainfo_string, {'\n', char(10), char(13)}, 'CollapseDelimiters', true);

    [LAT, LON, Height] = parse_dji_xyz_line(C);
    timestamp = parse_encoded_date_line(C);
    yaw = parse_dji_scalar_tag(C, 'gyw');
    pitch = parse_dji_scalar_tag(C, 'gpt');
    roll = parse_dji_scalar_tag(C, 'grl');
else
    % probably media info is not installed
    %  add values manually
    disp('Install Mediainfo: https://mediaarea.net/en/MediaInfo/Download/Ubuntu');
    disp('Install Mediainfo: https://mediaarea.net/en/MediaInfo/Download/Windows');
    warning('get_mediainfo_information: Mediainfo does not return valid data');

    LON = [];
    LAT = [];
    Height = [];
    timestamp = [];
    mediainfo_string = [];
    yaw = [];
    pitch = [];
    roll = [];

end

% save data in Camera Position Struct
CamPos_ST = struct('LONGITUDE',LON,'LATITUDE',LAT,'Height',Height,...
                   'timestamp',timestamp,'yaw',yaw,'pitch',pitch,...
                   'roll',roll,'extra',mediainfo_string);


end

function [lat, lon, height] = parse_dji_xyz_line(C)
lat = [];
lon = [];
height = [];
idx = find(contains(C, 'xyz') & contains(C, '+'), 1, 'first');
if isempty(idx)
    return;
end
try
    tok = regexp(C{idx}, '\+([0-9\.]+)\+([0-9\.]+)\+([0-9\.]+)', 'tokens', 'once');
    if ~isempty(tok)
        lat = str2double(tok{1});
        lon = str2double(tok{2});
        height = str2double(tok{3});
    end
catch
end
end

function ts = parse_encoded_date_line(C)
ts = [];
idx = find(contains(C, 'Encoded date'), 1, 'first');
if isempty(idx)
    return;
end
try
    parts = strsplit(C{idx}, ': UTC ');
    if numel(parts) >= 2
        ts = datenum(strtrim(parts{2})); %#ok<DATNM>
    end
catch
end
end

function val = parse_dji_scalar_tag(C, tag)
val = [];
idx = find(contains(C, [tag ' ']) | startsWith(strtrim(C), tag), 1, 'first');
if isempty(idx)
    return;
end
try
    parts = strsplit(C{idx}, ':');
    if numel(parts) >= 2
        val = str2double(strtrim(parts{2}));
    end
catch
end
end

