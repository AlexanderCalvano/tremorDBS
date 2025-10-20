#!/bin/bash

# Path configurations
VTA_ROOT="/path/to/derivatives/leaddbs"
OUTPUT_DIR="/path/to/output/effectiveness_map"
TREMOR_LEFT="/path/to/tremor_left.csv"
TREMOR_RIGHT="/path/to/tremor_right.csv"
REF_MNI="/path/to/MNI.nii"

mkdir -p "$OUTPUT_DIR"

# Worse tremor means high RMS, so we use 1/RMS as the weight
normalize_rms() {
    local rms=$1
    
    rms=$(echo "$rms" | tr -d '"')
    
    if [[ ! "$rms" =~ ^[0-9.]+$ ]]; then
        echo "0"
        return
    fi
    
    # Calculating tremor "weight" 
    local weight=$(echo "scale=10; 1 / $rms" | bc)
    
    echo "$weight"
}

# Function to process VTAs and create the effectiveness maps
# -Right tremor scores (tremor_right.csv) are used for left hemisphere VATs
# -Left tremor scores (tremor_left.csv) are used for right hemisphere VATs
process_vats() {
    local right_tremor_csv=$1  # For left hemisphere VATs
    local left_tremor_csv=$2   # For right hemisphere VATs
    local output_dir=$3
    
    # Create tmp files for weighted and non-weighted sums
    local weighted_sum_left="${output_dir}/weighted_sum_left.nii.gz"
    local nonweighted_sum_left="${output_dir}/nonweighted_sum_left.nii.gz"
    local weighted_sum_right="${output_dir}/weighted_sum_right.nii.gz"
    local nonweighted_sum_right="${output_dir}/nonweighted_sum_right.nii.gz"
    local effectiveness_map_left="${output_dir}/effectiveness_map_left.nii.gz"
    local effectiveness_map_right="${output_dir}/effectiveness_map_right.nii.gz"
    local effectiveness_map_combined="${output_dir}/effectiveness_map_combined.nii.gz"
    
    # Create empty images for the summation step
    fslmaths "$REF_MNI" -mul 0 "$weighted_sum_left"
    fslmaths "$REF_MNI" -mul 0 "$nonweighted_sum_left"
    fslmaths "$REF_MNI" -mul 0 "$weighted_sum_right"
    fslmaths "$REF_MNI" -mul 0 "$nonweighted_sum_right"
    
    # process left VATs with right tremor scores
    echo "Processing left hemisphere VATs..."
    
    {
        read header
        while IFS=, read -r subject side contact amp rms; do
            weight=$(normalize_rms "$rms")
            [ "$weight" = "0" ] && continue
            
            subject=$(echo "$subject" | tr -d '"')
            contact=$(echo "$contact" | tr -d '"')
            amp=$(echo "$amp" | tr -d '"')
            
            # Format contact with leading zero if single digit
            [[ "$contact" =~ ^[0-9]$ ]] && contact_fmt="0${contact}" || contact_fmt="${contact}"
            
            # Search for VAT file 
            vat_file=$(find "${VTA_ROOT}/sub-subject${subject}/stimulations/MNI152NLin2009bAsym" \
                -name "L_contact-*${contact}*_amp-${amp}mA" -type d 2>/dev/null | head -1)
            
            if [ -n "$vat_file" ]; then
                vat_file="${vat_file}/sub-subject${subject}_sim-binary_model-simbio_hemi-L_MNI.nii.gz"
                
                if [ -f "$vat_file" ]; then
                    temp_weighted=$(mktemp).nii.gz
                    fslmaths "$vat_file" -mul "$weight" "$temp_weighted"
                    fslmaths "$weighted_sum_left" -add "$temp_weighted" "$weighted_sum_left"
                    fslmaths "$nonweighted_sum_left" -add "$vat_file" "$nonweighted_sum_left"
                    rm "$temp_weighted"
                fi
            fi
        done
    } < "$right_tremor_csv"
    
    # Process right VATs with left tremor scores
    echo "Processing right hemisphere VATs..."
    
    {
        read header
        while IFS=, read -r subject side contact amp rms; do
            weight=$(normalize_rms "$rms")
            [ "$weight" = "0" ] && continue
            
            subject=$(echo "$subject" | tr -d '"')
            contact=$(echo "$contact" | tr -d '"')
            amp=$(echo "$amp" | tr -d '"')
            
            # Format contact with leading zero if single digit
            [[ "$contact" =~ ^[0-9]$ ]] && contact_fmt="0${contact}" || contact_fmt="${contact}"
            
            # Search for VAT file 
            vat_file=$(find "${VTA_ROOT}/sub-subject${subject}/stimulations/MNI152NLin2009bAsym" \
                -name "R_contact-*${contact}*_amp-${amp}mA" -type d 2>/dev/null | head -1)
            
            if [ -n "$vat_file" ]; then
                vat_file="${vat_file}/sub-subject${subject}_sim-binary_model-simbio_hemi-R_MNI.nii.gz"
                
                if [ -f "$vat_file" ]; then
                    temp_weighted=$(mktemp).nii.gz
                    fslmaths "$vat_file" -mul "$weight" "$temp_weighted"
                    fslmaths "$weighted_sum_right" -add "$temp_weighted" "$weighted_sum_right"
                    fslmaths "$nonweighted_sum_right" -add "$vat_file" "$nonweighted_sum_right"
                    rm "$temp_weighted"
                fi
            fi
        done
    } < "$left_tremor_csv"
    
    # Calculate effectiveness maps (weighted sum / non-weighted sum)
    echo "Calculating effectiveness maps..."
    
    local mask_left="${output_dir}/mask_left.nii.gz"
    local mask_right="${output_dir}/mask_right.nii.gz"
    
    fslmaths "$nonweighted_sum_left" -bin "$mask_left"
    fslmaths "$nonweighted_sum_right" -bin "$mask_right"
    fslmaths "$weighted_sum_left" -div "$nonweighted_sum_left" -mas "$mask_left" "$effectiveness_map_left"
    fslmaths "$weighted_sum_right" -div "$nonweighted_sum_right" -mas "$mask_right" "$effectiveness_map_right"
    fslmaths "$effectiveness_map_left" -add "$effectiveness_map_right" "$effectiveness_map_combined"
    
    echo "donnnne...file: $output_dir"
}

# Create temporary directory for preprocessed files
TEMP_DIR=$(mktemp -d)

echo "preprocessing tremor data..."
PREPROCESSED_LEFT="${TEMP_DIR}/tremor_left_averaged.csv"
PREPROCESSED_RIGHT="${TEMP_DIR}/tremor_right_averaged.csv"
preprocess_tremor_csv "$TREMOR_LEFT" "$PREPROCESSED_LEFT"
preprocess_tremor_csv "$TREMOR_RIGHT" "$PREPROCESSED_RIGHT"

echo "creating effectiveness map..."
process_vats "$PREPROCESSED_RIGHT" "$PREPROCESSED_LEFT" "$OUTPUT_DIR"

rm -rf "$TEMP_DIR"
echo "maps created."