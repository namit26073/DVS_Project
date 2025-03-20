clear variables;
close all;

%% PARAMETERS (tweak these if needed)
gammaE = 0.9;          % Gamma correction exponent
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
img = imread('old4.jpg');
grayImg = rgb2gray(img);

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
