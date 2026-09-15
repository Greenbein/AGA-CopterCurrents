function IMG_SEQ = get_IMG_SEQ_by_caltech_library_v2(Georeference_Struct_config,heading,pitch,roll,timestamp_video,Height_drone)
% Retrieve IMG_SEQ structure using the 'Camera Calibration Toolbox for Matlab'.
% The IMG_SEQ structure stores the video data in real size.
%   
%   Note: the caltech library 'Camera Calibration Toolbox for Matlab' is 
%   an external libary, written by Jean-Yves Bouguet,
%   jean-yves.bouguet@intel.com. This library is not part of CopterCurrents, and it
%   is available in:
%
%   http://www.vision.caltech.edu/bouguetj/calib_doc/
%   
%   The 'Camera Calibration Toolbox for Matlab' is compatible with OpenCV
%   camera calibration. This is the main reason to include this function in
%   CopterCurrents.
%  
%   If you want to retrieve the IMG_SEQ structure without any CopterCurrents 
%   external library, then use 'get_IMG_SEQ_by_HZG_method.m'.
% 
%   Input:
%     Georeference_Struct_config: Georeference configuration 
%     heading: video metadata heading (yaw) in degrees 
%     pitch: video metadata pitch in degrees 
%     roll: video metadata roll in degrees 
%     timestamp_video: time video information in seconds
%     Height_drone: distance from camera to water surface in meters.
%
%   Output:
%     IMG_SEQ structure
%     IMG_SEQ.IMG: 3D Intensty data (Nx,Ny,Nt)
%     IMG_SEQ.gridX: 2D grid X data in meters (Nx,Ny)
%     IMG_SEQ.gridY: 2D grid Y data in meters (Nx,Ny)
%     IMG_SEQ.dx: X resolution in meters.
%     IMG_SEQ.dy: Y resolution in meters.
%     IMG_SEQ.dt: time resolution in seconds.
%     IMG_SEQ.ts_video: video time stamps in datenum format. 1xNt vector.
%     IMG_SEQ.altitude: altitude to the water surface in meters.
%                       altitude  = video altitude + offset_home2water_Z
%     IMG_SEQ.pitch: video pitch (for Nadir pitch = -90)
%     IMG_SEQ.roll: video roll (for Nadir roll = 0)
%     IMG_SEQ.heading: video heading to North (yaw)
%     IMG_SEQ.Longitude: video longitude in degrees
%     IMG_SEQ.Latitude: video latitude in degrees
%     IMG_SEQ.mediainfo_string: raw mediainfo string
%     IMG_SEQ.Georeference_Struct_config: Georeference_Struct used
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


%
%     Georeference_Struct_config struct
%     Georeference_Struct_config.video_fname: video filename (complete path);
%     Georeference_Struct_config.dt: distance in seconds between frames to 
%                georeference. [initial_time_video_sec end_time_video_sec]
%     Georeference_Struct_config.time_limits: Vector defining the video 
%                                 data to be used.
%     Georeference_Struct_config.video_ts: video time stamps in detenum format
%     Georeference_Struct_config.offset_home2water_Z: distance between 
%                           home position and water surface in meters.
%     Georeference_Struct_config.CopterCurrents_CamCalib: Camera calibration
%                                                structure.
%     Georeference_Struct_config.out_resolution: resolution in meters of 
%           georeferenced data, only used when georeference_mode = 0 
%     

% get sensor offset
v = VideoReader(Georeference_Struct_config.video_fname);
% img_RGB = readFrame(v);


% get altitute
altitude = Height_drone + Georeference_Struct_config.offset_home2water_Z + ...
           Georeference_Struct_config.CopterCurrents_CamCalib.camera_offset_Z;

% get equidistant grid
v.CurrentTime = Georeference_Struct_config.video_ts(1);
img_RGB = readFrame(v);
img_gray = rgb2gray(img_RGB);

% get conversion to monotonic grid structure using Caltech library 
% [~,conv_monotonic_grid_ST] = georeferenceDJIFrame_byCaltech_EQ(img_gray,altitude, pitch,roll,Georeference_Struct_config.CopterCurrents_CamCalib);
[~,conv_monotonic_grid_ST] = georeferenceDJIFrame_byCaltech_EQ_v2(img_gray,altitude, pitch,roll,Georeference_Struct_config.CopterCurrents_CamCalib);
       
IMG_SEQ = [];

% axis_flag = 0; => georeferenceDJIFrame_byCaltech_EQ_v2
% axis_flag = 1; => georeferenceDJIFrame_byCaltech_EQ
axis_flag = 0; 
% axis flag to exchange X and Y axis, 
% and exchange dimesion 1 by 2 (IMG_SEQ format)


video_ts = Georeference_Struct_config.video_ts;
Nt = length(video_ts);

% Build output grid and metadata from first frame.
v.CurrentTime = video_ts(1);
img_rgb_first = readFrame(v);
img_gray_first = rgb2gray(img_rgb_first);
[X_eq,Y_eq,IMG_eq_first] = apply_conv_monotonic_grid_ST(conv_monotonic_grid_ST,img_gray_first,axis_flag);
IMG_eq_first = single(IMG_eq_first);

IMG_stack = zeros(size(X_eq,1),size(X_eq,2),Nt,'single');
IMG_stack(:,:,1) = IMG_eq_first;

IMG_SEQ.gridX = X_eq;
IMG_SEQ.gridY = Y_eq;
IMG_SEQ.dt = Georeference_Struct_config.dt;
IMG_SEQ.dx = conv_monotonic_grid_ST.dxdy;
IMG_SEQ.dy = conv_monotonic_grid_ST.dxdy;
IMG_SEQ.ts_video = timestamp_video + (video_ts/86400);
IMG_SEQ.altitude = altitude;
IMG_SEQ.pitch = pitch;
IMG_SEQ.roll = roll;
IMG_SEQ.heading = heading;
IMG_SEQ.Georeference_Struct_config = Georeference_Struct_config;

% % Parallel stage: georeference frames in batches.
% % Keep frame reading sequential and process each batch in parfor to reduce RAM usage.
% % Fall back to regular for-loop when Parallel Computing Toolbox is unavailable
% % or when a parallel batch raises an out-of-memory error.
% use_parallel = (license('test','Distrib_Computing_Toolbox') == 1);
% if use_parallel
%     disp('Processing frames with batched parfor');
%     batch_size = 24;
%     for i_start = 2:batch_size:Nt
%         i_end = min(i_start + batch_size - 1, Nt);
%         idx_batch = i_start:i_end;
%         n_batch = numel(idx_batch);
%         frames_batch = cell(n_batch,1);
% 
%         for k = 1:n_batch
%             i_global = idx_batch(k);
%             disp(['read image ' num2str(i_global) ' of ' num2str(Nt)])
%             v.CurrentTime = video_ts(i_global);
%             frames_batch{k} = rgb2gray(readFrame(v));
%         end
% 
%         IMG_batch = cell(n_batch,1);
%         try
%             parfor k = 1:n_batch
%                 [~,~,IMG_eq_k] = apply_conv_monotonic_grid_ST(conv_monotonic_grid_ST,frames_batch{k},axis_flag);
%                 IMG_batch{k} = single(IMG_eq_k);
%             end
%         catch ME
%             warning(['Parallel batch failed (' ME.message '). Falling back to for-loop for this batch.']);
%             for k = 1:n_batch
%                 [~,~,IMG_eq_k] = apply_conv_monotonic_grid_ST(conv_monotonic_grid_ST,frames_batch{k},axis_flag);
%                 IMG_batch{k} = single(IMG_eq_k);
%             end
%         end
% 
%         for k = 1:n_batch
%             IMG_stack(:,:,idx_batch(k)) = IMG_batch{k};
%         end
%     end
% else
%     disp('Processing frames with for-loop (parallel toolbox not available)');
%     for i1 = 1:Nt
%         disp(['process image ' num2str(i1) ' of ' num2str(Nt)])
%         v.CurrentTime = video_ts(i1);
%         img_rgb_i = readFrame(v);
%         img_gray_i = rgb2gray(img_rgb_i);
%         [~,~,IMG_eq_i] = apply_conv_monotonic_grid_ST(conv_monotonic_grid_ST,img_gray_i,axis_flag);
%         IMG_stack(:,:,i1) = single(IMG_eq_i);
%     end
% end
% 
% if use_parallel
%     % frame 1 already processed before batched loop
%     if Nt == 1
%         IMG_stack(:,:,1) = IMG_eq_first;
%     elseif all(IMG_stack(:,:,1) == 0,'all')
%         % Safety in case future edits alter the fill order.
%         IMG_stack(:,:,1) = IMG_eq_first;
%     end
% elseif Nt >= 1
%     % For-loop branch recomputes all frames, nothing else to do.
% else
%     % no-op, keep structure for completeness
% end
% 
% if use_parallel && Nt >= 1
%     % Ensure first frame comes from the deterministic first-frame computation.
%     IMG_stack(:,:,1) = IMG_eq_first;
% end
% 
% IMG_SEQ.IMG = IMG_stack;
% 
% % destroy video Reader object
% delete(v);
% clear v;
% 
% end


% ========================================================================
%
%               Processing Loop (GPU or CPU)
%
% ========================================================================
global USE_GPU_FLAG;
if isempty(USE_GPU_FLAG)
    USE_GPU_FLAG = true;
end

if USE_GPU_FLAG
    disp('Processing frames on GPU...');
    
    % 1. Load remapping indices into video memory (VRAM) ONCE
    idx_grid_arr = gpuArray(conv_monotonic_grid_ST.LinearInd_grid);
    idx_img_arr  = gpuArray(conv_monotonic_grid_ST.LinearInd_img);
    
    % 2. Create an empty frame template directly on the GPU (filled with NaNs).
    % It is crucial to use 'single' precision to maximize GPU performance (FP32).
    template_arr = gpuArray(nan(size(X_eq), 'single'));
else
    disp('Processing frames on CPU...');
    idx_grid_arr = conv_monotonic_grid_ST.LinearInd_grid;
    idx_img_arr  = conv_monotonic_grid_ST.LinearInd_img;
    template_arr = nan(size(X_eq), 'single');
end

% 3. Fast sequential loop for reading frames and indexing
for i1 = 1:Nt
    if mod(i1, 50) == 0 || i1 == 1
        if USE_GPU_FLAG
            fprintf('Processing image %d of %d on GPU\n', i1, Nt);
        else
            fprintf('Processing image %d of %d on CPU\n', i1, Nt);
        end
    end
    
    v.CurrentTime = video_ts(i1);
    % Read frame and convert immediately to single precision
    img_gray = single(rgb2gray(readFrame(v))); 
    
    if USE_GPU_FLAG
        img_arr = gpuArray(img_gray);
    else
        img_arr = img_gray;
    end
    
    % Initialize with the empty template
    IMG_eq_arr = template_arr;
    
    % Hardware-accelerated (if GPU) remapping of millions of pixels
    IMG_eq_arr(idx_grid_arr) = img_arr(idx_img_arr);
    
    % Gather the processed frame back to system RAM
    if USE_GPU_FLAG
        IMG_stack(:,:,i1) = gather(IMG_eq_arr);
    else
        IMG_stack(:,:,i1) = IMG_eq_arr;
    end
end

% Ensure the first frame strictly matches the deterministic first-frame computation
IMG_stack(:,:,1) = IMG_eq_first;

IMG_SEQ.IMG = IMG_stack;

% Destroy video Reader object
delete(v);
clear v;
end
