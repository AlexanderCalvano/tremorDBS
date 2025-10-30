#!/bin/bash

# load utility functions and paths
source utils
source paths

# define machine dependent paths
if [[ $(hostname) == "bigbrother" ]]
then
  MNI_FILE="/opt/FSL/pkgs/fsl-data_standard-2208.0-0/data/standard/MNI152_T1_1mm.nii.gz"
  IMG_DIR=/home/armink/tremorDBS/imaging_tremorDBS/
else
echo "shoot"
  MNI_FILE="/Users/alexandercalvano/fsl/pkgs/fsl-data_standard-2208.0-0/data/standard/MNI152_T1_1mm.nii.gz"
  IMG_DIR="/Users/alexandercalvano/Downloads/tremorDBS_imaging/"
fi



# define subject folder structure
SUBJECT_DIR=$IMG_DIR$1
STRUCTURAL_DIR="$SUBJECT_DIR/structural"
DIFFUSION_DIR="$SUBJECT_DIR/diffusion"
FREESURFER_DIR="$SUBJECT_DIR/freesurfer"
VAT_DIR="$SUBJECT_DIR/VAT"
BRAINMASK_FILE="$DIFFUSION_DIR/nodif_brain_mask.nii.gz"
LOGFILE=logs/$1
T1_IMAGE="$STRUCTURAL_DIR/anat_t1.nii.gz"


# abort on error and log output to file
set -e
exec > >(tee -i $LOGFILE)
exec 2>&1

# Run FreeSurfer
#source run_freesurfer.sh     

# freesurfer to struct
#source freesurfer2struct.sh

# DTI Preprocessing
#source dti_processing.sh     

# create brain mask (fuck tcsh, thank you Felix)
#tcsh "create_brain_mask.sh" "$DIFFUSION_DIR" "$FREESURFER_DIR/$1"

# Transform VATs to diffusion space with SPM coregister and resample with FLIRT
# ALEX did that seperately!

# define white matter mask and dilated version of it for fiber tracking (including brain stem!)
#bash generate_white_matter_mask.sh $SUBJECT_DIR

# get the fibertracking seeds from parcellation file and VAT
#bash extract_seeds.sh $SUBJECT_DIR

# get the fibertracking seeds from parcellation file and VAT
#bash generate_seed_ribbons.sh $SUBJECT_DIR

# Perform probabilistic fiber tracking
# bash run_probtrackx.sh $SUBJECT_DIR 30000 0.75 0.001