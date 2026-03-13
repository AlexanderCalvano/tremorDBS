#!/usr/bin/env Rscript
# Supplementary figure 2: In-sample comparison of network vs local model
# two panels showing pooled data (left + right hemispheres combined):
#   A) Network : true vs predicted log(RMS) from PLS regression
#   B) Local: true vs predicted log(RMS) from LME fixed effects

library(ggplot2)
library(dplyr)
library(cowplot)
library(lme4)
library(lmerTest)

# Load Network (PLS) Predictions
pls_left <- read.csv("path/to/pls_regression_model_predictions_left.csv")
pls_right <- read.csv("path/to/pls_regression_model_predictions_right.csv")

pls_pooled <- data.frame(
  true = c(pls_left$true, pls_right$true),
  pred = c(pls_left$pred_pls, pls_right$pred_pls)
)

# Load Local (LME) Predictions
miv_left <- read.csv("path/to/left_stn_miv_predictions.csv")
miv_right <- read.csv("path/to/right_stn_miv_predictions.csv")

lme_pooled <- data.frame(
  true = c(miv_left$True_log_RMS, miv_right$True_log_RMS),
  pred = c(miv_left$Predicted_log_RMS_Local, miv_right$Predicted_log_RMS_Local)
)

# Calculate Correlations
cor_net <- cor.test(pls_pooled$true, pls_pooled$pred, method = "pearson")
cor_loc <- cor.test(lme_pooled$true, lme_pooled$pred, method = "pearson")

# Plotting Function
create_scatter_plot <- function(data, x_var, y_var, x_label, y_label, title_text, 
                                cor_result, x_limits, x_breaks_vec, y_limits, y_breaks_vec) {
  r_val <- cor_result$estimate
  r2_val <- r_val^2
  cor_text <- sprintf("r = %.2f, R² = %.2f", r_val, r2_val)
  
  p <- ggplot(data, aes(x = !!sym(x_var), y = !!sym(y_var))) +
    geom_point(color = "grey60", alpha = 0.4, size = 1.5) +
    geom_smooth(method = "lm", se = TRUE, color = "black", fill = "lightgrey", alpha = 0.5, linewidth = 0.5) +
    labs(x = x_label, y = y_label, title = title_text) +
    scale_x_continuous(breaks = x_breaks_vec, limits = x_limits) +
    scale_y_continuous(breaks = y_breaks_vec, limits = y_limits) +
    annotate("text", x = -Inf, y = Inf, label = cor_text, 
             hjust = -0.1, vjust = 1.3, size = 4) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 14, face = "bold", hjust = 0.5),
      axis.title.x = element_text(size = 12, color = "black"),
      axis.title.y = element_text(size = 12, color = "black"),
      axis.text = element_text(size = 11, color = "black"),
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      panel.background = element_rect(fill = "white", color = NA),
      legend.position = "none",
      plot.margin = margin(10, 15, 10, 10),
      axis.line = element_line(color = "#808080", linewidth = 0.6),
      axis.ticks = element_line(color = "#808080", linewidth = 0.6),
      axis.ticks.length = unit(0.2, "cm"),
      plot.title.position = "plot"
    )
  
  return(p)
}

# Calculate Shared Axis Ranges
all_x <- c(pls_pooled$true, lme_pooled$true)
x_limits <- range(all_x, na.rm = TRUE)
x_breaks_vec <- round(seq(x_limits[1], x_limits[2], length.out = 5), 1)
all_y <- c(pls_pooled$pred, lme_pooled$pred)
y_limits <- range(all_y, na.rm = TRUE)
y_breaks_vec <- round(seq(y_limits[1], y_limits[2], length.out = 5), 1)

# Create Plots
net_plot <- create_scatter_plot(
  pls_pooled, "true", "pred", "True log(RMS)", "Predicted log(RMS)",
  "A) Network Model", cor_net, x_limits, x_breaks_vec, y_limits, y_breaks_vec
)

loc_plot <- create_scatter_plot(
  lme_pooled, "true", "pred", "True log(RMS)", "Predicted log(RMS)",
  "B) Local Model", cor_loc, x_limits, x_breaks_vec, y_limits, y_breaks_vec
)

# Combine Panels

combined_plot <- plot_grid(net_plot, loc_plot, ncol = 2, align = "h", axis = "tb")

main_title <- ggdraw() + 
  draw_label("In-Sample Predictions (Pooled)", fontface = "bold", size = 16, x = 0.5, y = 0.5)

final_plot <- plot_grid(main_title, combined_plot, ncol = 1, rel_heights = c(0.1, 1))

# Save Figures
ggsave("path/to/Supplementary_Figure_2.pdf", 
       final_plot, width = 10, height = 5, device = cairo_pdf, dpi = 300, bg = "white")

ggsave("path/to/Supplementary_Figure_2.png", 
       final_plot, width = 10, height = 5, dpi = 300, bg = "white")
