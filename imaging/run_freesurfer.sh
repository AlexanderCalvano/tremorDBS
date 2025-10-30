echo "Starting FreeSurfer recon-all for subject: $1"
recon-all -i "$STRUCTURAL_DIR/anat_t1.nii.gz" -s "$1" -sd "$FREESURFER_DIR" -all

if [ $? -eq 0 ]; then
    echo "FreeSurfer recon-all completed successfully for subject: $1"
else
    echo "ERROR: FreeSurfer recon-all failed for subject: $1"
    exit 1
fi
echo "FreeSurfer output saved in: $FREESURFER_DIR/$1"
