# Optical Music Recognition (OMR) - Full Note Detection

## Team Report

### Team Achievements:
We developed an Optical Music Recognition (OMR) system focused on accurately identifying and segmenting full notes from sheet music images. Our implementation leverages techniques learned from **Lab 4: Morphological Image Processing** and **Lab 5: Segmentation and Feature Detection**.

**Preprocessing Stage:**
- **Adaptive Binarization (Lab 5)**  
  Enhances contrast and clearly separates notes from the background.
  
- **Morphological Processing (Lab 4)**  
  Extracts horizontal staff lines using morphological operations (`imopen`) and removes them from images to isolate notes.

- **Shape and Solidity Filtering**  
  Filters components based on solidity and eccentricity, clearly isolating oval-shaped notes and reducing textual noise.

**Segmentation Stage:**
- **Horizontal Projection Analysis (Lab 5)**  
  Detects and segments sheet music into individual staves through smoothed horizontal projection profiles.

### Special Instructions to Run:
- Ensure MATLAB is installed on your system.
- Run the main script (`main.m`) in MATLAB located in the repository root.
- Replace `whole2.jpg` in the script with your image file name to test other sheet music.

### Evidence of Application Working:
- Clearly segmented images demonstrating preprocessing and note isolation are included in the `outputs` directory.
- MATLAB figures show each processing step, confirming functionality.

### Application Evaluation:

**Strengths:**
- Effectively isolates full notes and staff lines.
- Successfully segments individual music lines, preparing them for subsequent note classification.

**Limitations:**
- Difficulty fully removing text annotations, occasionally affecting accuracy.
- Optimized specifically for full (oval) notes—may require tuning for other note types.

**Future Improvements:**
- Integrate OCR or advanced morphological text-removal techniques.
- Extend functionality to recognize additional note types (quarter notes, half notes, etc.).

---

## Personal Statements

### [Namit Garg - 02026535]
I was responsible for the preprocessing and segmentation stages. My primary focus was on using adaptive thresholding and morphological operations (Lab 4 and Lab 5) to isolate notes effectively. Major challenges involved dealing with text interference. If repeated, I'd explore specialized text-removal methods earlier in development.
