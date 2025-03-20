clear all; close all;

%% PART 1: Preprocess and Segment the Full Image

% Read original image and convert to grayscale
img = imread('whole3.jpg');
grayImg = rgb2gray(img);

% Apply gamma transform to reduce yellowness
r = double(grayImg);
k = mean2(r);
E = 0.9;
s = 1 ./ (1.0 + (k ./ (r + eps)).^E);
g = uint8(255 * s);

% Adaptive binarization (invert so that notes/lines are white)
BW = imbinarize(g, 'adaptive','ForegroundPolarity','dark','Sensitivity',0.4);
BW = ~BW;

% Detect staff lines using a horizontal structuring element
se_line = strel('line', 50, 0);
staff_lines = imopen(BW, se_line);

% Remove the lines temporarily to help extract note heads
notes_no_lines = BW & ~staff_lines;
se_notes = strel('disk', 2);
notes_clean = imclose(notes_no_lines, se_notes);

% Filter out small objects (e.g., text) using region properties
cc = bwconncomp(notes_clean);
stats = regionprops(cc, 'Area', 'Eccentricity', 'Solidity');
idx_notes = find([stats.Area] >= 35 & [stats.Eccentricity] <= 0.87 & [stats.Solidity] >= 0.5);
final_notes = false(size(notes_clean));
for i = 1:length(idx_notes)
    final_notes(cc.PixelIdxList{idx_notes(i)}) = true;
end

% Combine the staff lines and the filtered notes
final_cleaned = staff_lines | final_notes;

% Segment the image into staffs via horizontal projection
horz_proj = sum(final_cleaned, 2);
smooth_proj = movmean(horz_proj, 15);
gap_thresh = max(smooth_proj)*0.05;
staff_present = smooth_proj > gap_thresh;
changes = diff([0; staff_present; 0]);
startRows = find(changes == 1);
endRows = find(changes == -1) - 1;

padding = 10;  % extra rows to include notes that lie slightly outside

%% PART 2: Process Each Valid Staff Segment for Note Detection

% Prepare the final output figure: show the original image with overlays.
finalFig = figure;
imshow(grayImg);
title('Final Detected Notes Overlay');
hold on;

% Container for all detected note labels (optional)
allDetectedNotes = {};

% Loop over each segmented staff region
for seg = 1:length(startRows)
    row_start = max(startRows(seg)-padding, 1);
    row_end   = min(endRows(seg)+padding, size(final_cleaned, 1));
    
    % Extract the corresponding segment from the original grayscale image.
    seg_gray = grayImg(row_start:row_end, :);
    
    % --- Note-Detection Pipeline for the Segment ---
    % Convert segment to binary and invert (so that staff lines/notes become white)
    BW_seg = imbinarize(seg_gray);
    BW_seg = imcomplement(BW_seg);
    
    % Detect staff lines in the segment using a long horizontal structuring element.
    se_line_seg = strel('line', 100, 0);
    BW_staff_seg = imerode(BW_seg, se_line_seg);
    
    % Extract staff line centroids (each centroid is [x, y])
    staffProps = regionprops(BW_staff_seg, 'Centroid');
    staffLinesY = [];
    for p = 1:length(staffProps)
        staffLinesY = [staffLinesY, staffProps(p).Centroid(2)];
    end
    staffLinesY = sort(staffLinesY);
    
    % Process this segment only if exactly 5 staff lines are detected.
    if length(staffLinesY) == 5
        % Remove staff lines while preserving note heads.
        BW_noStaff_seg = BW_seg - BW_staff_seg;
        
        % Fill gaps in note heads via morphological closing.
        se_fill = strel('disk', 3);
        BW_filled_seg = imclose(BW_noStaff_seg, se_fill);
        se_horiz = strel('line', 10, 0);
        BW_merged_seg = imdilate(BW_filled_seg, se_horiz);
        
        % Detect connected components (potential note heads)
        cc_seg = bwconncomp(BW_merged_seg);
        stats_seg = regionprops(cc_seg, 'Area', 'Centroid', 'BoundingBox');
        areaVals_seg = [stats_seg.Area];
        
        % Determine dynamic area thresholds (using median and IQR)
        if ~isempty(areaVals_seg)
            medianArea_seg = median(areaVals_seg);
            iqrArea_seg = iqr(areaVals_seg);
            minArea_seg = max(5, medianArea_seg - 1.5 * iqrArea_seg);
            maxArea_seg = medianArea_seg + 3 * iqrArea_seg;
        else
            % Skip this segment if no connected components detected.
            continue;
        end
        
        % Filter valid note heads by area.
        validIdx_seg = (areaVals_seg >= minArea_seg) & (areaVals_seg <= maxArea_seg);
        noteHeads_seg = stats_seg(validIdx_seg);
        
        % Compute staff spacing from the detected staff lines in this segment.
        d = mean(diff(staffLinesY));
        E_line_seg = staffLinesY(end);  % Bottom staff line corresponds to note E
        
        % Compute candidate Y-positions (relative to the segment)
        candidateY_seg = E_line_seg + [1, 0.5, 0, -0.5, -1, -1.5, -2, -2.5, -3, -3.5, -4, -4.5, -5] * d;
        noteNames = {'C','D','E','F','G','A','B','C','D','E','F','G','A'};
        
        % For each detected note head, determine the closest candidate position.
        for n = 1:length(noteHeads_seg)
            y_centroid = noteHeads_seg(n).Centroid(2);
            [~, idx] = min(abs(candidateY_seg - y_centroid));
            noteLabel = noteNames{idx};
            
            % Adjust the y-coordinate to match the coordinate system of the full image.
            orig_y = noteHeads_seg(n).Centroid(2) + row_start - 1;
            orig_x = noteHeads_seg(n).Centroid(1);
            
            % Overlay the note label next to the note on the final figure.
            text(orig_x + 10, orig_y, noteLabel, 'Color', 'red', 'FontSize', 12, ...
                'FontWeight', 'bold', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
            
            % Optionally, draw the bounding box (adjusted to full-image coordinates)
            bbox = noteHeads_seg(n).BoundingBox;
            bbox(2) = bbox(2) + row_start - 1;
            rectangle('Position', bbox, 'EdgeColor', 'yellow', 'LineWidth', 1.5);
            
            allDetectedNotes{end+1} = noteLabel;
            fprintf('Segment %d, Note %d: Local y = %.2f, Full y = %.2f, Assigned Note: %s\n', ...
                seg, n, y_centroid, orig_y, noteLabel);
        end
    else
        % Skip the segment if not exactly 5 staff lines.
        fprintf('Segment %d skipped: Detected %d staff lines (expected 5).\n', seg, length(staffLinesY));
        % Do not open any figure for this segment.
    end
end

hold off;
disp('Final Detected Notes:');
disp(allDetectedNotes);
