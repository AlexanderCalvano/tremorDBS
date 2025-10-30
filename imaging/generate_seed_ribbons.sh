#!/bin/bash
# Generate ribbonized seeds for fiber tracking in order to avoid
# direct connections across gyri. Also generate a negative mask whose
# voxels are avoided in probtrackx


subdir=$1
wmfile=$subdir/diffusion/pathmask_dilated.nii.gz
tmpfile=$subdir/tmp.nii.gz
avoidfile=$subdir/diffusion/avoid_mask.nii.gz

# generate inverted brain mask as basis for avoid mask
fslmaths $subdir/diffusion/nodif_brain_mask.nii.gz -binv \
	 $subdir/diffusion/avoid_mask.nii.gz


# generate seed ribbons for cortex and add difference to avoid mask
for seedfile in "$subdir"/seeds/ctx* "$subdir"/seeds/*Cerebellum*; do
  cp $seedfile $tmpfile
  fslmaths $seedfile -mul $wmfile $seedfile
  fslmaths $tmpfile -sub $seedfile -add $avoidfile $avoidfile
  rm $tmpfile
done


