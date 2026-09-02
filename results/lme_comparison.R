## ------------------------------------------------------------
## Model comparison and LME
## ------------------------------------------------------------

# prepare everything
results_dir <- "../results"
matched <- read.csv(file.path(results_dir, "matched_data_frame.csv"), stringsAsFactors = FALSE)
matched$sub <- as.factor(matched$sub)

predictor_names <- paste0("X", 1:82)
ncomp <- 6

lme_side <- function(dat, side_label) {
  if (side_label == "both")  dfm <- dat
  if (side_label == "left")  dfm <- dat[dat$contraside_char == "L", ]
  if (side_label == "right") dfm <- dat[dat$contraside_char == "R", ]

  X     <- as.matrix(dfm[, predictor_names])
  y_log <- log(dfm$rms)                        # LME uses log(RMS)
  y_dem <- y_log - ave(y_log, dfm$sub, FUN = mean)  # demeaned only for PLS fit 
  piv   <- dfm$MIV_peak
  sub   <- dfm$sub
  ok    <- is.finite(y_log) & apply(X, 1, function(z) all(is.finite(z))) & is.finite(piv)
  X <- X[ok, , drop = FALSE]; y_log <- y_log[ok]; y_dem <- y_dem[ok]
  piv <- piv[ok]; sub <- sub[ok]

  seed_side <- 123 + which(c("both","left","right") == side_label)
  set.seed(seed_side)

  # Fit PLS on demeaned outcome to obtain component scores, then we use
  # those scores as fixed effects in the LME
  m_pls  <- pls::plsr(y_dem ~ X, ncomp = ncomp, validation = "none")
  scores <- as.matrix(pls::scores(m_pls)[, 1:ncomp])
  colnames(scores) <- paste0("PC", 1:ncomp)

  d_net <- data.frame(y = y_log, sub = sub, scores)
  form_net <- as.formula(paste("y ~", paste0("PC", 1:ncomp, collapse = " + "), "+ (1|sub)"))
  m_lme_net <- lmer(form_net, data = d_net, REML = FALSE)

  d_loc <- data.frame(y = y_log, piv = piv, sub = sub)
  m_lme_loc <- lmer(y ~ piv + (1|sub), data = d_loc, REML = FALSE)

  vc_net <- lme4::VarCorr(m_lme_net)
  var_sub <- attr(vc_net$sub, "stddev")^2
  var_res <- attr(vc_net, "sc")^2
  icc <- var_sub / (var_sub + var_res)

  metrics <- data.frame(
    side = side_label, n = length(y_log),
    approach = c("PLS_network_LME", "PIV_local_LME"),
    marginal_R2    = c(r2_net["R2m"], r2_loc["R2m"]),
    conditional_R2 = c(r2_net["R2c"], r2_loc["R2c"]),
    AIC = c(AIC(m_lme_net), AIC(m_lme_loc)),
    BIC = c(BIC(m_lme_net), BIC(m_lme_loc)),
    ICC = c(icc, NA)
  )
  metrics$dAIC_vs_local <- metrics$AIC - metrics$AIC[metrics$approach == "PIV_local_LME"]
  metrics$dBIC_vs_local <- metrics$BIC - metrics$BIC[metrics$approach == "PIV_local_LME"]

  list(metrics = metrics,
       coef_net = summary(m_lme_net)$coefficients,
       coef_loc = summary(m_lme_loc)$coefficients)
}

r_both  <- lme_side(matched, "both")
r_left  <- lme_side(matched, "left")
r_right <- lme_side(matched, "right")

metrics <- rbind(r_both$metrics, r_left$metrics, r_right$metrics)

write.csv(metrics, file.path(results_dir, "_lme_comparison.csv"), row.names = FALSE)