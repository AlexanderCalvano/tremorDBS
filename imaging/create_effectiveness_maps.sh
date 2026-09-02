#!/bin/bash

#this script creates the effectivness maps for each patient using a leave-one-patient-out approach

cd "$(dirname "$0")"

# Paths
data_dir="../data"
vta_root="${data_dir}/leaddbs"                        
output_dir="${data_dir}/sweet_spot_zscore"            
tremor_left_stn="${data_dir}/tremor_leftSTN.csv"
tremor_right_stn="${data_dir}/tremor_rightSTN.csv"
ref_mni="${data_dir}/MNI_1.nii"                       # MNI reference template

mkdir -p "$output_dir"

# Function to pre-calculate subject-level statistics
calculate_subject_stats() {
    local csv_file=$1
    local stats_file=$2
    local excluded_subject=$3
    
    # Call R script to calculate per-subject mean and SD
    Rscript --vanilla - "$csv_file" "$stats_file" "$excluded_subject" << 'EOF'
args <- commandArgs(trailingOnly = TRUE)
csv_file <- args[1]
stats_file <- args[2]
excluded_subject <- if(length(args) >= 3 && args[3] != "") args[3] else NULL

# Read data
data <- read.csv(csv_file)

# Exclude subject if specified
if (!is.null(excluded_subject)) {
    data <- data[data$subnum != as.numeric(excluded_subject), ]
}

# Calculate per-subject mean and SD
stats <- aggregate(RMS ~ subnum, data = data, FUN = function(x) {
    c(mean = mean(x), sd = sd(x))
})

# Flatten the result
result <- data.frame(
    subnum = stats$subnum,
    mean_rms = stats$RMS[, "mean"],
    sd_rms = stats$RMS[, "sd"]
)

# Handle subjects with SD = 0 or NA (set to small value to avoid division by zero)
result$sd_rms[is.na(result$sd_rms) | result$sd_rms == 0] <- 0.001

# Write to file
write.csv(result, stats_file, row.names = FALSE, quote = FALSE)
EOF
}

# Function to get Z-score weight for a given subject and RMS value
get_zscore_weight() {
    local subnum=$1
    local rms=$2
    local stats_file=$3
    
    rms=$(echo "$rms" | tr -d '"')
    subnum=$(echo "$subnum" | tr -d '"')
    
    if [[ ! "$rms" =~ ^[0-9.]+$ ]]; then
        echo "0"
        return
    fi
    
    local stats_line=$(grep "^${subnum}," "$stats_file")
    
    if [ -z "$stats_line" ]; then
        echo "0"
        return
    fi
    
    local mean_rms=$(echo "$stats_line" | cut -d',' -f2)
    local sd_rms=$(echo "$stats_line" | cut -d',' -f3)
    
    # Calculate Z-score for each patient and inverse it
    local zscore=$(echo "scale=10; ($rms - $mean_rms) / $sd_rms" | bc)
    local weight=$(echo "scale=10; -1 * $zscore" | bc)
}

# Function to process VTAs and create sweet spot maps
process_vats() {
    local left_stn_csv=$1   
    local right_stn_csv=$2
    local output_dir=$3
    local excluded_subject=$4
    
    # Create temporary files
    local stats_left="${output_dir}/stats_left.csv"
    local stats_right="${output_dir}/stats_right.csv"
    
    # Calculate subject-level stats (excluding the LOSO subject if specified)
    calculate_subject_stats "$left_stn_csv" "$stats_left" "$excluded_subject"
    calculate_subject_stats "$right_stn_csv" "$stats_right" "$excluded_subject"
    
    
    # Create temporary files for weighted and non-weighted sums
    local weighted_sum_left="${output_dir}/weighted_sum_left.nii.gz"
    local nonweighted_sum_left="${output_dir}/nonweighted_sum_left.nii.gz"
    local weighted_sum_right="${output_dir}/weighted_sum_right.nii.gz"
    local nonweighted_sum_right="${output_dir}/nonweighted_sum_right.nii.gz"
    local sweet_spot_left="${output_dir}/sweet_spot_left.nii.gz"
    local sweet_spot_right="${output_dir}/sweet_spot_right.nii.gz"
    local sweet_spot_combined="${output_dir}/sweet_spot_combined.nii.gz"
    
    # Create empty images for summation
    fslmaths "$ref_mni" -mul 0 "$weighted_sum_left"
    fslmaths "$ref_mni" -mul 0 "$nonweighted_sum_left"
    fslmaths "$ref_mni" -mul 0 "$weighted_sum_right"
    fslmaths "$ref_mni" -mul 0 "$nonweighted_sum_right"
    
    # ------ Process left VTAs ------
    { 
        read header
        
        while IFS=, read -r subnum side contact amp rms; d
            subnum=$(echo "$subnum" | tr -d '"')
            contact=$(echo "$contact" | tr -d '"')
            amp=$(echo "$amp" | tr -d '"')
            
            # Skip if this is the excluded subject
            if [ -n "$excluded_subject" ] && [ "$subnum" = "$excluded_subject" ]; then
                continue
            fi
            
            # Calculate Z-score weight
            weight=$(get_zscore_weight "$subnum" "$rms" "$stats_left")
            
            contact_formatted=$(printf "%02d" "$contact")
            
            # get the VTA from the lead dbs folder
            vat_file="${vta_root}/sub-subject${subnum}/stimulations/MNI152NLin2009bAsym/L_contact-${contact_formatted}_amp-${amp}mA/sub-subject${subnum}_sim-binary_model-simbio_hemi-L_MNI_1mm.nii.gz"
            
            if [ -f "$vat_file" ]; then
                vta_min=$(fslstats "$vat_file" -R | awk '{print $1}')
                if (( $(echo "$vta_min < -1" | bc -l) )); then
                    echo "VTA might be corrupted, please check $vat_file (min=$vta_min)" >&2
                    continue
                fi
                
                
                # Create temporary weighted VTA
                temp_weighted=$(mktemp).nii.gz
                fslmaths "$vat_file" -mul "$weight" "$temp_weighted"
                
                # Add to weighted sum
                fslmaths "$weighted_sum_left" -add "$temp_weighted" "$weighted_sum_left"
                
                # Add to non-weighted sum
                fslmaths "$nonweighted_sum_left" -add "$vat_file" "$nonweighted_sum_left"
                
                # Clean everything
                rm "$temp_weighted"
            else
            fi
        done
    } < "$left_stn_csv"
    
     # ------ Process right VTAs ------
    {
        read header
        
        while IFS=, read -r subnum side contact amp rms; do
            # Remove quotes
            subnum=$(echo "$subnum" | tr -d '"')
            contact=$(echo "$contact" | tr -d '"')
            amp=$(echo "$amp" | tr -d '"')
            
            # Skip if this is the excluded subject
            if [ -n "$excluded_subject" ] && [ "$subnum" = "$excluded_subject" ]; then
                continue
            fi
            
            # Calculate Z-score weight
            weight=$(get_zscore_weight "$subnum" "$rms" "$stats_right")
            
            # Remap contact 9-16 to 1-8
            contact_remapped=$((contact - 8))
            contact_formatted=$(printf "%02d" "$contact_remapped")
            
            vat_file="${vta_root}/sub-subject${subnum}/stimulations/MNI152NLin2009bAsym/R_contact-${contact_formatted}_amp-${amp}mA/sub-subject${subnum}_sim-binary_model-simbio_hemi-R_MNI_1mm.nii.gz"
            
            if [ -f "$vat_file" ]; then
                vta_min=$(fslstats "$vat_file" -R | awk '{print $1}')
                if (( $(echo "$vta_min < -1" | bc -l) )); then
                    echo "warning: skipping corrupted vta: $vat_file (min=$vta_min)" >&2
                    continue
                fi
                
                # Create temporary weighted VTA
                temp_weighted=$(mktemp).nii.gz
                fslmaths "$vat_file" -mul "$weight" "$temp_weighted"
                
                # Add to weighted sum
                fslmaths "$weighted_sum_right" -add "$temp_weighted" "$weighted_sum_right"
                
                # Add to non-weighted sum
                fslmaths "$nonweighted_sum_right" -add "$vat_file" "$nonweighted_sum_right"
                
                # Clean up
                rm "$temp_weighted"
            else
                echo "warning: vat file not found: $vat_file" >&2
            fi
        done
    } < "$right_stn_csv"
    
    #---------------------------------------------------------------
    # Calculate sweet spots (weighted sum / non-weighted sum)
    #---------------------------------------------------------------
    
    # Create masks where non-weighted sum > 0
    local mask_left="${output_dir}/mask_left.nii.gz"
    local mask_right="${output_dir}/mask_right.nii.gz"
    
    fslmaths "$nonweighted_sum_left" -bin "$mask_left"
    fslmaths "$nonweighted_sum_right" -bin "$mask_right"
    
    # Calculate sweet spots within the masks
    fslmaths "$weighted_sum_left" -div "$nonweighted_sum_left" -mas "$mask_left" "$sweet_spot_left"
    fslmaths "$weighted_sum_right" -div "$nonweighted_sum_right" -mas "$mask_right" "$sweet_spot_right"
    
    # Create a combined sweet spot image
    fslmaths "$sweet_spot_left" -add "$sweet_spot_right" "$sweet_spot_combined"
}


# Get unique subject IDs
temp_subjects=$(mktemp)
tail -n +2 "$tremor_left_stn" | cut -d, -f1 | tr -d '"' > "$temp_subjects"
tail -n +2 "$tremor_right_stn" | cut -d, -f1 | tr -d '"' >> "$temp_subjects"
subjects=$(sort -u "$temp_subjects")
rm "$temp_subjects"


# For each subject, perform leave-one-out analysis
for subject in $subjects; do
    if grep -q "subject_${subject}:done" "$progress_file"; then
        continue
    fi

    loso_dir="${output_dir}/LOSO_sub-subject${subject}"
    mkdir -p "$loso_dir"
    
    process_vats "$tremor_left_stn" "$tremor_right_stn" "$loso_dir" "$subject"
    
    # Mark this subject as finished for the next round
    echo "subject_${subject}:done" >> "$progress_file"
done

