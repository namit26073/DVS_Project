% Step 1: Read Image and Convert to Grayscale
I = imread('LK1.png');  % Change to your actual image filename

if size(I,3) == 3
    I_gray = rgb2gray(I);
else
    I_gray = I;
end
figure, imshow(I_gray), title('Original Grayscale Image');

% Step 2: Convert to Binary and Invert (Notes & Lines = White)
BW = imbinarize(I_gray);
BW = imcomplement(BW);
figure, imshow(BW), title('Binary Image After Thresholding');

% Step 3: Detect Staff Lines Using Morphology
se_line = strel('line', 10, 0);  % Long horizontal structuring element
BW_staff = imerode(BW, se_line);  % Initial extraction of staff lines

% Dilate to cover the full line width
se_line_dilate = strel('line', 15, 0);
BW_staff_dilated = imdilate(BW_staff, se_line_dilate);
figure, imshow(BW_staff_dilated), title('Dilated Staff Lines');

% Step 4: Remove Staff Lines
BW_noStaff = BW & ~BW_staff_dilated;
figure, imshow(BW_noStaff), title('Image After Full Staff Line Removal');


% Step 5: Apply Morphological Closing to Fix Splits in Notes
se_fill = strel('disk', 3);
BW_filled = imclose(BW_noStaff, se_fill);
se_horiz = strel('line', 10, 0);
BW_merged = imdilate(BW_filled, se_horiz);
figure, imshow(BW_merged), title('After Bridging Note Heads');

% Step 6: Detect Connected Components (CCs)
cc = bwconncomp(BW_merged);
stats = regionprops(cc, 'Area', 'Centroid', 'BoundingBox');

% Compute area values
areaVals = [stats.Area];

% Step 7: Automatically Determine `minArea` and `maxArea`
if ~isempty(areaVals)
    medianArea = median(areaVals);
    iqrArea = iqr(areaVals);  % Interquartile range (IQR)
    
    % Define min and max dynamically
    minArea = max(5, medianArea - 1.5 * iqrArea);  % Avoid extreme small objects
    maxArea = medianArea + 3 * iqrArea;  % Allow some variation but exclude outliers
else
    error('No connected components detected.');
end

fprintf('Automatically determined minArea = %.2f, maxArea = %.2f\n', minArea, maxArea);

% Step 8: Filter Valid Note Heads Using Dynamic Area Limits
validIdx = (areaVals >= minArea) & (areaVals <= maxArea);
noteHeads = stats(validIdx);

% Step 9: Visualize Detected Connected Components
figure, imshow(BW_merged), hold on;
for k = 1:length(noteHeads)
    rectangle('Position', noteHeads(k).BoundingBox, 'EdgeColor', 'yellow', 'LineWidth', 1.5);
    plot(noteHeads(k).Centroid(1), noteHeads(k).Centroid(2), 'ro', 'MarkerSize', 8, 'LineWidth', 1.5);
end
title('Detected Connected Components (Potential Note Heads)');
hold off;

% Step 10: Detect Staff Lines Again (Ensure Exactly 5)
staffLines = regionprops(BW_staff, 'Centroid');
staffLinesY = sort([staffLines.Centroid]);

% Ensure exactly 5 staff lines are kept
if length(staffLinesY) > 5
    staffLinesY = staffLinesY(1:5);  % Keep only the first 5 (ignore extra)
elseif length(staffLinesY) < 5
    error('Staff line detection failed. Expected 5 lines, found less.');
end

% Compute the staff line spacing (d)
d = mean(diff(staffLinesY));

% Find the bottom-most staff line (which corresponds to E)
E_line = staffLinesY(end);  % Highest Y value (bottom staff line)

% Compute note positions using relative spacing from E
candidateY = E_line + [1, 0.5, 0, -0.5, -1, -1.5, -2, -2.5, -3, -3.5, -4, -4.5, -5] * d;

% Define the corresponding note names
noteNames = {'C','D','E','F','G','A','B','C','D','E','F','G','A'};

disp('Corrected Candidate Y-Positions (Using Relative Positioning):');
disp(candidateY);
disp('Corrected Note Mapping Order:');
disp(noteNames);

% Step 11: Assign Notes and Display Results
detectedNotes = {};
figure, imshow(I_gray), hold on;
for k = 1:length(noteHeads)
    y_centroid = noteHeads(k).Centroid(2);
    
    % Find Closest Note
    [~, idx] = min(abs(candidateY - y_centroid));
    noteLabel = noteNames{idx};

    % Print Debug Information
    fprintf('Note %d: Y-Centroid = %.2f, Assigned Note: %s (Closest Y = %.2f)\n', ...
            k, y_centroid, noteLabel, candidateY(idx));

    % Store Detected Note
    detectedNotes{end+1} = noteLabel;
    
    % Overlay Note Labels Slightly to the Side
    text(noteHeads(k).Centroid(1) + 10, noteHeads(k).Centroid(2), noteLabel, ...
        'Color', 'red', 'FontSize', 12, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
end
title('Final Detected Notes with Labels');

disp('Final Detected Notes:');
disp(detectedNotes);
