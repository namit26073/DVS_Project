%% Part 1: Preprocess and Segment the Full Sheet Music
% Read the full (original) image and convert to grayscale
img = imread('whole3.jpg');
grayImg = rgb2gray(img);

% Gamma transform to reduce yellowness from old pictures
r = double(grayImg);
k = mean2(r);
E = 0.9;
s = 1 ./ (1.0 + (k ./ (r + eps)).^E);
g = uint8(255 * s);

% Binarize the gamma-corrected image using adaptive thresholding
BW = imbinarize(g, 'adaptive','ForegroundPolarity','dark','Sensitivity',0.4);
BW = ~BW;

% Extract horizontal staff lines with a linear structuring element
se_line = strel('line', 50, 0);
staff_lines = imopen(BW, se_line);

% Temporarily remove the staff lines to isolate the notes
notes_no_lines = BW & ~staff_lines;

% Use morphological closing to fill any gaps in the notes
se_notes = strel('disk', 2);
notes_clean = imclose(notes_no_lines, se_notes);

% Filter connected components to remove unwanted features (e.g., text)
cc = bwconncomp(notes_clean);
stats = regionprops(cc, 'Area', 'Eccentricity', 'Solidity');
idx_notes = find([stats.Area] >= 35 & [stats.Eccentricity] <= 0.87 & [stats.Solidity] >= 0.5);
final_notes = false(size(notes_clean));
for i = 1:length(idx_notes)
    final_notes(cc.PixelIdxList{idx_notes(i)}) = true;
end

% Combine the staff lines with the filtered note heads
final_cleaned = staff_lines | final_notes;

% Segment the image into staff segments using horizontal projection
horz_proj = sum(final_cleaned, 2);
smooth_proj = movmean(horz_proj, 15);
gap_thresh = max(smooth_proj)*0.05;
staff_present = smooth_proj > gap_thresh;
changes = diff([0; staff_present; 0]);
startRows = find(changes == 1);
endRows = find(changes == -1) - 1;

padding = 10; % extra padding around each segment
staffSegments = {}; % to hold binary segments (for processing)
origSegments = {};  % to hold corresponding original image segments

for i = 1:length(startRows)
    row_start = max(startRows(i) - padding, 1);
    row_end = min(endRows(i) + padding, size(final_cleaned,1));
    % Extract the binary segment (used for detection)
    binarySegment = final_cleaned(row_start:row_end, :);
    staffSegments{i} = binarySegment;
    % Also extract the corresponding region from the original image
    origSegments{i} = img(row_start:row_end, :, :);
end

%% Part 2: Note Detection on Each Staff Segment (Overlay on Original Image)
% Loop over each segmented staff and apply note detection
for i = 1:length(staffSegments)
    BW_segment = staffSegments{i};
    origSegment = origSegments{i};

    % --- Remove Staff Lines to Isolate Note Heads ---
    se_line = strel('line', 10, 0);
    BW_staff = imerode(BW_segment, se_line);
    se_line_dilate = strel('line', 15, 0);
    BW_staff_dilated = imdilate(BW_staff, se_line_dilate);
    BW_noStaff = BW_segment & ~BW_staff_dilated;

    % --- Apply Morphological Closing and Dilation ---
    se_fill = strel('disk', 3);
    BW_filled = imclose(BW_noStaff, se_fill);
    se_horiz = strel('line', 10, 0);
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

    % Sort note heads left-to-right based on the x-coordinate
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
        staffLinesY = staffLinesY(1:5);  % Use the first 5 detected lines
    end
    
    % Compute the average spacing and the bottom staff line (E)
    d = mean(diff(staffLinesY));
    E_line = staffLinesY(end);
    
    % Define candidate vertical positions (relative to the bottom line)
    candidateY = E_line + [1, 0.5, 0, -0.5, -1, -1.5, -2, -2.5, -3, -3.5, -4, -4.5, -5] * d;
    noteNames = {'C','D','E','F','G','A','B','C','D','E','F','G','A'};
    
    % --- Assign Note Names Based on Vertical Proximity ---
    detectedNotes = {};
    for k = 1:length(noteHeads)
        y_centroid = noteHeads(k).Centroid(2);
        [~, idx] = min(abs(candidateY - y_centroid));
        noteLabel = noteNames{idx};
        detectedNotes{end+1} = noteLabel;
    end

    % --- Display the Original Image Segment with Overlays ---
    figure;
    imshow(origSegment);
    hold on;
    
    % Draw bounding boxes on the original image for each detected note head
    for k = 1:length(noteHeads)
        rectangle('Position', noteHeads(k).BoundingBox, 'EdgeColor', 'yellow', 'LineWidth', 1.5);
    end
    
    % Create a horizontal string of note labels (sorted left-to-right)
   % Draw bounding boxes on the original image for each detected note head
for k = 1:length(noteHeads)
    rectangle('Position', noteHeads(k).BoundingBox, 'EdgeColor', 'yellow', 'LineWidth', 1.5);
end

% Annotate each note directly at its corresponding note head (using data coordinates)
offset = 15; % adjust as needed so the label doesn't overlap the note head
for k = 1:length(noteHeads)
    pos = noteHeads(k).Centroid;
    text(pos(1), pos(2) - offset, detectedNotes{k}, 'HorizontalAlignment', 'center', ...
         'Color', 'red', 'FontSize', 14, 'FontWeight', 'bold');
end

    
    title(['Detected Notes for Staff Segment ' num2str(i)]);
    hold off;
end
