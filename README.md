# Optical Music Recognition (OMR) - Full Note Detection

## Team Report

### Team Achievements:

We developed an Optical Music Recognition system focused on accurately identifying and segmenting full notes from old/degraded sheet music images.

**Preprocessing Stage:**
- **Adaptive Binarization**

Enhances contrast and clearly separates notes from the background.

- **Morphological Processing**
    
    Extracts horizontal staff lines using morphological operations (`imopen`) and removes them from images to isolate notes.
    
- **Shape and Solidity Filtering**
    
    Filters components based on solidity and eccentricity, clearly isolating oval-shaped notes and reducing textual noise.
    

**Segmentation Stage:**
- **Horizontal Projection Analysis** 

Detects and segments sheet music into individual staves through smoothed horizontal projection profiles.

**Note Detection Stage:**
- **Morphological Analysis** 

Uses morphological techniques to isolate the noteheads and remove the staff lines

- **Connected Components** 

Uses CC in order to detect the size of noteheads and denote if its a valid note or just random noise/text

- **Positioning** 

Simply finds the Y values of the detected CCs and compares it against the Y values of the lines in order to determine which note it is.

 

### Special Instructions to Run:

- Download ZIP folder
- Run the main script (`OldMusicSheetConverter.m`) in MATLAB located in the repository root.
- Replace the image file in the script with any of the images in the images folder to try out how it works on different sheets of music

### Evidence of Application Working:

- Clearly segmented images demonstrating preprocessing and note isolation are included in the `outputs` directory.
- MATLAB figures show each processing step, confirming functionality.
- There is  also a video in the ouput folder which shows how the application runs

### Application Evaluation:

**Strengths:**
- Effectively isolates full notes and staff lines.
- Successfully segments individual music lines, preparing them for subsequent note classification.

**Limitations:**
- Difficulty fully removing text annotations, occasionally affecting accuracy.
- Optimized specifically for full (oval) notes—may require tuning for other note types.
- Falsely detects edges of the staff lines as notes.

**Future Improvements:**

- Advanced text-removal techniques
- Recognize different types of notes: quarter notes, half notes, etc
    - Remove the vertical lines (stems) in notes and still focus on elliptical notehead
- Recognize other elements in sheet music: clefs, symbols, rests, etc
    - More morphological techniques
- Detect different scales
    - This could be achieved by specifically looking at the left side of all segments, detecting any sharps or flats and their positions, and assign the corresponding notes the same.
 
### Code:
The code consists of multiple image processing techniques. The reasoning behind their use has been explained in Code_Explanation.md



---

## Personal Statements

### [Namit Garg - 02026535]

For this coursework, I was responsible for carrying out intensity transformation, morphological operations and segmentation to pre-process the old images into segmented line-by-line music blocks. 

There were quite a few challenges with regards to isolating notes and staves (horizontal lines) and removing noise since the noise would often be picked up as being similar intensity as the notes. Initially gamma correction was used however this seemed to be inconsistent with the results and so adaptive thresholding was utilized to make this more robust. I also made use of morphological filtering with a horizontal line SE to identify the lines. This was needed to be able to segment them into separate lines of music.

One of the mistakes made during the development was to have a static values for the structuring element which is used to identify the horizontal lines as this will only work on the standard size of music sheet so to fix this I would implement a dynamic SE which is worked out based on the size of the sheet. Another mistake is that when notes are too close to one another, the system struggles to identify some of them, to fix this, I would apply erosion on the notes to increase the gaps between the notes.

Throughout this project I have learnt a lot about visual systems and image processing through all the operations I have mentioned and hope to build on this going forward.

### [Aditya Munot - 02150093]

In this assignment, I focused on doing the actual note detection and combining the preprocessing code with it. 

Going into the assignment, I had initially assumed it to be a straightforward task but was soon faced with multiple challenges, especially from the fact that each image is unique, and I can’t set fixed parameters or values which would fit all scenarios. Thus, it was quite interesting to play with Morphological operators to make sure each note is detected.

I used to techniques to detect lines, morphological operators and Hough transforms. I initially thought the latter would yield better results, but it was the operators which turned out to be more reliable. Using other techniques such as closing and dilation, I was able to isolate noteheads to make sure that they were properly detected.

I also implemented parameters such as the thresholds for connected components to be dynamically adjusted. This allowed different types of images to have accurate results, without manually changing any parameters. 

Personally, the key limitation with the way noteheads were found is that it relies heavily on the notion of CCs, which means that detecting notes with stems and other symbols in sheet music becomes more complicated. The code also struggled to eliminate all of text, and there were instances where it would detect a fairly round text to be a note too!

Overall, the assignment was quite interesting. My key takeaway from the assignment is that for such scenarios, lots of people would implement machine learning, but with some smart image processing techniques, this could be an as reliable alternative.
