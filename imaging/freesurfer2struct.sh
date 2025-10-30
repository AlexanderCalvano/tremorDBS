echo "Generating brain_t1_native.mgz..."
FS_MRI_DIR=$FREESURFER_DIR/$1/mri
mri_label2vol \
    --seg  	$FS_MRI_DIR/brain.mgz           \
    --temp 	$FS_MRI_DIR/rawavg.mgz          \
    --o    	$FS_MRI_DIR/brain_t1_native.mgz \
    --regheader $FS_MRI_DIR/brain.mgz
check_file "$FS_MRI_DIR/brain_t1_native.mgz"

mri_convert "$FS_MRI_DIR/brain_t1_native.mgz" $FS_MRI_DIR/anat_t1_brain.nii.gz
check_file "$FS_MRI_DIR/anat_t1_brain.nii.gz"

# antsRegistration --dimensionality 3 --float 0 \
#   --output ["$SUBJECT_DIR/t1_to_MNI","$SUBJECT_DIR/t1_to_MNIWarped.nii.gz"] \
#   --interpolation Linear \
#   --initial-moving-transform ["$FREESURFER_DIR/mri/anat_t1_brain.nii.gz","$MNI_FILE",1] \
#   --transform Rigid[0.1] \
#   --metric MI[$FREESURFER_DIR/mri/anat_t1_brain.nii.gz,$MNI_FILE,1,32,Regular,0.25] \
#   --convergence [1000x500x250x100,1e-6,10] \
#   --shrink-factors 8x4x2x1 \
#   --smoothing-sigmas 3x2x1x0vox \
#   --transform Affine[0.1] \
#   --metric MI[$FREESURFER_DIR/mri/anat_t1_brain.nii.gz,$MNI_FILE,1,32,Regular,0.25] \
#   --convergence [1000x500x250x100,1e-6,10] \
#   --shrink-factors 8x4x2x1 \
#   --smoothing-sigmas 3x2x1x0vox \
#   --transform SyN[0.1,3,0] \
#   --metric CC[$FREESURFER_DIR/mri/anat_t1_brain.nii.gz,$MNI_FILE,1,4] \
#   --convergence [100x70x50x20,1e-6,10] \
#   --shrink-factors 8x4x2x1 \
#   --smoothing-sigmas 3x2x1x0vox \
#   --verbose 1
#   check_file "$SUBJECT_DIR/t1_to_MNIWarped.nii.gz"
