## script for the descriptives (RMS, VTA volume)

results_dir <- "../results"
matched <- read.csv(file.path(results_dir, "matched_data_frame.csv"), stringsAsFactors = FALSE)

lstn <- matched[matched$contraside_char == "L", ]
rstn <- matched[matched$contraside_char == "R", ]

# relabeling of the body side: stimulation of left STN produces right body tremor and vice versa.
lbody <- matched[matched$contraside_char == "R", ] 
rbody <- matched[matched$contraside_char == "L", ]  
lbody$logrms <- log(lbody$rms)
rbody$logrms <- log(rbody$rms)

fmt_int_iqr    <- function(x) { q <- quantile(x, c(.25,.5,.75), na.rm=TRUE); sprintf("%.0f [%.0f\u2013%.0f]", q[2], q[1], q[3]) }
fmt_median_iqr <- function(x) { q <- quantile(x, c(.25,.5,.75), na.rm=TRUE); sprintf("%.1f [%.1f\u2013%.1f]", q[2], q[1], q[3]) }

w_vol <- wilcox.test(lstn$volume_mm3, rstn$volume_mm3)
w_amp <- wilcox.test(lstn$amp,        rstn$amp)
w_rms <- wilcox.test(lbody$logrms,    rbody$logrms)

descr <- data.frame(
  metric = c("N observations (by STN)",
             "VTA volume (mm^3)",
             "Stimulation amplitude (mA)",
             "log(RMS), by body side"),
  left   = c(nrow(lstn),
             fmt_int_iqr(lstn$volume_mm3),
             fmt_median_iqr(lstn$amp),
             fmt_median_iqr(lbody$logrms)),
  right  = c(nrow(rstn),
             fmt_int_iqr(rstn$volume_mm3),
             fmt_median_iqr(rstn$amp),
             fmt_median_iqr(rbody$logrms)),
  P      = c(NA,
             format.pval(w_vol$p.value, digits=3),
             format.pval(w_amp$p.value, digits=3),
             format.pval(w_rms$p.value, digits=3))
)
write.csv(descr, file.path(results_dir, "_descriptives.csv"), row.names = FALSE)
