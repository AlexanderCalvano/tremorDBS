## ------------------------------------------------------------
## This script uses PLS to maximise shared covariance
## between RMS and network connectivity.
## We conduct three levels of validation:
##     - Fitted (in-sample) r
##     - 10-fold CV r
##     - LOSO r
##     - Within-subject permutation p on 10-fold CV
## ------------------------------------------------------------

# prepare everything
results_dir <- "../results"
matched <- read.csv(file.path(results_dir, "matched_data_frame.csv"), stringsAsFactors = FALSE)
matched$sub <- as.factor(matched$sub)

predictor_names <- paste0("X", 1:82)
ncomp  <- 6
n_perm <- 1000

r2p <- function(o, p) 1 - sum((o - p)^2) / sum((o - mean(o))^2)

pls_side <- function(dat, side_label) {
  if (side_label == "both")  dfm <- dat
  if (side_label == "left")  dfm <- dat[dat$contraside_char == "L", ]
  if (side_label == "right") dfm <- dat[dat$contraside_char == "R", ]
  X <- as.matrix(dfm[, predictor_names])
  y_raw <- log(dfm$rms)
  y     <- y_raw - ave(y_raw, dfm$sub, FUN = mean)          # within-subject demean
  sub   <- dfm$sub
  ok    <- is.finite(y) & apply(X, 1, function(z) all(is.finite(z)))
  X <- X[ok, , drop = FALSE]; y <- y[ok]; sub <- sub[ok]

  seed_side <- 123 + which(c("both","left","right") == side_label)

  # PLS with the 10-fold CV
  set.seed(seed_side)
  m <- pls::plsr(y ~ X, ncomp = ncomp, validation = "CV")
  fit_pred <- drop(fitted(m)[, 1, ncomp])
  cv_pred  <- drop(m$validation$pred[, 1, ncomp])

  # Leave-one-patient-out loop, which refits on all subjects except s, to predict s
  loso_pred <- rep(NA_real_, length(y))
  for (s in unique(sub)) {
    te <- sub == s; tr <- !te
    m_s <- pls::plsr(y[tr] ~ X[tr, , drop = FALSE], ncomp = ncomp, validation = "none")
    loso_pred[te] <- as.numeric(predict(m_s, newdata = X[te, , drop = FALSE])[, 1, ncomp])
  }

  # Within-subject permutation on CV r
  set.seed(seed_side)
  perm_stat <- numeric(n_perm)
  for (i in seq_len(n_perm)) {
    y_perm <- y
    for (s in unique(sub)) {
      idx <- which(sub == s); y_perm[idx] <- sample(y_perm[idx])
    }
    m_p <- pls::plsr(y_perm ~ X, ncomp = ncomp, validation = "CV", segments = 10)
    perm_stat[i] <- cor(y_perm, drop(m_p$validation$pred[, 1, ncomp]))
  }
  cv_r <- cor(y, cv_pred)
  p_perm <- (sum(abs(perm_stat) >= abs(cv_r)) + 1) / (n_perm + 1)

  list(
    metrics = data.frame(
      side = side_label, n = length(y),
      level = c("fitted", "10CV", "LOSO"),
      r     = c(cor(y, fit_pred),  cor(y, cv_pred),  cor(y, loso_pred)),
      R2    = c(r2p(y, fit_pred),  r2p(y, cv_pred),  r2p(y, loso_pred)),
      RMSE  = c(sqrt(mean((y-fit_pred)^2)), sqrt(mean((y-cv_pred)^2)), sqrt(mean((y-loso_pred)^2)))
    ),
    perm = data.frame(side = side_label, n_perm = n_perm, cv_r = cv_r, perm_p = p_perm)
  )
}

r_both  <- pls_side(matched, "both")
r_left  <- pls_side(matched, "left")
r_right <- pls_side(matched, "right")

metrics <- rbind(r_both$metrics, r_left$metrics, r_right$metrics)
perm    <- rbind(r_both$perm,    r_left$perm,    r_right$perm)

write.csv(metrics, file.path(results_dir, "pls_metrics_results.csv"), row.names = FALSE)
write.csv(perm,    file.path(results_dir, "permutation_results.csv"), row.names = FALSE)
