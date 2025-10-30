#!/bin/bash
# generate white matter mask for probtrackx from segmentation result

SUBDIR=$1
DIFDIR=$SUBDIR/diffusion
SEGFILE="$DIFDIR/aseg2diff.nii.gz"

# extract white matter and brainstem from segmentation file
fslmaths $SEGFILE -thr 2  -uthr  2 -bin $DIFDIR/cortical_wm_left.nii.gz
fslmaths $SEGFILE -thr 41 -uthr 41 -bin $DIFDIR/cortical_wm_right.nii.gz
fslmaths $SEGFILE -thr 7  -uthr  7 -bin $DIFDIR/cerebellar_wm_left.nii.gz
fslmaths $SEGFILE -thr 46 -uthr 46 -bin $DIFDIR/cerebellar_wm_right.nii.gz
fslmaths $SEGFILE -thr 16 -uthr 16 -bin $DIFDIR/brainstem.nii.gz

# add regions / create mask for possible fiber tracking paths
fslmaths $DIFDIR/cortical_wm_left.nii.gz    -add \
         $DIFDIR/cortical_wm_right.nii.gz   -add \
         $DIFDIR/cerebellar_wm_left.nii.gz  -add \
	 $DIFDIR/cerebellar_wm_right.nii.gz -add \
         $DIFDIR/brainstem.nii.gz           -bin \
         $DIFDIR/pathmask.nii.gz

# generate dilated white matter mask for creating ROI ribbons later
fslmaths $DIFDIR/pathmask.nii.gz -dilD $DIFDIR/pathmask_dilated.nii.gz
