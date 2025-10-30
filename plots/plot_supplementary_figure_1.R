#!/usr/bin/env Rscript

# Script to create 1x2 subplot for general sweet spot intensity vs log(tremor) correlations

# Load required libraries
library(tidyverse)
library(ggplot2)
library(gridExtra)

# Set relative paths
data_dir <- './data'
output_dir <- './results'

# Read the merged files with all data
left_data <- read.csv(file.path(data_dir, 'miv_rms_vta_left.csv'))
right_data <- read.csv(file.path(data_dir, 'miv_rms_vta_right.csv'))

# Create contralateral matched datasets by matching on subnum, contact, amp
left_ssi_right_rms <- left_data %>%
  select(subnum, contact, amp, mean_sweetspot_intensity) %>%
  inner_join(
    right_data %>% select(subnum, contact, amp, RMS_avg, log_RMS),
    by = c("subnum", "contact", "amp")
  )

right_ssi_left_rms <- right_data %>%
  select(subnum, contact, amp, mean_sweetspot_intensity) %>%
  inner_join(
    left_data %>% select(subnum, contact, amp, RMS_avg, log_RMS),
    by = c("subnum", "contact", "amp")
  )

# Calculate correlations
cor_left_spearman <- cor.test(left_ssi_right_rms$mean_sweetspot_intensity, 
                               left_ssi_right_rms$log_RMS, 
                               method = "spearman")
cor_right_spearman <- cor.test(right_ssi_left_rms$mean_sweetspot_intensity, 
                                right_ssi_left_rms$log_RMS, 
                                method = "spearman")

# Extract correlation values
left_spearman_log <- cor_left_spearman$estimate
left_spearman_log_p <- cor_left_spearman$p.value
right_spearman_log <- cor_right_spearman$estimate
right_spearman_log_p <- cor_right_spearman$p.value

# Print sample sizes and correlations
cat("n (Left MIV + Right RMS):", nrow(left_ssi_right_rms), "\n")
cat("n (Right MIV + Left RMS):", nrow(right_ssi_left_rms), "\n")

# Function to format p-values
format_pvalue <- function(p) {
  if (p < 0.001) {
    return("p < 0.001")
  } else if (p < 0.01) {
    return("p < 0.01")
  } else if (p < 0.05) {
    return("p < 0.05")
  } else {
    return(paste0("p = ", round(p, 3)))
  }
}

# Set consistent axis limits for both plots
all_x_values <- c(left_ssi_right_rms$mean_sweetspot_intensity, right_ssi_left_rms$mean_sweetspot_intensity)
all_y_values <- c(left_ssi_right_rms$log_RMS, right_ssi_left_rms$log_RMS)
x_min <- 0
x_max <- 200
y_min <- -6
y_max <- 0
x_breaks <- 4
y_breaks <- 4

# Create Left MIV + Right RMS plot 
plot_left <- ggplot(left_ssi_right_rms, aes(x = mean_sweetspot_intensity, y = log_RMS)) +
  geom_point(alpha = 0.7, color = "#FFB366", size = 1.5) +
  geom_smooth(method = "lm", se = TRUE, color = "black", linewidth = 1, fill = "gray80", alpha = 0.3) +
  scale_x_continuous(breaks = c(0, 50, 100, 150, 200), limits = c(x_min, x_max)) +
  scale_y_continuous(breaks = seq(-6, 0, length.out = 5), limits = c(y_min, y_max)) +
  labs(x = "MIV (Left)", y = "Log(RMS) (Right)") +
  theme_minimal() +
  theme(
    panel.grid = element_blank(),
    axis.line = element_line(color = "black", linewidth = 1.2),
    axis.ticks = element_line(color = "black", linewidth = 1.2),
    axis.ticks.length = unit(0.3, "cm"),
    axis.text = element_text(size = 20, color = "black", family = "Helvetica"),
    axis.title = element_text(size = 20, color = "black", family = "Helvetica"),
    panel.border = element_blank(),
    plot.margin = margin(20, 20, 20, 20)
  ) +
  annotate("text", x = x_min + 10, y = y_max - 0.5, 
           label = paste0("ρ = ", round(left_spearman_log, 3)), 
           hjust = 0, size = 5)

# Create Right MIV + Left RMS plot
plot_right <- ggplot(right_ssi_left_rms, aes(x = mean_sweetspot_intensity, y = log_RMS)) +
  geom_point(alpha = 0.7, color = "#6B9BD2", size = 1.5) +
  geom_smooth(method = "lm", se = TRUE, color = "black", linewidth = 1, fill = "gray80", alpha = 0.3) +
  scale_x_continuous(breaks = c(0, 50, 100, 150, 200), limits = c(x_min, x_max)) +
  scale_y_continuous(breaks = seq(-6, 0, length.out = 5), limits = c(y_min, y_max)) +
  labs(x = "MIV (Right)", y = "Log(RMS) (Left)") +
  theme_minimal() +
  theme(
    panel.grid = element_blank(),
    axis.line = element_line(color = "black", linewidth = 1.2),
    axis.ticks = element_line(color = "black", linewidth = 1.2),
    axis.ticks.length = unit(0.3, "cm"),
    axis.text = element_text(size = 20, color = "black", family = "Helvetica"),
    axis.title = element_text(size = 20, color = "black", family = "Helvetica"),
    panel.border = element_blank(),
    plot.margin = margin(20, 20, 20, 20)
  ) +
  annotate("text", x = x_min + 10, y = y_max - 0.5, 
           label = paste0("ρ = ", round(right_spearman_log, 3)), 
           hjust = 0, size = 5)

# Combine plots in 1x2 layout
combined_plot_1x2 <- grid.arrange(
  plot_left, plot_right,
  nrow = 1, ncol = 2
)

# Save 1x2 combined plot as PDF
ggsave(file.path(output_dir, "general_SSI_log_1x2_contralateral_combined.pdf"), combined_plot_1x2, 
       width = 12, height = 6, device = "pdf")

# Print results
cat("\nLeft:  ρ =", round(left_spearman_log, 3), ", p =", format.pval(left_spearman_log_p), "\n")
cat("Right: ρ =", round(right_spearman_log, 3), ", p =", format.pval(right_spearman_log_p), "\n")
cat("\nPlots saved to:", output_dir, "\n")
# Display the 1x2 plot
print(combined_plot_1x2)
