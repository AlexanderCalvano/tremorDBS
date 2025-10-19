library(ggplot2)
library(dplyr)
library(gridExtra)

# Read the matched CSV files (same as our analyses)
left_ipsilateral <- read.csv('tremor_left_vta_left_matched.csv')  # Left tremor + Left VTA (ipsilateral)
right_ipsilateral <- read.csv('tremor_right_vta_right_matched.csv')  # Right tremor + Right VTA (ipsilateral)

# Create VTA volume comparison dataset
vta_comparison <- rbind(
  data.frame(
    side = "Left",
    volume = left_ipsilateral$vta_volume_mm3
  ),
  data.frame(
    side = "Right", 
    volume = right_ipsilateral$vta_volume_mm3
  )
)

# Create RMS comparison dataset (ipsilateral - consistent with VTA)
rms_comparison <- rbind(
  data.frame(
    side = "Left",
    rms_scaled = left_ipsilateral$tremor_RMS * 1000  # Convert to ×10⁻³
  ),
  data.frame(
    side = "Right",
    rms_scaled = right_ipsilateral$tremor_RMS * 1000  # Convert to ×10⁻³
  )
)

# Define colors (same as violin_plot_rms.R)
colors <- c("Left" = "#FFB366", "Right" = "#6B9BD2")  # Pastel orange for left, navy pastel blue for right

# Create VTA volume boxplot
p_vta <- ggplot(vta_comparison, aes(x = side, y = volume, fill = side)) +
  geom_boxplot(alpha = 0.8, outlier.shape = NA, width = 0.4, linewidth = 1.2) +
  scale_fill_manual(values = colors) +
  scale_x_discrete(labels = c("Left" = "Left", "Right" = "Right"), 
                   expand = c(0.3, 0.3)) +
  scale_y_continuous(breaks = c(0, 50, 100, 150, 200), limits = c(0, 200)) +
  labs(
    x = "",
    y = "VTA Volume (mm³)",
    title = "VTA Volume"
  ) +
  theme_classic() +
  theme(
    axis.line = element_line(color = "black", linewidth = 0.8),
    axis.ticks = element_line(color = "black", linewidth = 0.8),
    axis.text = element_text(size = 11, color = "black"),
    axis.title.y = element_text(size = 12, color = "black", margin = margin(r = 10)),
    axis.title.x = element_blank(),
    plot.title = element_text(size = 12, hjust = 0.5, margin = margin(b = 10)),
    legend.position = "none",
    panel.background = element_blank(),
    plot.background = element_blank(),
    panel.grid = element_blank(),
    plot.margin = margin(10, 10, 10, 10)
  )

# Create RMS score boxplot
p_rms <- ggplot(rms_comparison, aes(x = side, y = rms_scaled, fill = side)) +
  geom_boxplot(alpha = 0.8, outlier.shape = NA, width = 0.4, linewidth = 1.2) +
  scale_fill_manual(values = colors) +
  scale_x_discrete(labels = c("Left" = "Left", "Right" = "Right"), 
                   expand = c(0.3, 0.3)) +
  scale_y_continuous(limits = c(0, 40), breaks = c(0, 10, 20, 30, 40)) +
  labs(
    x = "",
    y = "RMS Score (×10⁻³)",
    title = "RMS Score"
  ) +
  theme_classic() +
  theme(
    axis.line = element_line(color = "black", linewidth = 0.8),
    axis.ticks = element_line(color = "black", linewidth = 0.8),
    axis.text = element_text(size = 11, color = "black"),
    axis.title.y = element_text(size = 12, color = "black", margin = margin(r = 10)),
    axis.title.x = element_blank(),
    plot.title = element_text(size = 12, hjust = 0.5, margin = margin(b = 10)),
    legend.position = "none",
    panel.background = element_blank(),
    plot.background = element_blank(),
    panel.grid = element_blank(),
    plot.margin = margin(10, 10, 10, 10)
  )

# Combine plots side by side
combined_plot <- grid.arrange(p_vta, p_rms, ncol = 2)

# Save the combined plot
ggsave('dual_boxplot_vta_rms.png', 
       plot = combined_plot, width = 10, height = 5, dpi = 300)

# Print summary statistics
cat("=== VTA VOLUME SUMMARY ===\n")
vta_stats <- vta_comparison %>% 
  group_by(side) %>% 
  summarise(
    count = n(),
    mean = mean(volume, na.rm = TRUE),
    median = median(volume, na.rm = TRUE),
    Q1 = quantile(volume, 0.25, na.rm = TRUE),
    Q3 = quantile(volume, 0.75, na.rm = TRUE),
    IQR = Q3 - Q1
  )
print(vta_stats)

cat("\n=== RMS SCORE SUMMARY (×10⁻³) ===\n")
rms_stats <- rms_comparison %>% 
  group_by(side) %>% 
  summarise(
    count = n(),
    mean = mean(rms_scaled, na.rm = TRUE),
    median = median(rms_scaled, na.rm = TRUE),
    Q1 = quantile(rms_scaled, 0.25, na.rm = TRUE),
    Q3 = quantile(rms_scaled, 0.75, na.rm = TRUE),
    IQR = Q3 - Q1
  )
print(rms_stats)

# Perform Wilcoxon tests
cat("\n=== STATISTICAL TESTS ===\n")

# VTA volume test
cat("VTA Volume Wilcoxon Test:\n")
left_vta <- vta_comparison$volume[vta_comparison$side == "Left"]
right_vta <- vta_comparison$volume[vta_comparison$side == "Right"]
wilcox_vta <- wilcox.test(left_vta, right_vta, alternative = "two.sided")
print(wilcox_vta)

# Effect size for VTA
n1_vta <- length(left_vta)
n2_vta <- length(right_vta)
total_n_vta <- n1_vta + n2_vta
z_score_vta <- qnorm(wilcox_vta$p.value/2)
effect_size_vta <- abs(z_score_vta) / sqrt(total_n_vta)
cat(sprintf("VTA Effect size (r): %.4f\n", effect_size_vta))

# RMS score test
cat("\nRMS Score Wilcoxon Test:\n")
left_rms <- rms_comparison$rms_scaled[rms_comparison$side == "Left"]
right_rms <- rms_comparison$rms_scaled[rms_comparison$side == "Right"]
wilcox_rms <- wilcox.test(left_rms, right_rms, alternative = "two.sided")
print(wilcox_rms)

# Effect size for RMS
n1_rms <- length(left_rms)
n2_rms <- length(right_rms)
total_n_rms <- n1_rms + n2_rms
z_score_rms <- qnorm(wilcox_rms$p.value/2)
effect_size_rms <- abs(z_score_rms) / sqrt(total_n_rms)
cat(sprintf("RMS Effect size (r): %.4f\n", effect_size_rms))

cat("\nData points match between VTA and RMS analyses:\n")
cat("Left side:", nrow(vta_comparison[vta_comparison$side == "Left",]), "VTA,", 
    nrow(rms_comparison[rms_comparison$side == "Left",]), "RMS\n")
cat("Right side:", nrow(vta_comparison[vta_comparison$side == "Right",]), "VTA,", 
    nrow(rms_comparison[rms_comparison$side == "Right",]), "RMS\n")
