#!/usr/bin/env Rscript
# Network (PLS) vs local (MIV) model comparison
# calculates in-sample adjusted R² and LOSO Steiger's Z for pooled data

library(dplyr)

# Steiger's Z test for dependent correlations
steiger_z_test <- function(r_xz, r_yz, r_xy, n) {
  z_xz <- 0.5 * log((1 + r_xz) / (1 - r_xz))
  z_yz <- 0.5 * log((1 + r_yz) / (1 - r_yz))
  r_bar <- (r_xz + r_yz) / 2
  f <- (1 - r_xy) / (2 * (1 - r_bar^2))
  h <- (1 - f * r_bar^2) / (1 - r_bar^2)
  se <- sqrt((2 * (1 - r_xy) * h) / (n - 3))
  z_stat <- (z_xz - z_yz) / se
  p_value <- 2 * (1 - pnorm(abs(z_stat)))
  return(list(z = z_stat, p = p_value))
}

# Load data
pls_left <- read.csv("path/to/pls_regression_model_predictions_left.csv")
pls_right <- read.csv("path/to/pls_regression_model_predictions_right.csv")
miv_left <- read.csv("path/to/left_stn_miv_predictions.csv")
miv_right <- read.csv("path/to/right_stn_miv_predictions.csv")

# Row-based 1:1 matching
n_left <- min(nrow(pls_left), nrow(miv_left))
n_right <- min(nrow(pls_right), nrow(miv_right))
pls_left_sub <- pls_left[1:n_left, ]
pls_right_sub <- pls_right[1:n_right, ]
miv_left_sub <- miv_left[1:n_left, ]
miv_right_sub <- miv_right[1:n_right, ]

left_merged <- data.frame(
  hemisphere = "Left",
  true = pls_left_sub$true,
  pred_pls = pls_left_sub$pred_pls,
  pred_loo = pls_left_sub$pred_loo,
  SubjectID = miv_left_sub$SubjectID,
  True_log_RMS = miv_left_sub$True_log_RMS,
  Predicted_log_RMS_Local = miv_left_sub$Predicted_log_RMS_Local,
  LOSO_Predicted_log_RMS_Local = miv_left_sub$LOSO_Predicted_log_RMS_Local
)

right_merged <- data.frame(
  hemisphere = "Right",
  true = pls_right_sub$true,
  pred_pls = pls_right_sub$pred_pls,
  pred_loo = pls_right_sub$pred_loo,
  SubjectID = miv_right_sub$SubjectID,
  True_log_RMS = miv_right_sub$True_log_RMS,
  Predicted_log_RMS_Local = miv_right_sub$Predicted_log_RMS_Local,
  LOSO_Predicted_log_RMS_Local = miv_right_sub$LOSO_Predicted_log_RMS_Local
)

pooled <- rbind(left_merged, right_merged)
n_pooled <- nrow(pooled)
pooled$observed <- pooled$True_log_RMS

# In-sample statistics
r_network_insample <- cor(pooled$observed, pooled$pred_pls)
r2_network <- r_network_insample^2
k_network <- 6
adj_r2_network <- 1 - (1 - r2_network) * (n_pooled - 1) / (n_pooled - k_network - 1)

r_local_insample <- cor(pooled$observed, pooled$Predicted_log_RMS_Local)
r2_local <- r_local_insample^2
k_local <- 1
adj_r2_local <- 1 - (1 - r2_local) * (n_pooled - 1) / (n_pooled - k_local - 1)

# Out-of-sample (LOSO) statistics
r_network_loso <- cor(pooled$observed, pooled$pred_loo)
r_local_loso <- cor(pooled$observed, pooled$LOSO_Predicted_log_RMS_Local)

# Steiger's Z test
r_models <- cor(pooled$pred_loo, pooled$LOSO_Predicted_log_RMS_Local)
steiger_result <- steiger_z_test(
  r_xz = r_network_loso,
  r_yz = r_local_loso,
  r_xy = r_models,
  n = n_pooled
)

# Export results
results_df <- data.frame(
  metric = c("N", "Network_r_insample", "Network_R2", "Network_AdjR2", "Network_LOSO_r",
             "Local_r_insample", "Local_R2", "Local_AdjR2", "Local_LOSO_r",
             "Steiger_Z", "Steiger_p"),
  value = c(n_pooled, r_network_insample, r2_network, adj_r2_network, r_network_loso,
            r_local_insample, r2_local, adj_r2_local, r_local_loso,
            steiger_result$z, steiger_result$p)
)

write.csv(results_df, "path/to/network_vs_local_comparison.csv", row.names = FALSE)
