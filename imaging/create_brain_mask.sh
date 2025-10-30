#!/bin/tcsh -f

if ($#argv == 0) then
  echo "usage: create_brain_mask <diffusion_dir> <freesurfer_dir>"
  exit
endif

set diffusion_dir = $1
set freesurfer_dir = $2

setenv SUBJECTS_DIR `dirname $freesurfer_dir`

if (! -e $diffusion_dir/nodif.nii.gz) then 
  fslroi $diffusion_dir/data.nii.gz $diffusion_dir/nodif.nii.gz 0 1
endif

if (! -e $diffusion_dir/diff2str.dat) then 
  bbregister --s `basename $freesurfer_dir` --mov $diffusion_dir/nodif.nii.gz --reg $diffusion_dir/diff2str.dat --fslmat $diffusion_dir/diffusion/diff2str.mat --dti
endif

if (! -e $diffusion_dir/aseg2diff.nii.gz) then 
  mri_vol2vol --mov $diffusion_dir/nodif.nii.gz --targ $freesurfer_dir/mri/aparc+aseg.mgz --o $diffusion_dir/aseg2diff.nii.gz --no-save-reg --reg $diffusion_dir/diff2str.dat --inv --interp nearest
endif

mkdir /tmp/brain_wo_ventricles

fslmaths $diffusion_dir/aseg2diff.nii.gz -thr 4 -uthr 4 /tmp/brain_wo_ventricles/aseg-seg4.nii.gz
fslmaths $diffusion_dir/aseg2diff.nii.gz -thr 5 -uthr 5 /tmp/brain_wo_ventricles/aseg-seg5.nii.gz
fslmaths $diffusion_dir/aseg2diff.nii.gz -thr 43 -uthr 43 /tmp/brain_wo_ventricles/aseg-seg43.nii.gz
fslmaths $diffusion_dir/aseg2diff.nii.gz -thr 44 -uthr 44 /tmp/brain_wo_ventricles/aseg-seg44.nii.gz
fslmaths $diffusion_dir/aseg2diff.nii.gz -thr 14 -uthr 14 /tmp/brain_wo_ventricles/aseg-seg14.nii.gz
fslmaths $diffusion_dir/aseg2diff.nii.gz -thr 15 -uthr 15 /tmp/brain_wo_ventricles/aseg-seg15.nii.gz
fslmaths $diffusion_dir/aseg2diff.nii.gz -thr 24 -uthr 24 /tmp/brain_wo_ventricles/aseg-seg24.nii.gz
fslmaths $diffusion_dir/aseg2diff.nii.gz -thr 30 -uthr 30 /tmp/brain_wo_ventricles/aseg-seg30.nii.gz
fslmaths $diffusion_dir/aseg2diff.nii.gz -thr 62 -uthr 62 /tmp/brain_wo_ventricles/aseg-seg62.nii.gz
fslmaths $diffusion_dir/aseg2diff.nii.gz -thr 31 -uthr 31 /tmp/brain_wo_ventricles/aseg-seg31.nii.gz
fslmaths $diffusion_dir/aseg2diff.nii.gz -thr 63 -uthr 63 /tmp/brain_wo_ventricles/aseg-seg63.nii.gz
fslmaths $diffusion_dir/aseg2diff.nii.gz -thr 72 -uthr 72 /tmp/brain_wo_ventricles/aseg-seg72.nii.gz

fslmaths $diffusion_dir/aseg2diff.nii.gz \
    -sub /tmp/brain_wo_ventricles/aseg-seg4.nii.gz  \
    -sub /tmp/brain_wo_ventricles/aseg-seg5.nii.gz  \
    -sub /tmp/brain_wo_ventricles/aseg-seg43.nii.gz \
    -sub /tmp/brain_wo_ventricles/aseg-seg44.nii.gz \
    -sub /tmp/brain_wo_ventricles/aseg-seg14.nii.gz \
    -sub /tmp/brain_wo_ventricles/aseg-seg15.nii.gz \
    -sub /tmp/brain_wo_ventricles/aseg-seg24.nii.gz \
    -sub /tmp/brain_wo_ventricles/aseg-seg30.nii.gz \
    -sub /tmp/brain_wo_ventricles/aseg-seg62.nii.gz \
    -sub /tmp/brain_wo_ventricles/aseg-seg31.nii.gz \
    -sub /tmp/brain_wo_ventricles/aseg-seg63.nii.gz \
    -sub /tmp/brain_wo_ventricles/aseg-seg72.nii.gz \
    /tmp/brain_wo_ventricles/brain.nii.gz

fslmaths /tmp/brain_wo_ventricles/brain.nii.gz -bin $diffusion_dir/nodif_brain_mask.nii.gz

rm -rf /tmp/brain_wo_ventricles
