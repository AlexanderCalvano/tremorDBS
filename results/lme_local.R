#!/usr/bin/env Rscript
# LME analysis: MIV (z-score full map) predicting log(RMS)
# generates in-sample and LOSO out-of-sample predictions

library(lme4)
library(lmerTest)
library(dplyr)

# load and merge data
miv_left <- read.csv("path/to/miv_leftSTN_fullmap_zscore.csv")
miv_right <- read.csv("path/to/miv_rightSTN_fullmap_zscore.csv")
tremor_left <- read.csv("path/to/tremor_leftSTN_final.csv")
tremor_right <- read.csv("path/to/tremor_rightSTN_final.csv")

names(miv_left) <- trimws(names(miv_left))
names(miv_right) <- trimws(names(miv_right))
names(tremor_left) <- trimws(names(tremor_left))
names(tremor_right) <- trimws(names(tremor_right))

left_data <- merge(miv_left, tremor_left, by = c("subnum", "side", "contact", "amp"))
right_data <- merge(miv_right, tremor_right, by = c("subnum", "side", "contact", "amp"))

left_data$log_RMS <- log(left_data$RMS + 0.001)
right_data$log_RMS <- log(right_data$RMS + 0.001)

# R-squared calculation for LME
calc_r2 <- function(model) {
  var_fixed <- var(predict(model, re.form = NA))
  var_random <- as.numeric(VarCorr(model)[[1]])
  var_resid <- sigma(model)^2
  R2m <- var_fixed / (var_fixed + var_random + var_resid)
  R2c <- (var_fixed + var_random) / (var_fixed + var_random + var_resid)
  return(list(R2m = R2m, R2c = R2c))
}

# LME analysis function
run_lme_analysis <- function(data, hemisphere) {
  model <- lmer(log_RMS ~ MIV + (1 | subnum), data = data)
  coefs <- summary(model)$coefficients
  beta <- coefs["MIV", "Estimate"]
  se <- coefs["MIV", "Std. Error"]
  t_val <- coefs["MIV", "t value"]
  p_val <- coefs["MIV", "Pr(>|t|)"]
  r2 <- calc_r2(model)
  n <- nrow(data)
  k <- 1
  adj_r2 <- 1 - (1 - r2$R2m) * (n - 1) / (n - k - 1)
  data$Predicted_log_RMS_Local <- predict(model, re.form = NA)
  data$Predicted_log_RMS_Full <- fitted(model)
  return(list(
    model = model,
    data = data,
    stats = data.frame(
      hemisphere = hemisphere,
      beta = beta,
      se = se,
      t_value = t_val,
      p_value = p_val,
      R2_marginal = r2$R2m,
      R2_conditional = r2$R2c,
      R2_adjusted = adj_r2,
      n = n,
      n_subjects = length(unique(data$subnum))
    )
  ))
}

# Run LME for both hemispheres
left_results <- run_lme_analysis(left_data, "Left")
right_results <- run_lme_analysis(right_data, "Right")

# LOSO (leave-one-subject-out) predictions
run_loso <- function(data, hemisphere) {
  subjects <- unique(data$subnum)
  data$LOSO_Predicted_log_RMS_Local <- NA
  for (i in seq_along(subjects)) {
    held_out <- subjects[i]
    train_data <- data[data$subnum != held_out, ]
    test_data <- data[data$subnum == held_out, ]
    model_loso <- lmer(log_RMS ~ MIV + (1 | subnum), data = train_data)
    pred <- predict(model_loso, newdata = test_data, re.form = NA, allow.new.levels = TRUE)
    data$LOSO_Predicted_log_RMS_Local[data$subnum == held_out] <- pred
  }
  return(data)
}

left_data_loso <- run_loso(left_results$data, "Left")
right_data_loso <- run_loso(right_results$data, "Right")

# Export results
left_insample <- left_data_loso %>%
  select(subnum, side, contact, amp, MIV, RMS, log_RMS, 
         Predicted_log_RMS_Local, Predicted_log_RMS_Full, LOSO_Predicted_log_RMS_Local) %>%
  rename(SubjectID = subnum, True_log_RMS = log_RMS)

right_insample <- right_data_loso %>%
  select(subnum, side, contact, amp, MIV, RMS, log_RMS, 
         Predicted_log_RMS_Local, Predicted_log_RMS_Full, LOSO_Predicted_log_RMS_Local) %>%
  rename(SubjectID = subnum, True_log_RMS = log_RMS)

write.csv(left_insample, "path/to/left_stn_miv_predictions.csv", row.names = FALSE)
write.csv(right_insample, "path/to/right_stn_miv_predictions.csv", row.names = FALSE)

stats_summary <- rbind(left_results$stats, right_results$stats)
write.csv(stats_summary, "path/to/lme_miv_zscore_stats.csv", row.names = FALSE)
