DTI_NIFTI="$DIFFUSION_DIR/data.nii.gz"
BVAL="$DIFFUSION_DIR/bvals"
BVEC="$DIFFUSION_DIR/bvecs"
JSON_FILE="$DIFFUSION_DIR/data.json"
ACQP_FILE="$DIFFUSION_DIR/acqparams.txt"
INDEX_FILE="$DIFFUSION_DIR/index.txt"

echo $DTI_NIFTI
echo $BVAL
echo $BVEC
echo $JSON_FILE

# Check required files
if [ ! -f "$DTI_NIFTI" ] || [ ! -f "$BVAL" ] || [ ! -f "$BVEC" ] || [ ! -f "$JSON_FILE" ]; then
    echo "ERROR: Required files are missing in $DIFFUSION_DIR."
    exit 1
fi

cd "$DIFFUSION_DIR" || exit

# Step 1: Automatically create acqparams.txt
echo "[INFO] Extracting metadata from JSON to create acqparams.txt..."
PHASE_ENCODING=$(grep '"PhaseEncodingDirection"' $JSON_FILE | awk -F '"' '{print $4}')
TOTAL_READOUT=$(grep '"TotalReadoutTime"' $JSON_FILE | awk -F ': ' '{print $2}' | tr -d ',')

if [[ $PHASE_ENCODING == "j-" ]]; then
    echo "0 -1 0 $TOTAL_READOUT" > $ACQP_FILE
elif [[ $PHASE_ENCODING == "j" ]]; then
    echo "0 1 0 $TOTAL_READOUT" > $ACQP_FILE
elif [[ $PHASE_ENCODING == "i-" ]]; then
    echo "-1 0 0 $TOTAL_READOUT" > $ACQP_FILE
elif [[ $PHASE_ENCODING == "i" ]]; then
    echo "1 0 0 $TOTAL_READOUT" > $ACQP_FILE
else
    echo "ERROR: Unsupported PhaseEncodingDirection: $PHASE_ENCODING"
    exit 1
fi
echo "[INFO] acqparamso.txt created: $(cat $ACQP_FILE)"

# Step 2: Automatically create index.txt
echo "[INFO] Creating index.txt..."
NUM_VOLUMES=$(fslval $DTI_NIFTI dim4)
yes 1 | head -n $NUM_VOLUMES > $INDEX_FILE
echo "[INFO] index.txt created with $NUM_VOLUMES volumes."

# Step 3: Extract b0 from DTI data
echo "[INFO] Extracting b0 from DTI data..."
fslroi $DTI_NIFTI b0.nii.gz 0 1

# Step 4: Skull strip the b0 image
echo "[INFO] Skull stripping b0 image..."
bet b0.nii.gz b0_brain.nii.gz -m -f 0.2

# Step 5: Perform eddy correction
echo "[INFO] Running eddy correction..."
eddy --imain=$DTI_NIFTI \
     --mask=b0_brain_mask.nii.gz \
     --index=$INDEX_FILE \
     --acqp=$ACQP_FILE \
     --bvecs=$BVEC \
     --bvals=$BVAL \
     --out=eddy_corrected

# Step 6: Delete old bvecs and rename rotated bvecs
if [ -f "bvecs" ]; then
    echo "[INFO] Deleting old bvecs file..."
    rm bvecs
fi

if [ -f "eddy_corrected.eddy_rotated_bvecs" ]; then
    echo "[INFO] Renaming eddy-corrected bvecs to bvecs..."
    mv eddy_corrected.eddy_rotated_bvecs bvecs
else
    echo "ERROR: Rotated bvecs file not found. Eddy correction might have failed."
    exit 1
fi

# Step 7: Rename brain mask
echo "[INFO] Renaming brain mask..."
mv b0_brain_mask.nii.gz nodif_brain_mask.nii.gz

# Step 8: Rename diffusion data
echo "[INFO] Renaming diffusion data..."
mv $DTI_NIFTI $DIFFUSION_DIR/raw_data.nii.gz
mv eddy_corrected.nii.gz $DTI_NIFTI

# Step 9: Perform BEDPOSTX
echo "[INFO] Running BEDPOSTX..."
bedpostx_gpu "$DIFFUSION_DIR"

echo "[INFO] Workflow completed for $1"
