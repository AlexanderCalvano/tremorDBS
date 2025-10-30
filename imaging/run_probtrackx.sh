#!/bin/bash

subdir=$1

mkdir $subdir/diffusion/stats

# find all VAT files and loop over them
find "$subdir/VAT" -type f -name "*contact*bin.nii.gz" | while read -r vat_file; do

    # extract folder name of VAT 
    vat_folder=$(basename "$(dirname "$vat_file")")

    # Append VAT path to temporary seeds file
    cp $subdir/seeds/seeds.txt $subdir/seeds/seeds_tmp.txt
    echo "$vat_file" >> "$subdir/seeds/seeds_tmp.txt"
    
    # run probtrackx
    probtrackx2_gpu \
       -s $subdir/diffusion.bedpostX/merged \
       -m $subdir/diffusion/nodif_brain_mask.nii.gz \
       -x $subdir/seeds/seeds_tmp.txt \
       --dir=$subdir/diffusion/stats/$vat_folder \
       --network \
       --opd \
       --ompl \
       --waypoints=$subdir/diffusion/pathmask.nii.gz \
       --avoid=$subdir/diffusion/avoid_mask.nii.gz \
       --modeuler \
       --nsamples=$2 \
       --steplength=$3 \
       --fibthresh=$4 \
       --loopcheck
done
