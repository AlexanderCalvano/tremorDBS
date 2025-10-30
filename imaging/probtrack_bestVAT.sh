#Avoidance Mask
fslmaths $BRAINMASK_DIR -binv $DIFFUSION_DIR/exclusion_mask.nii.gz

#Create Grey Matter Mask and transform into diff space
mri_vol2vol --mov $DIFFUSION_DIR/nodif.nii.gz --targ $FREESURFER_DIR/mri/ribbon.mgz --o $DIFFUSION_DIR/ribbon2diff.nii.gz --no-save-reg --reg $DIFFUSION_DIR/diff2str.dat --inv --interp nearest
mri_vol2vol --mov $DIFFUSION_DIR/nodif.nii.gz --targ $FREESURFER_DIR/mri/wmparc.mgz --o $DIFFUSION_DIR/wmparc2diff.nii.gz --no-save-reg --reg $DIFFUSION_DIR/diff2str.dat --inv --interp nearest

# Binarize WM
mri_binarize --i $DIFFUSION_DIR/aseg2diff.nii.gz --match 2 --o $DIFFUSION_DIR/left_wm2diff.nii.gz
mri_binarize --i $DIFFUSION_DIR/aseg2diff.nii.gz --match 41 --o $DIFFUSION_DIR/right_wm2diff.nii.gz
fslmaths $DIFFUSION_DIR/left_wm2diff.nii.gz -add $DIFFUSION_DIR/right_wm2diff.nii.gz $DIFFUSION_DIR/wm2diff.nii.gz

cd $DIFFUSION_DIR
# Generate GM target
for i in "ribbon" "wmparc"; do
    if [ "$i" = "ribbon" ]; then
        mri_binarize --i "${i}2diff.nii.gz" --match 3 --o left_ribbon.nii.gz
        mri_binarize --i "${i}2diff.nii.gz" --match 42 --o right_ribbon.nii.gz

        # Add left and right ribbons
        fslmaths left_ribbon.nii.gz -add right_ribbon.nii.gz "${i}2diff.nii.gz"

        # Clean up
        rm left_ribbon.nii.gz right_ribbon.nii.gz

    elif [ "$i" = "wmparc" ]; then
        # Define subcortical regions
        subcort=("49" "10" "50" "11" "51" "12" "52" "13" "53" "17" "58" "26" "16" "47" "8" "18" "54")

        # Process each subcortical region
        for n in "${subcort[@]}"; do
            mri_binarize --i "${i}2diff.nii.gz" --match "$n" --o "${n}.nii.gz"
        done

        # Combine all subcortical regions into one file
        fslmaths 49.nii.gz -add 10.nii.gz -add 50.nii.gz -add 11.nii.gz \
        -add 51.nii.gz -add 12.nii.gz -add 52.nii.gz -add 13.nii.gz \
        -add 53.nii.gz -add 17.nii.gz -add 58.nii.gz -add 26.nii.gz \
        -add 16.nii.gz -add 47.nii.gz -add 8.nii.gz -add 18.nii.gz \
        -add 54.nii.gz subcorticalgm2diff.nii.gz

        # Clean up temporary files
        for trash in "${subcort[@]}"; do
            rm "${trash}.nii.gz"
        done
    fi
done

# Dilate ribbon into WM, multiply with WM, add residue to original ribbon,
# add subcortical GM, and binarize
#fslmaths ribbon2diff.nii.gz -dilD -mul wm2diff.nii.gz -add ribbon2diff.nii.gz \
#-add subcorticalgm2diff.nii.gz -bin target2diff.nii.gz

#besseeeeeer
fslmaths ribbon2diff.nii.gz -add subcorticalgm2diff.nii.gz -bin target2diff.nii.gz

#Run Fibertracking right VAT
    probtrackx2 \
    -s /Users/alexandercalvano/Downloads/tremorDBS_imaging/subject4/fsl.bedpostX/merged \
    -m $BRAINMASK_DIR \
    -x $DIFFUSION_DIR/target2diff.nii.gz --dir=$SUBJECT_DIR/probtrack_wholebrain \
    --targetmasks=/Users/alexandercalvano/Downloads/tremorDBS_imaging/subject4/fsl/VAT2wholebrain.txt \
    --modeuler \
    --avoid=$DIFFUSION_DIR/exclusion_mask.nii.gz \
    --opd \
    --os2t --s2tastext \
    --loopcheck
