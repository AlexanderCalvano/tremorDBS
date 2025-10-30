#!/bin/bash

# make freesurfer (for mri_binarize) accessible
export PATH=/opt/freesurfer/bin:$PATH
export FREESURFER_HOME=/opt/freesurfer

work_dir=$1
diffusion_dir=$work_dir/diffusion
seeds_file="/home/armink/retro_tremor_dbs/imaging/desikan_seed_list.txt"

mkdir $work_dir/seeds

#Generating Targets...
cat $seeds_file | awk -v aparc=$diffusion_dir/aseg2diff.nii.gz -v output=$work_dir/seeds '{print "mri_binarize --i "aparc" --match "$1" --o "output"/"$2".nii.gz"}' | bash
cat $seeds_file | awk -v output=$work_dir/seeds '{print output"/"$2".nii.gz"}' > $work_dir/seeds/seeds.txt

