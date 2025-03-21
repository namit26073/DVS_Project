clear all; close all;

img = imread('whole3.jpg');
grayImg = rgb2gray(img);

% Adaptive binarization (clearly from labs)
BW = imbinarize(grayImg,'adaptive','ForegroundPolarity','dark','Sensitivity',0.4);
BW = ~BW;

% Horizontal projection to find staves
horz_proj = sum(BW,2);

% Smooth projection (clearly removes small noise)
smooth_proj = movmean(horz_proj, 15);

% Clearly visualize horizontal projection (debugging)
figure; plot(smooth_proj);
title('Smoothed Horizontal Projection');

% Clearly detect presence of staffs
gap_thresh = max(smooth_proj)*0.05; % Adjust if needed
staff_present = smooth_proj > gap_thresh;

% Clearly detect boundaries of each staff segment
changes = diff([0; staff_present; 0]);
startRows = find(changes == 1);
endRows = find(changes == -1) - 1;

padding = 15; % padding around each segment (clearly adjustable)
staffSegments = {};

% Clearly loop through each detected segment
for i = 1:length(startRows)
    row_start = max(startRows(i)-padding, 1);
    row_end = min(endRows(i)+padding, size(grayImg,1));

    % Extract segment clearly with padding
    segment = grayImg(row_start:row_end, :);
    staffSegments{i} = segment;

    figure; imshow(staffSegments{i});
    title(['Clearly Extracted Staff Segment ', num2str(i)]);
end
