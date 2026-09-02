## ------------------------------------------------------------
## This script uses PIV as the sole predictor for tremor outcomes
## We conduct three levels of validation:
##     - Fitted (in-sample) r
##     - 10-fold CV r
##     - LOSO r
## ------------------------------------------------------------

# prepare everything
results_dir <- "../results"
matched <- read.csv(file.path(results_dir, "matched_data_frame.csv"), stringsAsFactors = FALSE)
matched$sub <- as.factor(matched$sub)

r2p <- function(o, p) 1 - sum((o - p)^2) / sum((o - mean(o))^2)

local_side <- function(dat, side_label) {
  if (side_label == "both")  dfm <- dat
  if (side_label == "left")  dfm <- dat[dat$contraside_char == "L", ]
  if (side_label == "right") dfm <- dat[dat$contraside_char == "R", ]
  y_raw <- log(dfm$rms)
  y     <- y_raw - ave(y_raw, dfm$sub, FUN = mean)
  mpeak <- dfm$MIV_peak - ave(dfm$MIV_peak, dfm$sub, FUN = mean)
  sub   <- dfm$sub
  ok    <- is.finite(y) & is.finite(mpeak)
  y <- y[ok]; mpeak <- mpeak[ok]; sub <- sub[ok]

  seed_side <- 123 + which(c("both","left","right") == side_label)

  m <- lm(y ~ mpeak); fit_pred <- as.numeric(predict(m))

  set.seed(seed_side)
  fold <- sample(rep(1:10, length.out = length(y)))
  cv_pred <- rep(NA_real_, length(y))
  for (k in 1:10) {
    te <- fold == k; tr <- !te
    mk <- lm(y[tr] ~ mpeak[tr])
    cv_pred[te] <- coef(mk)[1] + coef(mk)[2] * mpeak[te]
  }

  loso_pred <- rep(NA_real_, length(y))
  for (s in unique(sub)) {
    te <- sub == s; tr <- !te
    ms <- lm(y[tr] ~ mpeak[tr])
    loso_pred[te] <- coef(ms)[1] + coef(ms)[2] * mpeak[te]
  }

  data.frame(
    side = side_label, n = length(y),
    level = c("fitted", "10CV", "LOSO"),
    r     = c(cor(y, fit_pred),  cor(y, cv_pred),  cor(y, loso_pred)),
    R2    = c(r2p(y, fit_pred),  r2p(y, cv_pred),  r2p(y, loso_pred)),
    RMSE  = c(sqrt(mean((y-fit_pred)^2)), sqrt(mean((y-cv_pred)^2)), sqrt(mean((y-loso_pred)^2)))
  )
}

metrics <- rbind(
  local_side(matched, "both"),
  local_side(matched, "left"),
  local_side(matched, "right")
)
write.csv(metrics, file.path(results_dir, "_local_metrics.csv"), row.names = FALSE)
