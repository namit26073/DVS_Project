


% Loop over each segmented staff and apply note detection
for i = 1:length(staffSegments)
    BW_segment = staffSegments{i};
    origSegment = origSegments{i};

    % --- Remove Staff Lines to Isolate Note Heads ---
    se_line = strel('line', 100, 0);
    BW_staff = imerode(BW_segment, se_line);
    se_line_dilate = strel('line', 10, 0);
    BW_staff_dilated = imdilate(BW_staff, se_line_dilate);
…    pos = noteHeads(k).Centroid;
    text(pos(1), pos(2) - offset, detectedNotes{k}, 'HorizontalAlignment', 'center', ...
         'Color', 'red', 'FontSize', 8, 'FontWeight', 'bold');
end

    
    title(['Detected Notes for Staff Segment ' num2str(i)]);
    hold off;
end
Search (Ctrl+Shift+Space)
has popup
