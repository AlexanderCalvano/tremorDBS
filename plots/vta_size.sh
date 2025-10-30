#!/bin/bash

# Script to calculate VTA sizes per hemisphere

# Path settings
ORDERED_TREMOR="/path/to/ordered_tremor.csv"
VTA_ROOT="/path/to/derivatives/leaddbs"
OUTPUT_DIR="/path/to/output/vta_size_stats"

mkdir -p "$OUTPUT_DIR"

# Output files
LEFT_VOLUMES="$OUTPUT_DIR/left_vta_volumes.csv"
RIGHT_VOLUMES="$OUTPUT_DIR/right_vta_volumes.csv"
STATS_SUMMARY="$OUTPUT_DIR/vta_size_statistics.csv"

if [[ ! -f "$ORDERED_TREMOR" ]]; then
    echo "Error: Input file not found: $ORDERED_TREMOR"
    exit 1
fi

# Function to process a single VTA and get volume
process_vta() {
    local subject=$1
    local side=$2
    local contact=$3
    local amp=$4
    
    # Format subject as "subject1", "subject2", etc.
    local subject_formatted="subject${subject}"
    
    # Format contact with leading zero if needed (1 -> 01, 10 -> 10)
    local contact_formatted=$(printf "%02d" "$contact")
    
    # Construct VTA file path
    vat_pattern="${VTA_ROOT}/sub-${subject_formatted}/stimulations/MNI152NLin2009bAsym/${side}_contact-${contact_formatted}_amp-${amp}mA/sub-${subject_formatted}_sim-binary_model-simbio_hemi-${side}_MNI.nii.gz"
    
    if [ -f "$vat_pattern" ]; then
        volume=$(fslstats "$vat_pattern" -V 2>/dev/null | awk '{print $2}')
        if [ -n "$volume" ] && [ "$volume" != "0.000000" ]; then
            echo "$subject,$side,$contact,$amp,$volume"
            return 0
        fi
    fi
    return 1
}

# Extract unique VTA configurations
TEMP_UNIQUE=$(mktemp)

{
    read header
    while IFS=, read -r row_id subnum contact mA cond side meanamp rms; do
        subject_clean=$(echo "$subnum" | tr -d '"')
        side_clean=$(echo "$side" | tr -d '"')
        contact_clean=$(echo "$contact" | tr -d '"')
        amp_clean=$(echo "$mA" | tr -d '"')
        echo "$subject_clean,$side_clean,$contact_clean,$amp_clean"
    done
} < "$ORDERED_TREMOR" | sort -u > "$TEMP_UNIQUE"

left_count=0
right_count=0
left_processed=0
right_processed=0
total_lines=$(wc -l < "$TEMP_UNIQUE")
current_line=0

while IFS=, read -r subject_clean side_clean contact_clean amp_clean; do
    current_line=$((current_line + 1))
    
    if [ $((current_line % 50)) -eq 0 ]; then
        echo -ne "\rProgress: $current_line/$total_lines (Left: $left_processed, Right: $right_processed)"
    fi
    
    [ "$side_clean" = "L" ] && left_count=$((left_count + 1)) || right_count=$((right_count + 1))
    if result=$(process_vta "$subject_clean" "$side_clean" "$contact_clean" "$amp_clean"); then
        if [ "$side_clean" = "L" ]; then
            echo "$result" >> "$LEFT_VOLUMES"
            left_processed=$((left_processed + 1))
        else
            echo "$result" >> "$RIGHT_VOLUMES"
            right_processed=$((right_processed + 1))
        fi
    fi
done < "$TEMP_UNIQUE"

rm "$TEMP_UNIQUE"

# Calculate statistics
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
Rscript "$SCRIPT_DIR/vta_stats.R" "$LEFT_VOLUMES" "$RIGHT_VOLUMES" "$STATS_SUMMARY"
