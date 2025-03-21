# Sheet Music Note Detection Pipeline: A Detailed Explanation

This MATLAB script is designed to process an image of sheet music, detect the musical note heads, and display them along with their corresponding note names on the original image. The code employs various image processing techniques—such as gamma correction, adaptive thresholding, morphological operations, and connected component analysis—to isolate and identify the notes accurately.

---

## 1. Initialization and Parameter Setup

The script begins by clearing the workspace and closing all figures. Then, several parameters are defined which control various aspects of the processing pipeline.

```matlab
clear variables;
close all;

%% PARAMETERS
gammaE = 0.9;          % Gamma correction exponent
threshSensitivity = 0.4;  % Sensitivity for adaptive thresholding
lineLength_staff = 100;  % Length for staff line structuring element
diskRadius_notes = 2;   % Radius for morphological closing on notes
padding = 10;           % Extra padding for staff segmentation
lineLength_erase = 100; % For eroding staff lines in segments
lineLength_dilate = 10; % For dilating eroded staff lines
diskRadius_fill = 3;    % For closing after staff removal
lineLength_merge = 10;  % For dilating after closing
```

---

## 2. Preprocessing and Segmentation of the Full Sheet Music

### a. Input of Image

The image is loaded and converted to grayscale. A gamma correction is applied to adjust brightness and counteract the yellowish hue from aged paper.

```matlab
% Read the full image and convert to grayscale
img = imread('old4.jpg');
grayImg = rgb2gray(img);

% Gamma transform to reduce yellowness from old pictures
r = double(grayImg);
k = mean2(r);
s = 1 ./ (1.0 + (k ./ (r + eps)).^gammaE);
g = uint8(255 * s);
```

**Grayscale Conversion:** Simplifies the image by removing color and is needed to be able to do further processing

**Gamma Correction:** Alters the luminance values to normalize brightness, which is particularly useful for old images where yellowing may occur.

### b. Binarization and Inversion

The gamma-corrected image is binarized using adaptive thresholding. 

```matlab
% Binarize the gamma-corrected image using adaptive thresholding
BW = imbinarize(g, 'adaptive', 'ForegroundPolarity', 'dark', 'Sensitivity', threshSensitivity);
BW = ~BW;
```

**Adaptive Thresholding:** Adjusts the threshold locally to account for uneven illumination.

**Inversion:** Inverts the image so that the staff lines and notes become white on a black background.

### c. Extracting and Removing Staff Lines

A linear structuring element is used to extract horizontal staff lines. These lines are then subtracted from the binary image to help isolate the notes.

```matlab
% Extract horizontal staff lines using a linear structuring element
se_line_staff = strel('line', lineLength_staff, 0);
staff_lines = imopen(BW, se_line_staff);

% Remove staff lines to isolate the notes
notes_no_lines = BW & ~staff_lines;
```

**Morphological Opening:** This operation isolates the long horizontal lines that correspond to staff lines.

**Subtraction:** Removing the staff lines  leaves just the notes.

### d. Fixing the Note

Morphological closing is applied to fill gaps in the isolated note heads which were formed by the staff intersecting them.

```matlab
% Use morphological closing to fill gaps in the notes
se_notes = strel('disk', diskRadius_notes);
notes_clean = imclose(notes_no_lines, se_notes);
```

**Closing:** Helps in connecting fragmented parts of the note, which allows for further analysis.

### e. Filtering and Combining Components

The potential notes are filtered based on area, eccentricity, and solidity to eliminates features like text. Then, the valid notes are combined with the original staff lines.

```matlab
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
```

### f. Segmenting the Image into Line-by-Line

The script computes a horizontal projection of the image to find regions where staff lines are and then segments the image accordingly with some padding.

```matlab
matlab
Copy
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

```

**Horizontal Projection:** Adds pixel values along each row to detect areas with significant content (i.e., staff lines).

**Moving Mean Smoothing:** Reduces noise in the projection.

**Thresholding and Finding Changes:** Detects transitions from background to staff regions and vice versa.

**Segmentation:** Each detected staff region is extracted along with a little extra padding to capture the entire staff area.

---

## 3. Note Detection on Each Segment

After segmenting the notes into different parts, we know do the detection of the notes within each segment, i.e. assigning letters to each notehead.

### a. Preparing the Display

This part prepares the image on which all 4 segments will later be combined.

```matlab
% Create figure with original image
figure;
imshow(img);
hold on;

% Store all detected note information
allNoteHeads = [];
allNoteNames = {};
allCentroids = [];

```

- **Setup:** Opens a figure, displays the original image, and prepares arrays to store the detection results.

### b. Processing Each Staff Segment

For each segmented staff region, the code performs several steps to isolate note heads from any remaining staff line artifacts. A *for* loop is set up to go through each sheet segment.

```matlab

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

```

- **Staff Line Removal:**
    - The first step is to isolate the noteheads in this section. To do that, the staff lines are removed.
    - *Erosion* with a long horizontal SE removes thin lines (staff lines).
    - *Dilation* then slightly restores shapes that may have been overly eroded. There were times when we observed that removing the lines cuts off the noteheads.
    - The difference (`BW_segment & ~BW_staff_dilated`) removes the staff lines from the segment.
- **Closing and Dilation:**
    - A disk-shaped closing operation fills in gaps left in the note heads. This also helps in filling the notehead to make sure it can be recognized as a connected component.
    - A subsequent horizontal dilation merges nearby elements to form more continuous regions corresponding to the note heads.

### c. Connected Component Analysis in the Segment

At this point, the noteheads are individual connected components which can be counted, and located in XY coordinates.

```matlab
matlab
Copy
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

```

- **CC Stats:**
- `regionprops` finds specific properties for each connected component found in `cc`.
- The properties being calculated are:
    - **Area:** The number of pixels in the component.
    - **Centroid:** The (x, y) coordinates representing the center of mass of the component.
    - **BoundingBox:** The smallest rectangle that fully contains the component.
- **Dynamic Thresholding:**
    - As different sheets might have different notehead sizes, we did not want to set manual sizing filters, thus we use the Interquartile ranges to determine what size we are actually looking for.
    - This helps to reject regions that are too small (likely noise) or too large (possibly merged or non-note components). This makes sure that most detections are actually noteheads and not text of the cle, etc
- **Sorting:**
    - Note heads are sorted left-to-right, which is important for proper ordering when interpreting musical notation. This is done by using their x values (index 1)

### d. Detecting Staff Lines Within the Segment for Note Positioning

Assigning each note a letter is actually quite straight forward. It uses the Y values of the staff lines as reference and compares it to the note’s Y values

```matlab
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

```

- **Staff Line Extraction:**
    - Using `regionprops` on the eroded staff lines (`BW_staff`), the centroids of these lines are computed.
    - If there are less than 5 lines detected, the script assumes its a wrong segment (an error in some of the previous steps) and discards them
    - If not, it takes the 5 lines and stores them in an array.

### e. Assigning Note Names Based on Vertical Position

Using the positions of the staff lines, the script defines candidate vertical positions for notes relative to the bottom line (E-line) and calculates the average spacing. Then, each detected note is assigned a note name (C, D, E, etc.) by comparing its centroid to these candidate positions.

```matlab
matlab
Copy
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

```

- **Average Staff Spacing (`d`):**
    - With the 5 lines detected, we get an average of the spacing between them, in order to determine candidate note positions.
- **Candidate Positions:**
    - We are assuming that most staff music has notes from the C below the staff notation, all the way up to A.
    - The bottom-most staff line (E) is taken as reference and based on the spacing, each possible note is assigned a Y value
- **Note Name Assignment:**
    - We then take the detected notehead centroids and find the closest candidate position for it to assign a value.
    - The bounding box and centroid coordinates are adjusted with the segment’s offset so that they align correctly with the full image.

### f. Accumulating and Storing the Results

Each detected note from the segment is added to a cumulative list that stores all note heads, their assigned names, and centroids.

```matlab
    % Append to our overall lists
    for k = 1:length(noteHeads)
        allNoteHeads = [allNoteHeads; noteHeads(k)];
        allNoteNames = [allNoteNames, detectedNotes(k)];
        allCentroids = [allCentroids; noteHeads(k).Centroid];
    end
end

```

- **Result Accumulation:**
    - This allows for the final step to display and annotate all the detected notes across the entire sheet music image.

---

## 4. Displaying the Results on the Original Image

After processing all staff segments, the detected note heads are drawn on the original image with bounding boxes and note names.

```matlab
matlab
Copy
%% Draw all detected notes on the original image
for k = 1:length(allNoteHeads)
    rectangle('Position', allNoteHeads(k).BoundingBox, 'EdgeColor', 'yellow', 'LineWidth', 1.5);
    pos = allNoteHeads(k).Centroid;
    text(pos(1), pos(2) - 15, allNoteNames{k}, 'HorizontalAlignment', 'center', ...
         'Color', 'red', 'FontSize', 8, 'FontWeight', 'bold');
end

title('All Detected Notes on Original Sheet Music');
hold off;

```

- **Annotation:**
    - Rectangles highlight the detected note head areas.
    - Text labels are placed slightly above the note heads to indicate the note names.
- **Visualization:**
    - The original image now serves as the canvas, providing context for the detected elements.

---

## 5. Summary of Detected Notes

Finally, the script prints the total count of detected notes along with their names to the command window.

```matlab
matlab
Copy
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

```

- **Feedback:**
    - This output provides a quick summary and verification of the detection process, which can be useful for debugging and analysis.

---

## Conclusion

This MATLAB script illustrates a comprehensive approach to processing sheet music images. By employing adaptive thresholding, morphological operations, connected component analysis, and spatial reasoning based on staff line positions, the code effectively isolates note heads and assigns them musical note names. Each step—from preprocessing to segmentation and final annotation—is designed to handle the challenges posed by the inherent noise and degradation in old sheet music images.

Feel free to adjust the parameters at the beginning of the script to better suit different images or to refine the note detection performance.
