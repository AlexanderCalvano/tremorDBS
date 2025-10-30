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