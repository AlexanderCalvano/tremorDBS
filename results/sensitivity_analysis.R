## ------------------------------------------------------------
## Running the PLS analysis on the subcohort who underwent 3T MRI (n=19)
## We then correlate the obtained PLS components with the full-sample analysis
## ------------------------------------------------------------

# prepare everything
results_dir <- "../results"
matched <- read.csv(file.path(results_dir, "matched_data_frame.csv"), stringsAsFactors = FALSE)
matched$sub <- as.factor(matched$sub)

predictor_names <- paste0("X", 1:82)
ncomp <- 6
r2p <- function(o, p) 1 - sum((o - p)^2) / sum((o - mean(o))^2)

# We exclude the 1.5T MRI subjects
exclude_1p5t <- c("10", "13", "14", "17")
matched_3t <- matched[!as.character(matched$sub) %in% exclude_1p5t, ]
fit_pls <- function(dat, side_label) {
  if (side_label == "both")  dfm <- dat
  if (side_label == "left")  dfm <- dat[dat$contraside_char == "L", ]
  if (side_label == "right") dfm <- dat[dat$contraside_char == "R", ]
  X <- as.matrix(dfm[, predictor_names])
  y_raw <- log(dfm$rms)
  y     <- y_raw - ave(y_raw, dfm$sub, FUN = mean)
  sub   <- dfm$sub
  ok    <- is.finite(y) & apply(X, 1, function(z) all(is.finite(z)))
  X <- X[ok, , drop = FALSE]; y <- y[ok]; sub <- sub[ok]

  seed_side <- 123 + which(c("both","left","right") == side_label)
  set.seed(seed_side)
  m <- pls::plsr(y ~ X, ncomp = ncomp, validation = "CV")
  fit_pred <- drop(fitted(m)[, 1, ncomp])
  cv_pred  <- drop(m$validation$pred[, 1, ncomp])

  loso_pred <- rep(NA_real_, length(y))
  for (s in unique(sub)) {
    te <- sub == s; tr <- !te
    m_s <- pls::plsr(y[tr] ~ X[tr, , drop = FALSE], ncomp = ncomp, validation = "none")
    loso_pred[te] <- as.numeric(predict(m_s, newdata = X[te, , drop = FALSE])[, 1, ncomp])
  }
  loads <- as.data.frame(as.matrix(m$loadings)[, 1:ncomp])
  colnames(loads) <- paste0("Comp", 1:ncomp)

  list(
    metrics = data.frame(
      side = side_label, n = length(y), n_sub = length(unique(sub)),
      fitted_r = cor(y, fit_pred), fitted_R2 = r2p(y, fit_pred),
      cv_r     = cor(y, cv_pred),  cv_R2     = r2p(y, cv_pred),
      loso_r   = cor(y, loso_pred),loso_R2   = r2p(y, loso_pred)
    ),
    loadings = loads
  )
}

# Fit both full and 3T MRI only subcohort per side
sides <- c("both", "left", "right")
full <- setNames(lapply(sides, function(s) fit_pls(matched,    s)), sides)
t3t  <- setNames(lapply(sides, function(s) fit_pls(matched_3t, s)), sides)

metrics <- do.call(rbind, lapply(sides, function(s) t3t[[s]]$metrics))
write.csv(metrics, file.path(results_dir, "05_sensitivity_3T_metrics.csv"), row.names = FALSE)

# Loading stability for both groups
stab <- do.call(rbind, lapply(sides, function(side_label) {
  fL <- full[[side_label]]$loadings; tL <- t3t[[side_label]]$loadings
  do.call(rbind, lapply(1:ncomp, function(c_) {
    col <- paste0("Comp", c_)
    top_f <- rownames(fL)[order(-abs(fL[[col]]))][1:7]
    top_t <- rownames(tL)[order(-abs(tL[[col]]))][1:7]
    data.frame(
      side = side_label, component = c_,
      r_raw = cor(fL[[col]], tL[[col]]),
      r_abs = cor(abs(fL[[col]]), abs(tL[[col]])),
      top7_overlap = length(intersect(top_f, top_t))
    )
  }))
}))
stab$r_raw <- round(stab$r_raw, 3); stab$r_abs <- round(stab$r_abs, 3)
write.csv(stab, file.path(results_dir, "_sensitivity_analysis.csv"), row.names = FALSE)
