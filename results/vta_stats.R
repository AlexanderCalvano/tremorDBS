#!/usr/bin/env Rscript

# Calculate VTA volume statistics per hemisphere

# Path settings
args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 3) {
  left_file <- args[1]
  right_file <- args[2]
  output_file <- args[3]
} else {
  left_file <- "/path/to/left_vta_volumes.csv"
  right_file <- "/path/to/right_vta_volumes.csv"
  output_file <- "/path/to/vta_size_statistics.csv"
}

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
cat("------VTA Statistics----:\n")

for (i in seq_len(nrow(results))) {
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
write.csv(results, output_file, row.names = FALSE)

cat(sprintf("Results saved to: %s\n", output_file))
