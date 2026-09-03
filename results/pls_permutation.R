
## ------------------------------------------------------------
## predictive performance of the network (pls) model
## ------------------------------------------------------------

results_dir <- "../results"

ncomp           <- 6
n_perm_cv       <- 1000  
n_perm_loso     <- 1000  
predictor_names <- paste0("X", 1:82) 

matched     <- read.csv(file.path(results_dir, "matched_data_frame.csv"),
                        stringsAsFactors = FALSE)
matched$sub <- as.factor(matched$sub)

r2p <- function(o, p) 1 - sum((o - p)^2) / sum((o - mean(o))^2)

pls_side <- function(dat, side_label) {
  dfm <- switch(side_label,
                both  = dat,
                left  = dat[dat$contraside_char == "L", ],
                right = dat[dat$contraside_char == "R", ])

  x     <- as.matrix(dfm[, predictor_names])
  y_raw <- log(dfm$rms)
  y     <- y_raw - ave(y_raw, dfm$sub, FUN = mean)   # within-subject demean
  sub   <- dfm$sub

  ok  <- is.finite(y) & apply(x, 1, function(z) all(is.finite(z)))
  x   <- x[ok, , drop = FALSE]; y <- y[ok]; sub <- sub[ok]
  subj_list <- unique(sub)

  seed_side <- 123 + which(c("both", "left", "right") == side_label)

  # cv--------------
  set.seed(seed_side)
  m        <- pls::plsr(y ~ x, ncomp = ncomp, validation = "CV", segments = 10)
  fit_pred <- drop(fitted(m)[, 1, ncomp])
  cv_pred  <- drop(m$validation$pred[, 1, ncomp])

  # loso-----------
  loso_pred <- rep(NA_real_, length(y))
  for (s in subj_list) {
    te <- sub == s; tr <- !te
    m_s <- pls::plsr(y[tr] ~ x[tr, , drop = FALSE], ncomp = ncomp,
                     validation = "none")
    loso_pred[te] <- as.numeric(predict(m_s, newdata = x[te, , drop = FALSE])[, 1, ncomp])
  }

  # within-subject permutation
  set.seed(seed_side)
  perm_cv_stat <- numeric(n_perm_cv)
  for (i in seq_len(n_perm_cv)) {
    y_perm <- y
    for (s in subj_list) {
      idx <- which(sub == s); y_perm[idx] <- sample(y_perm[idx])
    }
    m_p <- pls::plsr(y_perm ~ x, ncomp = ncomp, validation = "CV", segments = 10)
    perm_cv_stat[i] <- cor(y_perm, drop(m_p$validation$pred[, 1, ncomp]))
  }
  cv_r      <- cor(y, cv_pred)
  p_perm_cv <- (sum(abs(perm_cv_stat) >= abs(cv_r)) + 1) / (n_perm_cv + 1)

  # within-subject permutation on the loso correlation
  set.seed(seed_side + 1000)
  perm_loso_stat <- numeric(n_perm_loso)
  for (i in seq_len(n_perm_loso)) {
    y_perm <- y
    for (s in subj_list) {
      idx <- which(sub == s); y_perm[idx] <- sample(y_perm[idx])
    }
    loso_pred_perm <- rep(NA_real_, length(y_perm))
    for (s in subj_list) {
      te <- sub == s; tr <- !te
      m_s <- pls::plsr(y_perm[tr] ~ x[tr, , drop = FALSE], ncomp = ncomp,
                       validation = "none")
      loso_pred_perm[te] <- as.numeric(predict(m_s, newdata = x[te, , drop = FALSE])[, 1, ncomp])
    }
    perm_loso_stat[i] <- cor(y_perm, loso_pred_perm)
  }
  loso_r      <- cor(y, loso_pred)
  p_perm_loso <- (sum(abs(perm_loso_stat) >= abs(loso_r)) + 1) / (n_perm_loso + 1)

  list(
    metrics = data.frame(
      side  = side_label,
      n     = length(y),
      level = c("fitted", "10CV", "LOSO"),
      r     = c(cor(y, fit_pred), cv_r, loso_r),
      R2    = c(r2p(y, fit_pred), r2p(y, cv_pred), r2p(y, loso_pred)),
      RMSE  = c(sqrt(mean((y - fit_pred)^2)),
                sqrt(mean((y - cv_pred)^2)),
                sqrt(mean((y - loso_pred)^2)))
    ),
    perm = data.frame(
      side   = side_label,
      level  = c("10CV", "LOSO"),
      n_perm = c(n_perm_cv, n_perm_loso),
      obs_r  = c(cv_r, loso_r),
      perm_p = c(p_perm_cv, p_perm_loso)
    )
  )
}

sides   <- c("both", "left", "right")
results <- lapply(sides, function(s) pls_side(matched, s))

metrics <- do.call(rbind, lapply(results, `[[`, "metrics"))
perm    <- do.call(rbind, lapply(results, `[[`, "perm"))

write.csv(metrics, file.path(results_dir, "_pls_metrics.csv"), row.names = FALSE)
write.csv(perm,    file.path(results_dir, "_permutation.csv"), row.names = FALSE)
