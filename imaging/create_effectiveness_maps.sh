#!/bin/bash
# create z-score normalised effectiveness maps

vta_root="path/to/leaddbs/derivatives"
output_dir="path/to/output"
tremor_left_stn="path/to/tremor_leftSTN_final.csv"
tremor_right_stn="path/to/tremor_rightSTN_final.csv"
ref_mni="path/to/MNI_1.nii"

mkdir -p "$output_dir"

calculate_subject_stats() {
    local csv_file=$1
    local stats_file=$2
    
    Rscript --vanilla - "$csv_file" "$stats_file" << 'EOF'
args <- commandArgs(trailingOnly = TRUE)
data <- read.csv(args[1])
stats <- aggregate(RMS ~ subnum, data = data, FUN = function(x) c(mean = mean(x), sd = sd(x)))
result <- data.frame(subnum = stats$subnum, mean_rms = stats$RMS[, "mean"], sd_rms = stats$RMS[, "sd"])
result$sd_rms[is.na(result$sd_rms) | result$sd_rms == 0] <- 0.001
write.csv(result, args[2], row.names = FALSE, quote = FALSE)
EOF
}

# get z-score weight
get_zscore_weight() {
    local subnum=$(echo "$1" | tr -d '"')
    local rms=$(echo "$2" | tr -d '"')
    local stats_file=$3
    
    [[ ! "$rms" =~ ^[0-9.]+$ ]] && echo "0" && return
    
    local stats_line=$(grep "^${subnum}," "$stats_file")
    [ -z "$stats_line" ] && echo "0" && return
    
    local mean_rms=$(echo "$stats_line" | cut -d',' -f2)
    local sd_rms=$(echo "$stats_line" | cut -d',' -f3)
    
    echo "scale=10; -1 * ($rms - $mean_rms) / $sd_rms" | bc
}

process_vtas() {
    local stats_left="${output_dir}/stats_left.csv"
    local stats_right="${output_dir}/stats_right.csv"
    
    calculate_subject_stats "$tremor_left_stn" "$stats_left"
    calculate_subject_stats "$tremor_right_stn" "$stats_right"
    
    local weighted_sum_left="${output_dir}/weighted_sum_left.nii.gz"
    local nonweighted_sum_left="${output_dir}/nonweighted_sum_left.nii.gz"
    local weighted_sum_right="${output_dir}/weighted_sum_right.nii.gz"
    local nonweighted_sum_right="${output_dir}/nonweighted_sum_right.nii.gz"
    
    fslmaths "$ref_mni" -mul 0 "$weighted_sum_left"
    fslmaths "$ref_mni" -mul 0 "$nonweighted_sum_left"
    fslmaths "$ref_mni" -mul 0 "$weighted_sum_right"
    fslmaths "$ref_mni" -mul 0 "$nonweighted_sum_right"
    
    # left
    { read header; while IFS=, read -r subnum side contact amp rms; do
        subnum=$(echo "$subnum" | tr -d '"')
        contact=$(echo "$contact" | tr -d '"')
        amp=$(echo "$amp" | tr -d '"')
        weight=$(get_zscore_weight "$subnum" "$rms" "$stats_left")
        contact_formatted=$(printf "%02d" "$contact")
        vta_file="${vta_root}/sub-subject${subnum}/stimulations/MNI152NLin2009bAsym/L_contact-${contact_formatted}_amp-${amp}mA/sub-subject${subnum}_sim-binary_model-simbio_hemi-L_MNI_1mm.nii.gz"
        
        if [ -f "$vta_file" ]; then
            temp_weighted=$(mktemp).nii.gz
            fslmaths "$vta_file" -mul "$weight" "$temp_weighted"
            fslmaths "$weighted_sum_left" -add "$temp_weighted" "$weighted_sum_left"
            fslmaths "$nonweighted_sum_left" -add "$vta_file" "$nonweighted_sum_left"
            rm "$temp_weighted"
        fi
    done; } < "$tremor_left_stn"
    
    # right
    { read header; while IFS=, read -r subnum side contact amp rms; do
        subnum=$(echo "$subnum" | tr -d '"')
        contact=$(echo "$contact" | tr -d '"')
        amp=$(echo "$amp" | tr -d '"')
        weight=$(get_zscore_weight "$subnum" "$rms" "$stats_right")
        contact_remapped=$((contact - 8))
        contact_formatted=$(printf "%02d" "$contact_remapped")
        vta_file="${vta_root}/sub-subject${subnum}/stimulations/MNI152NLin2009bAsym/R_contact-${contact_formatted}_amp-${amp}mA/sub-subject${subnum}_sim-binary_model-simbio_hemi-R_MNI_1mm.nii.gz"
        
        if [ -f "$vta_file" ]; then
            temp_weighted=$(mktemp).nii.gz
            fslmaths "$vta_file" -mul "$weight" "$temp_weighted"
            fslmaths "$weighted_sum_right" -add "$temp_weighted" "$weighted_sum_right"
            fslmaths "$nonweighted_sum_right" -add "$vta_file" "$nonweighted_sum_right"
            rm "$temp_weighted"
        fi
    done; } < "$tremor_right_stn"
    
    local mask_left="${output_dir}/mask_left.nii.gz"
    local mask_right="${output_dir}/mask_right.nii.gz"
    
    fslmaths "$nonweighted_sum_left" -bin "$mask_left"
    fslmaths "$nonweighted_sum_right" -bin "$mask_right"
    
    fslmaths "$weighted_sum_left" -div "$nonweighted_sum_left" -mas "$mask_left" "${output_dir}/effectiveness_map_left.nii.gz"
    fslmaths "$weighted_sum_right" -div "$nonweighted_sum_right" -mas "$mask_right" "${output_dir}/effectiveness_map_right.nii.gz"
    fslmaths "${output_dir}/effectiveness_map_left.nii.gz" -add "${output_dir}/effectiveness_map_right.nii.gz" "${output_dir}/effectiveness_map_combined.nii.gz"
}

# run
process_vtas
