#!/bin/bash

# Path settings
VTA_ROOT="/path/to/derivatives/leaddbs"
EFFECTIVENESS_MAP_DIR="/path/to/effectiveness_map"
OUTPUT_DIR="/path/to/output/miv_results"
LOG_FILE="${OUTPUT_DIR}/miv_calculation.log"

mkdir -p "$OUTPUT_DIR"
echo "MIV calculation at $(date)" > "$LOG_FILE"

echo "subnum,side,contact,amp,mean_effectiveness_intensity" > "${OUTPUT_DIR}/miv_L.csv"
echo "subnum,side,contact,amp,mean_effectiveness_intensity" > "${OUTPUT_DIR}/miv_R.csv"

extract_contact_amp() {
    local vat_path="$1"
    contact=$(echo "$vat_path" | grep -o "contact-[0-9]*" | cut -d'-' -f2)
    amp=$(echo "$vat_path" | grep -o "amp-[0-9.]*mA" | sed 's/amp-//;s/mA//')
    echo "$contact,$amp"
}

calculate_intensity() {
    local subnum="$1"
    local side="$2"
    local vat_file="$3"
    
    [ "$side" = "L" ] && side_name="left" || side_name="right"
    
    effectiveness_map="${EFFECTIVENESS_MAP_DIR}/effectiveness_map_${side_name}.nii.gz"
    
    if [ ! -f "$effectiveness_map" ] || [ ! -f "$vat_file" ]; then
        echo "missing file for subject $subnum, side $side" >> "$LOG_FILE"
        return 1
    fi
    
    contact_amp=$(extract_contact_amp "$vat_file")
    contact=$(echo "$contact_amp" | cut -d',' -f1)
    amp=$(echo "$contact_amp" | cut -d',' -f2)
    
    output=$(fslstats "$effectiveness_map" -k "$vat_file" -M 2>&1)
    status=$?
    
    if [[ "$output" == *"Empty mask"* ]]; then
        mean_intensity="0"
    elif [ $status -ne 0 ] || [ -z "$output" ]; then
        echo "fslstats failed for subject $subnum, side $side" >> "$LOG_FILE"
        return 1
    else
        mean_intensity=$(echo "$output" | tr -d '[:space:]')
    fi
    
    echo "${subnum},${side},${contact},${amp},${mean_intensity}" >> "${OUTPUT_DIR}/miv_${side}.csv"
    return 0
}

echo "Finding subjects..." | tee -a "$LOG_FILE"
subjects=$(find "$VTA_ROOT" -type d -name "sub-subject*" -maxdepth 1 | sed 's/.*sub-subject//' | sort -n)

for subnum in $subjects; do
    echo "Processing subject: $subnum" | tee -a "$LOG_FILE"
    
    left_vats=$(find "$VTA_ROOT/sub-subject${subnum}/stimulations" -path "*/L_contact-*" -name "*_hemi-L_MNI.nii.gz" | sort)
    for vat_file in $left_vats; do
        calculate_intensity "$subnum" "L" "$vat_file"
    done
    
    right_vats=$(find "$VTA_ROOT/sub-subject${subnum}/stimulations" -path "*/R_contact-*" -name "*_hemi-R_MNI.nii.gz" | sort)
    for vat_file in $right_vats; do
        calculate_intensity "$subnum" "R" "$vat_file"
    done
done

echo "MIV calculation complete at $(date)" | tee -a "$LOG_FILE"
echo "Results: ${OUTPUT_DIR}/miv_L.csv and ${OUTPUT_DIR}/miv_R.csv"
