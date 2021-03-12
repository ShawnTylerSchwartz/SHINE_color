% images = SHINE(images,templ)
%
% Equates a number of image properties across an image set
%
% INPUT:
% (1) images: a cell (1xN or Nx1) that contains N source image matrices
%      Example 1: 
%       images = cell(3,1); 
%       images{1} = pic1; 
%       images{2} = pic2;
%       images{3} = pic3;
%      Example 2: 
%       [images,N] = readImages(pathname,imformat);
% (2) templ: optional; contains the template(s) for figure-ground 
%     segregation; templ can be a single matrix (of the same size as the 
%     pictures) or a cell of N matrices; the background must be 
%     uniform and of a luminance that does NOT occur in the foreground
%     (e.g., recommended: use a background of 255 and a foreground 
%     of values between 0 and 254)
%
% OUTPUT:
% (1) images: optional; SHINEd images stored in a cell
%
% Alternatively, SHINE can be used to load and save the images 
% automatically:
% 1. Put all source images in the SHINE_INPUT folder and make sure that it 
%    does not contain any other files of the same format and that the 
%    pathnames are correct (lines 70-72 of SHINE.m) 
% 2. Specify the image format in line 69 of SHINE.m (imformat)
% 3. Optional: Put the templates in the SHINE_TEMPLATE folder and make sure
%    the folder does not contain any other files of the same format
% 4. Type the following in the Matlab command window to start the program:
%    SHINE
% 5. Press enter and choose among the shine options that appear in the 
%    command window. 
%
%    If you want to QUIT the program, press ENTER without
%    choosing an option.

% ------------------------------------------------------------------------
% SHINE toolbox, May 2010
% (c) Verena Willenbockel, Javid Sadr, Daniel Fiset, Greg O. Horne,
% Frederic Gosselin, James W. Tanaka
% ------------------------------------------------------------------------
% Permission to use, copy, or modify this software and its documentation
% for educational and research purposes only and without fee is hereby
% granted, provided that this copyright notice and the original authors'
% names appear on all copies and supporting documentation. This program
% shall not be used, rewritten, or adapted as the basis of a commercial
% software or hardware product without first obtaining permission of the
% authors. The authors make no representations about the suitability of
% this software for any purpose. It is provided "as is" without express
% or implied warranty.
%
% Please refer to the following paper:
% Willenbockel, V., Sadr, J., Fiset, D., Horne, G. O., Gosselin, F.,
% Tanaka, J. W. (2010). Controlling low-level image properties: The
% SHINE toolbox. Behavior Research Methods, 42, 671-684.
%
% Kindly report any suggestions or corrections to verena.vw@gmail.com
% ------------------------------------------------------------------------
% SHINE_color toolbox, February 2019, version 0.1
% adapted by Rodrigo Dal Ben
%
% Convert RGB images to HSV and apply SHINE toolbox functions to the 
% scaled Value channel (luminance). Then, the Value channel is rescaled 
% and concatenated with Hue and Saturation channels.
% 
% Three customs functions are used:
% v2scale: convert RGB to HSV and scale the Value channel (0-1) to 0-255;
% scale2v: rescale values from 0-255 to 0-1;
% lum_calc: calculates the Value channel values of the original and new
% images (the output is a .txt file saved on the images output folder).
%
% The major adaptations were made on the "readImages" function. 
% Nonetheless the function "rgb2gray" was replaced by "v2scale" on all 
% functions that it was called.
%
% All adaptations are commented and comments always begin with 
% "SHINE_color:"
%
% Kindly report any suggestions or corrections on the adaptations to 
% dalbenwork@gmail.com
% ------------------------------------------------------------------------
% SHINE_color toolbox, April 2019, version 0.2
% adapted by Rodrigo Dal Ben
%
% The toolbox now handles video files.
% If a video file is provided, all frames will be extracted, SHINE_color
% operations will be performed on each frame, and the video will be
% re-created with the manipulated frames. 
% All the frames (pre and pos manipulations), their statistics, and the 
% new video are outputted.
%
% Two functions were added: 
% video2frames: to extract all frames of a video;
% frames2mpeg (+ getAllFilesInFolder): to re-create the video. This is an 
% adaptation of the "imageFolder2mpeg" function created by Todd Karin. 
%
% All adaptations are commented and comments always begin with 
% "SHINE_color:"
%
% Kindly report any suggestions or corrections on the adaptations to 
% dalbenwork@gmail.com
% ------------------------------------------------------------------------



function images = SHINE_color(images,templ)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Specify the image format and the input/output directories here if SHINE  
% is called without input or output arguments:
input_folder = fullfile(pwd, 'SHINE_color_INPUT'); % SHINE_color: changed from matlabroot to the current directory
output_folder = fullfile(pwd,'SHINE_color_OUTPUT'); % SHINE_color: changed from matlabroot to the current directory
template_folder = fullfile(pwd,'SHINE_color_TEMPLATE'); % SHINE_color: changed from matlabroot to the current directory
        
% SHINE_color: start by selecting image or video processing:
prompt = 'Input     [1=images, 2=video]: ';
im_vid = input(prompt);

if im_vid == 2
    prompt = 'The INPUT folder contains only one video and the OUTPUT folder is empty? [1=yes, 2=no]: ';
    y_n = input(prompt);
        if y_n == 2
            disp('Error: the INPUT folder must contain only one video and the OUTPUT folder must be empty');
            return
        else
            prompt = 'Type the video format     [e.g., mp4, avi]: ';
            video_format = input(prompt,'s');
            imformat = 'png';
            if isempty(video_format)
                video_format = 'mp4';
                disp('mp4 as default');
            end
        end
    
    videoList = dir(fullfile(input_folder, strcat('*.', video_format)));
    if length(videoList) > 1
        disp('Error: The INPUT folder must contain only one video at a time.')
        return
    end
    
    [frame_rate] = video2frames(input_folder, video_format);
    
elseif im_vid == 1
    % SHINE_color: changed predifined format to user input
    prompt = 'Type the image format  [e.g., jpg, png]\n';
    imformat = input(prompt,'s');
    if isempty(imformat)
      imformat = 'jpg';
      disp('jpg as default');
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% If desired, the default values can be changed here:

it = 1;           % number of iterations (default = 1)

wholeIm = 1;      % 1 = whole image (default)
                  % 2 = figure-ground separated (input images as templates)
                  % 3 = figure-ground separated (based on templates)

mode = 8;         % 1 = lumMatch only
                  % 2 = histMatch only
                  % 3 = sfMatch only
                  % 4 = specMatch only
                  % 5 = histMatch & sfMatch
                  % 6 = histMatch & specMatch
                  % 7 = sfMatch & histMatch
                  % 8 = specMatch & histMatch (default)

background = 300; % background lum of template, or 300=automatic (default)
                  % (automatically, the luminance that occurs most
                  % frequently in the image is used as background lum); 
                  % basically, all regions of that lum are treated as 
                  % background

rescaling = 1;    % 0 = no rescaling
                  % 1 = rescale absolute values (default)
                  % 2 = rescale average values
                 
optim = 0;        % 0 = no SSIM optimization
                  % 1 = SSIM optimization (Avanaki, 2009; to change the
                  % number if iterations (default = 10) and adjust step
                  % size (default = 67), see histMatch.m)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

temp = 0; md = 0; wim = 0; backg = 0;
quitmsg = 'SHINE_color was quit.';

while temp ~= 1 && temp ~= 2
    temp = input('SHINE_color options    [1=default, 2=custom]: ');
    if isempty(temp) == 1
        disp(quitmsg)
        return;
    end
end

if temp == 2
    temp = 0;

    while temp ~= 1 && temp ~= 2 && temp ~= 3
        temp = input('Matching mode    [1=luminance, 2=spatial frequency, 3=both]: ');
        if isempty(temp) == 1
            disp(quitmsg)
            return;
        end
    end

    if temp == 1
        while md ~= 1 && md ~= 2
            md = input('Luminance option [1=lumMatch, 2=histMatch]: ');
            if md == 2  
                while optim ~= 2 && optim ~= 3
                optim = 1+input('Optimize SSIM    [1=no, 2=yes]: ');    
                end
                optim = optim-2;
            elseif isempty(md) == 1
                disp(quitmsg)
                return;
            end
        end
    elseif temp == 2
        while md ~= 3 && md ~= 4
            md = 2+input('Spectrum options [1=sfMatch, 2=specMatch]: ');
            if isempty(md) == 1
                disp(quitmsg)
                return;
            end
        end
    elseif temp == 3
        while md ~= 5 && md ~= 6 && md ~= 7 && md ~= 8
            md = 4+input('Matching of both [1=hist&sf, 2=hist&spec, 3=sf&hist, 4=spec&hist]: ');
                while optim ~= 2 && optim ~= 3
                optim = 1+input('Optimize SSIM    [1=no, 2=yes]: ');    
                end
                optim = optim-2;
            if isempty(md) == 1
                disp(quitmsg)
                return;
            end
            it = input('# of iterations? ');
            if isempty(it) == 1
                disp(quitmsg)
                return;
            end
        end
    end

    mode = md;

    if temp == 1 || temp == 3
        if nargin < 2
            while wim ~= 1 && wim ~= 2
                wim = input('Matching region  [1=whole image, 2=foreground/background]: ');
                if isempty(wim) == 1
                    disp(quitmsg)
                    return;
                end
            end
        else
            wim = 2;
        end
        if wim == 2
            wim = 0;
            if nargin < 2
                while wim ~= 2 && wim ~= 3
                    wim = 1+input('Segmentation of: [1=source images, 2=template(s)]: ');
                    if isempty(wim) == 1
                        disp(quitmsg)
                        return;
                    end
                end
            else
                wim = 3;
            end
            if wim == 2
                while backg ~= 1 && backg ~= 2
                    backg = input('Image background [1=specify lum, 2=find automatically (most frequent lum in the image)]: ');
                    if isempty(backg) == 1
                        disp(quitmsg)
                        return;
                    end
                end
            else
                while backg ~= 1 && backg ~= 2
                    backg = input('Templ background [1=specify lum, 2=find automatically (most frequent lum in the template)]: ');
                    if isempty(backg) == 1
                        disp(quitmsg)
                        return;
                    end
                end
            end
            if backg == 1
                backg = 1.1;
                while mod(backg,1) > 0 || backg < 0 || backg > 255
                    backg = input('Enter lum value  [integer between 0 and 255]: ');
                    if isempty(backg) == 1
                        disp(quitmsg)
                        return;
                    end
                end
            else
                backg = 300;
            end
            background = backg;
        end
        wholeIm = wim;
    end
end

clear temp md wim backg

if nargin == 0
    [hue_cell, sat_cell, v_cell, images,numim,imname] = readImages(input_folder,imformat); % RDB added outputs for HSV channels
else
    numim = max(size(images));
end

disp(' ')
disp(sprintf('Number of images: %d', numim));
disp(' ')

if numim == 0
    error('No images found. Please check pathnames and file format.')
end

images_orig = images;

switch wholeIm
    case 2
        mask_fgr = cell(numim,1);
        mask_bgr = cell(numim,1);
        for im = 1:numim
            image = images{im};
            [mask_f,mask_b,background] = separate(image,0,background);
            mask_fgr{im} = mask_f;
            mask_bgr{im} = mask_b;
        end
    case 3
        if nargin < 2
            [templ,numtemp] = readImages(template_folder,imformat);
            if numtemp == 0
                error('No templates found. Please check pathnames and file format.')
            end
        else
            if iscell(templ) == 1
                numtemp = max(size(templ));
                if numtemp == 1
                    templ = cell2mat(templ);
                end
            else
                numtemp = 1;
            end
        end
        if numtemp > 1
            if numtemp ~= numim
                error('The number of templates must equal the number of images.')
            end
        end
        for im = 1:numtemp
            if iscell(templ) == 1
                [mask_f,mask_b,background] = separate(templ{im},0,background);
                mask_fgr{im} = mask_f;
                mask_bgr{im} = mask_b;
            else
                [mask_fgr,mask_bgr,background] = separate(templ,0,background);
            end
        end
end

switch mode
    case 1
        if wholeIm == 1
            disp('Option:   Mean luminance matching on the whole images')
        else
            disp(sprintf('Option:   Mean luminance matching separately for the foregrounds and backgrounds (background = all regions of lum %d)',background))
        end
        it = 1;
    case 2
        if wholeIm == 1
            disp('Option:   histMatch on the whole images')
        else
            disp(sprintf('Option:   histMatch separately for the foregrounds and backgrounds (background = all regions of lum %d)',background'))
        end
        it = 1;
    case 3
        disp('Option:   sfMatch')
        it = 1;
    case 4
        disp('Option:   specMatch')
        it = 1;
    case 5
        disp(sprintf('Option:   histMatch & sfMatch with %d iteration(s)',it))
        if wholeIm == 1
            disp('Option:   whole image')
        else
            disp(sprintf('Option:   histMatch separately for the foregrounds and backgrounds (background = all regions of lum %d)',background'))
        end
    case 6
        disp(sprintf('Option:   histMatch & specMatch with %d iteration(s)',it))
        if wholeIm == 1
            disp('Option:   whole image')
        else
            disp(sprintf('Option:   histMatch separately for the foregrounds and backgrounds (background = all regions of lum %d)',background'))
        end
    case 7
        disp(sprintf('Option:   sfMatch & histMatch with %d iteration(s)',it))
        if wholeIm == 1
            disp('Option:   whole image')
        else
            disp(sprintf('Option:   histMatch separately for the foregrounds and backgrounds (background = all regions of lum %d)',background'))
        end
    case 8
        disp(sprintf('Option:   specMatch & histMatch with %d iteration(s)',it))
        if wholeIm == 1
            disp('Option:   whole image')
        else
            disp(sprintf('Option:   histMatch separately for the foregrounds and backgrounds (background = all regions of lum %d)',background'))
        end
end

for iteration = 1:it
    if it > 1
        disp(' ')
        disp(sprintf('Iteration %d', iteration))
    end
    switch mode
        case 1
            if wholeIm == 1
                images = lumMatch(images);
            else
                images = lumMatch(images,mask_fgr);
                images = lumMatch(images,mask_bgr);
            end
            disp('Progress: lumMatch successful')
        case {2, 5, 6}
            if wholeIm == 1
                images = histMatch(images,optim);
            else
                images = histMatch(images,optim,[],mask_fgr);
                images = histMatch(images,optim,[],mask_bgr);
            end
            disp('Progress: histMatch successful')
    end
    switch mode
        case {3, 5, 7}
            images = sfMatch(images,rescaling);
            disp('Progress: sfMatch successful')
        case {4, 6, 8}
            images = specMatch(images,rescaling);
            disp('Progress: specMatch successful')
    end
    switch mode
        case {7, 8}
            if wholeIm == 1
                images = histMatch(images,optim);
            else
                images = histMatch(images,optim,[],mask_fgr);
                images = histMatch(images,optim,[],mask_bgr);
            end
            disp('Progress: histMatch successful')
    end
    % To save the result after each iteration
    %save(fullfile(output_folder,sprintf('SHINE_color_d_%d_it',iteration)),'images') % SHINE_color: altered the output folder name
end


rmsqe_all = 0;
mssim_all = 0;
for im = 1:numim
    if nargout == 0
        if nargin > 0
        % SHINE_color: rescale value channel from 0-255 to 0-1
        v_cell{im} = scale2v(images{im}); % SHINE_color: opened on the readImages function
        
        % SHINE_color: create a hsv color image and transform to rgb
        color_im = cat(3, hue_cell{im}, sat_cell{im}, v_cell{im}); 
        color_im = hsv2rgb(color_im);
       
            %imwrite(images{im},fullfile(output_folder,strcat('SHINE_color_d_',num2str(im),'.tif'))); % SHINE_color: original command
            imwrite(color_im,fullfile(output_folder,strcat('SHINE_color_',num2str(im),'.tif'))); % SHINE_color: writing the colorful image
        else
            % SHINE_color: rescale value channel from 0-255 to 0-1
            v_cell{im} = scale2v(images{im}); %opened on the readImages function
        
            % SHINE_color: create a hsv color image and transform to rgb
            color_im = cat(3, hue_cell{im}, sat_cell{im}, v_cell{im}); 
            color_im = hsv2rgb(color_im);
            
            %imwrite(images{im},fullfile(output_folder,strcat('SHINE_color_d_',imname{im}))); % SHINE_color: original command
            imwrite(color_im,fullfile(output_folder,strcat('SHINE_color_',imname{im}))); % SHINE_color: writing the colorful image
        end
    end
    rmsqe = getRMSE(images_orig{im},images{im});
    rmsqe_all = rmsqe_all+rmsqe;
    mssim = ssim_index(images_orig{im},images{im});
    mssim_all = mssim_all+mssim;
end

lum_calc(input_folder, output_folder, imformat); % SHINE_color: calculates the Value channel values of the original and new images

RMSE = rmsqe_all/numim;
SSIM = mssim_all/numim;

disp(' ')
disp(sprintf('RMSE:     %d',RMSE))
disp(sprintf('SSIM:     %d',SSIM))

if im_vid == 2
    disp([10 'Re-creating video with new luminance.' 10]);
    frames2mpeg(output_folder,frame_rate);
    disp([10 'All done! See the OUTPUT folder for the new video, all individual frames, and their statistics.']);
end


if nargout < 1
    clear images
end