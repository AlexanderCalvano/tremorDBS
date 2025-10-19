#!/usr/bin/env Rscript

library(tidyverse)

# Path settings
base_dir <- "/path/to/analysis"
output_dir <- file.path(base_dir, "miv_correlation")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Read data files
miv_L <- read.csv(file.path(base_dir, "miv_results/miv_L.csv"))
miv_R <- read.csv(file.path(base_dir, "miv_results/miv_R.csv"))
tremor_left <- read.csv(file.path(base_dir, "tremor_left.csv"))
tremor_right <- read.csv(file.path(base_dir, "tremor_right.csv"))

# Ensure consistent data types
miv_L$subnum <- as.character(miv_L$subnum)
miv_L$contact <- as.character(miv_L$contact)
miv_L$amp <- as.numeric(miv_L$amp)

miv_R$subnum <- as.character(miv_R$subnum)
miv_R$contact <- as.character(miv_R$contact)
miv_R$amp <- as.numeric(miv_R$amp)

tremor_left$subnum <- as.character(tremor_left$subnum)
tremor_left$contact <- as.character(tremor_left$contact)
tremor_left$amp <- as.numeric(tremor_left$amp)

tremor_right$subnum <- as.character(tremor_right$subnum)
tremor_right$contact <- as.character(tremor_right$contact)
tremor_right$amp <- as.numeric(tremor_right$amp)

# Average multiple RMS values for the same VAT
cat("Preprocessing tremor data...\n")
tremor_left_avg <- tremor_left %>%
  group_by(subnum, side, contact, amp) %>%
  summarise(RMS = mean(RMS), .groups = "drop")

tremor_right_avg <- tremor_right %>%
  group_by(subnum, side, contact, amp) %>%
  summarise(RMS = mean(RMS), .groups = "drop")

miv_L <- miv_L %>% mutate(key = paste(subnum, contact, amp, sep = "_"))
miv_R <- miv_R %>% mutate(key = paste(subnum, contact, amp, sep = "_"))
tremor_left_avg <- tremor_left_avg %>% mutate(key = paste(subnum, contact, amp, sep = "_"))
tremor_right_avg <- tremor_right_avg %>% mutate(key = paste(subnum, contact, amp, sep = "_"))

# Match MIV with tremor scores
left_data <- inner_join(miv_L, tremor_left_avg, by = "key", suffix = c("_miv", "_tremor"))
right_data <- inner_join(miv_R, tremor_right_avg, by = "key", suffix = c("_miv", "_tremor"))
all_data <- bind_rows(left_data, right_data)

# Log-transform RMS values
left_data$log_RMS <- log(left_data$RMS)
right_data$log_RMS <- log(right_data$RMS)
all_data$log_RMS <- log(all_data$RMS)

cat(sprintf("Left hemisphere: %d matched VAT-tremor pairs\n", nrow(left_data)))
cat(sprintf("Right hemisphere: %d matched VAT-tremor pairs\n", nrow(right_data)))
cat(sprintf("Total: %d matched pairs\n", nrow(all_data)))

# Calculate Pearson correlation with log-transformed RMS
calculate_correlation <- function(data, label) {
  if (nrow(data) < 5) {
    cat(sprintf("Insufficient data for %s\n", label))
    return(NULL)
  }
  
  corr_test <- cor.test(data$mean_effectiveness_intensity, data$log_RMS, method = "pearson")
  
  cat(sprintf("%s: r = %.4f, p = %.4g, n = %d\n", 
              label, corr_test$estimate, corr_test$p.value, nrow(data)))
  
  return(list(
    hemisphere = label,
    n = nrow(data),
    r = corr_test$estimate,
    p = corr_test$p.value
  ))
}

# Calculate Pearson correlations with log-transformed RMS
cat("\nPearson correlations (MIV vs log-transformed RMS):\n")
left_corr <- calculate_correlation(left_data, "Left hemisphere")
right_corr <- calculate_correlation(right_data, "Right hemisphere")
all_corr <- calculate_correlation(all_data, "Combined hemispheres")

# Save correlation results
cat("\nSaving results...\n")
results <- data.frame(
  hemisphere = c(left_corr$hemisphere, right_corr$hemisphere, all_corr$hemisphere),
  n = c(left_corr$n, right_corr$n, all_corr$n),
  pearson_r = c(left_corr$r, right_corr$r, all_corr$r),
  p_value = c(left_corr$p, right_corr$p, all_corr$p)
)

write.csv(results, file.path(output_dir, "miv_correlation_results.csv"), row.names = FALSE)
cat(sprintf("Results saved to: %s\n", file.path(output_dir, "miv_correlation_results.csv")))

cat("\ndone.\n")
