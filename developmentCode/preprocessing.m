clear all; close all;

img = imread('images/whole3.jpg');
grayImg = rgb2gray(img);

% using gamma transform to fix get rid of yellowness from old pictures
r = double(grayImg);
k = mean2(r);
E = 0.9;
s = 1 ./ (1.0 + (k ./ (r + eps)) .^ E);
g = uint8(255*s);

% binarization of the image
BW = imbinarize(g, 'adaptive','ForegroundPolarity','dark','Sensitivity',0.4);
BW = ~BW;

% using a SE of a line to find all the horizontal lines (staff)
se_line = strel('line', 50, 0);
staff_lines = imopen(BW, se_line);

% get rid off the lines temporarily to find all the notes
notes_no_lines = BW & ~staff_lines;

% using morphological closing to fill in any gaps in the notes due to staff
se_notes = strel('disk', 2);
notes_clean = imclose(notes_no_lines, se_notes);

% feature filtering to remove text
cc = bwconncomp(notes_clean);
stats = regionprops(cc, 'Area', 'Eccentricity', 'Solidity');
idx_notes = find([stats.Area] >= 35 & [stats.Eccentricity] <= 0.87 & [stats.Solidity] >= 0.5);
final_notes = false(size(notes_clean));
for i = 1:length(idx_notes)
    final_notes(cc.PixelIdxList{idx_notes(i)}) = true;
end

% combine wanted parts and display
final_cleaned = staff_lines | final_notes;
figure;
montage({BW, staff_lines, final_notes, final_cleaned}, 'Size',[1 4]);
title('Binary | Lines | Final Notes | Final Cleaned Result');

% staff segmentation to be able to seperate lines
horz_proj = sum(final_cleaned, 2);
smooth_proj = movmean(horz_proj, 15);
gap_thresh = max(smooth_proj)*0.05;
staff_present = smooth_proj > gap_thresh;
changes = diff([0; staff_present; 0]);
startRows = find(changes == 1);
endRows = find(changes == -1) - 1;

padding = 10; % padding around each line so notes above staff are still detected
staffSegments = {};

for i = 1:length(startRows)
    row_start = max(startRows(i)-padding, 1);
    row_end = min(endRows(i)+padding, size(final_cleaned,1));

    % Extract segment clearly with padding (binary cleaned image)
    segment = final_cleaned(row_start:row_end, :);
    staffSegments{i} = segment;

    figure; imshow(staffSegments{i});
    title(['Line of music', num2str(i)]);
end
