clear variables;
close all;

%% PARAMETERS (tweak these if needed)
gammaE = 2;          % Gamma correction exponent
threshSensitivity = 0.4;  % Sensitivity for adaptive thresholding
lineLength_staff = 100;  % Length for staff line structuring element
diskRadius_notes = 2;   % Radius for morphological closing on notes
padding = 10;           % Extra padding for staff segmentation
lineLength_erase = 100; % For eroding staff lines in segments
lineLength_dilate = 10; % For dilating eroded staff lines
diskRadius_fill = 3;    % For closing after staff removal
lineLength_merge = 10;  % For dilating after closing

%% Part 1: Preprocess and Segment the Full Sheet Music
% Read the full image and convert to grayscale
img = imread('images/old3.jpg');
grayImg = rgb2gray(img);
border_percent = 0.02; % 2% of the image size
border_h = round(size(grayImg, 1) * border_percent);
border_w = round(size(grayImg, 2) * border_percent);

% Create a mask that removes the border
mask = true(size(grayImg));
mask(1:border_h,:) = false; % Top border
mask(end-border_h+1:end,:) = false; % Bottom border
mask(:,1:border_w) = false; % Left border
mask(:,end-border_w+1:end) = false; % Right border

% Optional: More aggressive method using morphological operations
% Clean up noise and specks using morphological opening
se_clean = strel('disk', 3);
mask_cleaned = imopen(mask, se_clean);

% Apply additional median filtering to the grayscale image
grayImg_filtered = medfilt2(grayImg, [3 3]);

% Use the mask for further processing by replacing border pixels with white
grayImg_masked = grayImg_filtered;
grayImg_masked(~mask_cleaned) = 255; % Set borders to white

% Gamma transform to reduce yellowness from old pictures
r = double(grayImg);
k = mean2(r);
s = 1 ./ (1.0 + (k ./ (r + eps)).^gammaE);
g = uint8(255 * s);

% Binarize the gamma-corrected image using adaptive thresholding
BW = imbinarize(g, 'adaptive', 'ForegroundPolarity', 'dark', 'Sensitivity', threshSensitivity);
BW = ~BW;

% Extract horizontal staff lines using a linear structuring element
se_line_staff = strel('line', lineLength_staff, 0);
staff_lines = imopen(BW, se_line_staff);

% Remove staff lines to isolate the notes
notes_no_lines = BW & ~staff_lines;

% Use morphological closing to fill gaps in the notes
se_notes = strel('disk', diskRadius_notes);
notes_clean = imclose(notes_no_lines, se_notes);

% Filter connected components to remove unwanted features (e.g., text)
cc = bwconncomp(notes_clean);
stats = regionprops(cc, 'Area', 'Eccentricity', 'Solidity');
idx_notes = find([stats.Area] >= 35 & [stats.Eccentricity] <= 0.87 & [stats.Solidity] >= 0.5);
final_notes = false(size(notes_clean));
for i = 1:length(idx_notes)
    final_notes(cc.PixelIdxList{idx_notes(i)}) = true;
end

% Combine staff lines with the filtered note heads
final_cleaned = staff_lines | final_notes;

% Segment the image into staff segments using horizontal projection
horz_proj = sum(final_cleaned, 2);
smooth_proj = movmean(horz_proj, 15);
gap_thresh = max(smooth_proj) * 0.05;
staff_present = smooth_proj > gap_thresh;
changes = diff([0; staff_present; 0]);
startRows = find(changes == 1);
endRows = find(changes == -1) - 1;

staffSegments = {}; % Binary segments for processing
staffOffsets = [];  % Store the y-offset of each segment

for i = 1:length(startRows)
    row_start = max(startRows(i) - padding, 1);
    row_end = min(endRows(i) + padding, size(final_cleaned, 1));
    staffSegments{i} = final_cleaned(row_start:row_end, :);
    staffOffsets(i) = row_start - 1; % Store the offset to adjust coordinates later
end

%% Part 2: Note Detection on Each Staff Segment (Prepare for displaying on original image)
% Create figure with original image
figure;
imshow(img);
hold on;

% Store all detected note information
allNoteHeads = [];
allNoteNames = {};
allCentroids = [];

for i = 1:length(staffSegments)
    BW_segment = staffSegments{i};
    y_offset = staffOffsets(i); % Get the y-offset for this segment
    
    % --- Remove Staff Lines to Isolate Note Heads ---
    se_line_erase = strel('line', lineLength_erase, 0);
    BW_staff = imerode(BW_segment, se_line_erase);
    se_line_dilate = strel('line', lineLength_dilate, 0);
    BW_staff_dilated = imdilate(BW_staff, se_line_dilate);
    BW_noStaff = BW_segment & ~BW_staff_dilated;
    
    % --- Apply Morphological Closing and Dilation ---
    se_fill = strel('disk', diskRadius_fill);
    BW_filled = imclose(BW_noStaff, se_fill);
    se_horiz = strel('line', lineLength_merge, 0);
    BW_merged = imdilate(BW_filled, se_horiz);
    
    % --- Detect Connected Components as Candidate Note Heads ---
    cc = bwconncomp(BW_merged);
    stats = regionprops(cc, 'Area', 'Centroid', 'BoundingBox');
    areaVals = [stats.Area];
    
    if isempty(areaVals)
        warning('No connected components detected in segment %d.', i);
        continue;
    end
    
    % Compute dynamic area thresholds
    medianArea = median(areaVals);
    iqrArea = iqr(areaVals);
    minArea = max(5, medianArea - 1.5 * iqrArea);
    maxArea = medianArea + 3 * iqrArea;
    validIdx = (areaVals >= minArea) & (areaVals <= maxArea);
    noteHeads = stats(validIdx);
    
    if isempty(noteHeads)
        warning('No valid note heads detected in segment %d.', i);
        continue;
    end
    
    % Sort note heads left-to-right based on x-coordinate
    centroids = cat(1, noteHeads.Centroid);
    [~, sortIdx] = sort(centroids(:,1));
    noteHeads = noteHeads(sortIdx);
    
    % --- Detect Staff Lines for Note Positioning ---
    staffProps = regionprops(BW_staff, 'Centroid');
    staffLinesY = [];
    for sp = 1:length(staffProps)
        staffLinesY = [staffLinesY, staffProps(sp).Centroid(2)];
    end
    staffLinesY = sort(staffLinesY);
    
    if length(staffLinesY) < 5
        warning('Less than 5 staff lines detected in segment %d.', i);
        continue;
    else
        staffLinesY = staffLinesY(1:5);  % Use only the first 5 lines
    end
    
    % Compute the average spacing and the bottom staff line (E_line)
    d = mean(diff(staffLinesY));
    E_line = staffLinesY(end);
    
    % Define candidate vertical positions (relative to the bottom line)
    candidateY = E_line + [1, 0.5, 0, -0.5, -1, -1.5, -2, -2.5, -3, -3.5, -4, -4.5, -5] * d;
    noteNames = {'C','D','E','F','G','A','B','C','D','E','F','G','A'};
    
    % --- Assign Note Names Based on Vertical Proximity ---
    detectedNotes = cell(1, length(noteHeads));
    for k = 1:length(noteHeads)
        y_centroid = noteHeads(k).Centroid(2);
        [~, idx] = min(abs(candidateY - y_centroid));
        detectedNotes{k} = noteNames{idx};
        
        % Adjust bounding box coordinates with the y-offset
        noteHeads(k).BoundingBox(2) = noteHeads(k).BoundingBox(2) + y_offset;
        noteHeads(k).Centroid(2) = noteHeads(k).Centroid(2) + y_offset;
    end
    
    % Append to our overall lists
    for k = 1:length(noteHeads)
        allNoteHeads = [allNoteHeads; noteHeads(k)];
        allNoteNames = [allNoteNames, detectedNotes(k)];
        allCentroids = [allCentroids; noteHeads(k).Centroid];
    end
end

%% Draw all detected notes on the original image
for k = 1:length(allNoteHeads)
    rectangle('Position', allNoteHeads(k).BoundingBox, 'EdgeColor', 'yellow', 'LineWidth', 1.5);
    pos = allNoteHeads(k).Centroid;
    text(pos(1), pos(2) - 15, allNoteNames{k}, 'HorizontalAlignment', 'center', ...
         'Color', 'red', 'FontSize', 8, 'FontWeight', 'bold');
end

title('All Detected Notes on Original Sheet Music');
hold off;

% Display information about detected notes
fprintf('Total number of notes detected: %d\n', length(allNoteHeads));
fprintf('Notes detected: ');
for k = 1:length(allNoteNames)
    fprintf('%s ', allNoteNames{k});
    if mod(k, 20) == 0
        fprintf('\n');
    end
end
fprintf('\n');

%% Additional Figures for Major Instances (Overall Processing Stages)
% 1. Original Image
figure;
imshow(img);
title('Original Image');
pause(2);

% 2. Gamma Corrected Image
figure;
imshow(g);
title('Gamma Corrected Image');

pause(2);
% 3. Binarized Image after Adaptive Thresholding (inverted)
figure;
imshow(BW);
title('Binarized Image (After Adaptive Thresholding)');
pause(2);
% 4. Extracted Staff Lines
figure;
imshow(staff_lines);
title('Extracted Staff Lines');
pause(2);
% 5. Notes Isolated by Removing Staff Lines (notes_no_lines)
figure;
imshow(notes_no_lines);
title('Notes without Staff Lines');
pause(2);
% 6. Final Cleaned Image (Staff Lines + Filtered Note Heads)
figure;
imshow(final_cleaned);
title('Final Cleaned Image (Staff Lines + Notes)');
pause(2);
% 7. Staff Segments (only segments with at least 5 staff lines)
for i = 1:length(staffSegments)
    BW_segment = staffSegments{i};
    se_line_erase = strel('line', lineLength_erase, 0);
    BW_staff = imerode(BW_segment, se_line_erase);
    staffProps = regionprops(BW_staff, 'Centroid');
    staffLinesY = [];
    for sp = 1:length(staffProps)
        staffLinesY = [staffLinesY, staffProps(sp).Centroid(2)];
    end
    if length(staffLinesY) < 5
        continue;
    end
    figure;
    imshow(BW_segment);
    title(sprintf('Segment %d', i));
    pause(2);
end

%% Morphological Operations Example for One Valid Segment
% Find the first segment with at least 5 staff lines
chosenSegment = [];
for i = 1:length(staffSegments)
    seg = staffSegments{i};
    se_line_erase = strel('line', lineLength_erase, 0);
    BW_staff_temp = imerode(seg, se_line_erase);
    staffProps = regionprops(BW_staff_temp, 'Centroid');
    staffLinesY = [];
    for sp = 1:length(staffProps)
        staffLinesY = [staffLinesY, staffProps(sp).Centroid(2)];
    end
    if length(staffLinesY) >= 5
        chosenSegment = seg;
        break;
    end
end

if ~isempty(chosenSegment)
    % Compute the intermediate morphological operations for the chosen segment
    % Original Segment
    ex_segment = chosenSegment;
    
    % Erosion (remove staff lines)
    se_line_erase = strel('line', lineLength_erase, 0);
    ex_BW_staff = imerode(ex_segment, se_line_erase);
    
    % Dilation of eroded image
    se_line_dilate = strel('line', lineLength_dilate, 0);
    ex_BW_staff_dilated = imdilate(ex_BW_staff, se_line_dilate);
    
    % Staff removal result
    ex_BW_noStaff = ex_segment & ~ex_BW_staff_dilated;
    
    % Morphological closing
    se_fill = strel('disk', diskRadius_fill);
    ex_BW_filled = imclose(ex_BW_noStaff, se_fill);
    
    % Final dilation (merging)
    se_horiz = strel('line', lineLength_merge, 0);
    ex_BW_merged = imdilate(ex_BW_filled, se_horiz);
    
    % Display the intermediate results for the chosen segment
    figure;
    imshow(ex_segment);
    title('Example Segment: Original');

    pause(2);
    
    figure;
    imshow(ex_BW_staff);
    title('Example Segment: After Erosion');
    pause(2);

    figure;
    imshow(ex_BW_staff_dilated);
    title('Example Segment: After Dilation');
    
    pause(2);

    figure;
    imshow(ex_BW_noStaff);
    title('Example Segment: After Staff Removal');
    
    pause(2);

    figure;
    imshow(ex_BW_filled);
    title('Example Segment: After Morphological Closing');
    
    pause(2);

    figure;
    imshow(ex_BW_merged);
    title('Example Segment: After Final Dilation');
    pause(2);

else
    warning('No valid segment with at least 5 staff lines was found for the morphological operations example.');
end