#!/bin/bash

# Script to calculate VTA size statistics per hemisphere
# Uses the complete dataset from ordered_tremor.csv (all VATs with tremor scores)

# Input file
ORDERED_TREMOR="/Users/alexandercalvano/Downloads/ordered_tremor.csv"

# VTA root directory
VTA_ROOT="/Users/alexandercalvano/Downloads/BACKUP_tremorleaddbs_before2diff/derivatives/leaddbs"

# Output directory
OUTPUT_DIR="/Users/alexandercalvano/CascadeProjects/VTA_analysis/vta_size_stats_complete"
mkdir -p "$OUTPUT_DIR"

# Output files
LEFT_VOLUMES="$OUTPUT_DIR/left_vta_volumes.csv"
RIGHT_VOLUMES="$OUTPUT_DIR/right_vta_volumes.csv"
STATS_SUMMARY="$OUTPUT_DIR/vta_size_statistics.csv"

echo "Calculating VTA volumes for all VATs with tremor scores..."
echo "========================================================"

# Check if input file exists
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

# Initialize output files
echo "subject,side,contact,amp,volume_mm3" > "$LEFT_VOLUMES"
echo "subject,side,contact,amp,volume_mm3" > "$RIGHT_VOLUMES"

# First, extract unique VTA configurations (deduplicate multiple RMS scores for same stimulation)
echo "Extracting unique VTA configurations..."
TEMP_UNIQUE=$(mktemp)

{
    # Skip header
    read header
    
    # Process each line and create unique key
    while IFS=, read -r row_id subnum contact mA cond side meanamp rms; do
        # Clean variables (remove quotes if present)
        subject_clean=$(echo "$subnum" | tr -d '"')
        side_clean=$(echo "$side" | tr -d '"')
        contact_clean=$(echo "$contact" | tr -d '"')
        amp_clean=$(echo "$mA" | tr -d '"')
        
        # Create unique key: subject,side,contact,amp
        echo "$subject_clean,$side_clean,$contact_clean,$amp_clean"
    done
} < "$ORDERED_TREMOR" | sort -u > "$TEMP_UNIQUE"

# Process the unique VTA configurations
echo "Processing unique VTA configurations..."

left_count=0
right_count=0
left_processed=0
right_processed=0
total_lines=$(wc -l < "$TEMP_UNIQUE")
current_line=0

while IFS=, read -r subject_clean side_clean contact_clean amp_clean; do
    current_line=$((current_line + 1))
    
    # Show progress every 50 lines
    if [ $((current_line % 50)) -eq 0 ]; then
        echo -ne "\rProgress: $current_line/$total_lines (Left: $left_processed, Right: $right_processed)"
    fi
    
    # Count by hemisphere
    if [ "$side_clean" = "L" ]; then
        left_count=$((left_count + 1))
    else
        right_count=$((right_count + 1))
    fi
    
    # Process VTA and get volume
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

# Clean up temp file
rm "$TEMP_UNIQUE"

echo -e "\nProcessing complete!"
echo "Left hemisphere: $left_processed volumes calculated from $left_count VATs"
echo "Right hemisphere: $right_processed volumes calculated from $right_count VATs"

# Calculate statistics using R
echo ""
echo "Calculating statistics..."

# Create R script for statistics
cat > "$OUTPUT_DIR/calc_stats.R" << 'EOF'
# Read volume data
left_file <- "/Users/alexandercalvano/CascadeProjects/VTA_analysis/vta_size_stats_complete/left_vta_volumes.csv"
right_file <- "/Users/alexandercalvano/CascadeProjects/VTA_analysis/vta_size_stats_complete/right_vta_volumes.csv"

# Check if files exist and have data
if (file.exists(left_file)) {
  left_data <- read.csv(left_file)
  if (nrow(left_data) == 0) {
    cat("Warning: No left hemisphere volume data found\n")
    left_volumes <- numeric(0)
  } else {
    left_volumes <- left_data$volume_mm3
  }
} else {
  cat("Error: Left volume file not found\n")
  left_volumes <- numeric(0)
}

if (file.exists(right_file)) {
  right_data <- read.csv(right_file)
  if (nrow(right_data) == 0) {
    cat("Warning: No right hemisphere volume data found\n")
    right_volumes <- numeric(0)
  } else {
    right_volumes <- right_data$volume_mm3
  }
} else {
  cat("Error: Right volume file not found\n")
  right_volumes <- numeric(0)
}

# Calculate statistics function
calc_stats <- function(volumes, hemisphere) {
  if (length(volumes) == 0) {
    return(data.frame(
      Hemisphere = hemisphere,
      N = 0,
      Mean_mm3 = NA,
      Median_mm3 = NA,
      Q1_mm3 = NA,
      Q3_mm3 = NA,
      IQR_mm3 = NA,
      Min_mm3 = NA,
      Max_mm3 = NA
    ))
  }
  
  q1 <- quantile(volumes, 0.25, na.rm = TRUE)
  q3 <- quantile(volumes, 0.75, na.rm = TRUE)
  
  data.frame(
    Hemisphere = hemisphere,
    N = length(volumes),
    Mean_mm3 = round(mean(volumes, na.rm = TRUE), 2),
    Median_mm3 = round(median(volumes, na.rm = TRUE), 2),
    Q1_mm3 = round(q1, 2),
    Q3_mm3 = round(q3, 2),
    IQR_mm3 = round(q3 - q1, 2),
    Min_mm3 = round(min(volumes, na.rm = TRUE), 2),
    Max_mm3 = round(max(volumes, na.rm = TRUE), 2)
  )
}

# Calculate statistics
left_stats <- calc_stats(left_volumes, "Left")
right_stats <- calc_stats(right_volumes, "Right")

# Combine results
results <- rbind(left_stats, right_stats)

# Print results
cat("VTA Volume Statistics (Complete Dataset):\n")
cat("========================================\n\n")

for (i in 1:nrow(results)) {
  cat(sprintf("%s Hemisphere:\n", results$Hemisphere[i]))
  cat(sprintf("  Sample size: %d VTAs\n", results$N[i]))
  if (!is.na(results$Mean_mm3[i])) {
    cat(sprintf("  Mean: %.2f mm³\n", results$Mean_mm3[i]))
    cat(sprintf("  Median: %.2f mm³\n", results$Median_mm3[i]))
    cat(sprintf("  Q1 (25th percentile): %.2f mm³\n", results$Q1_mm3[i]))
    cat(sprintf("  Q3 (75th percentile): %.2f mm³\n", results$Q3_mm3[i]))
    cat(sprintf("  IQR: %.2f mm³\n", results$IQR_mm3[i]))
    cat(sprintf("  Min: %.2f mm³\n", results$Min_mm3[i]))
    cat(sprintf("  Max: %.2f mm³\n", results$Max_mm3[i]))
  } else {
    cat("  No valid volume data found\n")
  }
  cat("\n")
}

# Save results
write.csv(results, "/Users/alexandercalvano/CascadeProjects/VTA_analysis/vta_size_stats_complete/vta_size_statistics.csv", 
          row.names = FALSE)

cat("Results saved to: vta_size_statistics.csv\n")
EOF

# Run R script
Rscript "$OUTPUT_DIR/calc_stats.R"

# Clean up
rm "$OUTPUT_DIR/calc_stats.R"

echo ""
echo "Analysis complete!"
echo "Output files:"
echo "  Left volumes: $LEFT_VOLUMES"
echo "  Right volumes: $RIGHT_VOLUMES"
echo "  Statistics: $STATS_SUMMARY"
