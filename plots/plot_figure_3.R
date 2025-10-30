#!/usr/bin/env Rscript

#Loads data from miv_rms_vta_left.csv and miv_rms_vta_right.csv
#Merges the data and creates boxplots for VTA volume and RMS scores.
#Performs statistics for the boxplots.
#Saves the boxplots as a PDF file.

library(ggplot2)
library(dplyr)
library(gridExtra)

# Define relative paths
data_dir <- './data'
output_dir <- './publication'

# Create output directory if it doesn't exist
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# Read the CSV files
left_merged <- read.csv(file.path(data_dir, 'miv_rms_vta_left.csv'))
right_merged <- read.csv(file.path(data_dir, 'miv_rms_vta_right.csv'))

# Create VTA volume dataset
vta_comparison <- rbind(
  data.frame(
    side = "Left",
    volume = left_merged$volume_mm3
  ),
  data.frame(
    side = "Right", 
    volume = right_merged$volume_mm3
  )
)

# Create RMS dataset 
rms_comparison <- rbind(
  data.frame(
    side = "Left",
    rms_scaled = left_merged$RMS_avg * 1000  # Convert to ×10⁻³
  ),
  data.frame(
    side = "Right",
    rms_scaled = right_merged$RMS_avg * 1000  # Convert to ×10⁻³
  )
)

# styling options
colors <- c("Left" = "#FFB366", "Right" = "#6B9BD2")

# Create VTA volume boxplot
p_vta <- ggplot(vta_comparison, aes(x = side, y = volume, fill = side)) +
  geom_boxplot(alpha = 0.8, outlier.shape = NA, width = 0.4, linewidth = 1.2) +
  scale_fill_manual(values = colors) +
  scale_x_discrete(labels = c("Left" = "Left Hemisphere", "Right" = "Right Hemisphere"), 
                   expand = c(0.3, 0.3)) +
  scale_y_continuous(breaks = seq(0, 200, length.out = 5)) +
  coord_cartesian(ylim = c(0, 200)) +
  labs(
    x = "",
    y = expression("VTA Volume (mm"^3*")")
  ) +
  theme_minimal() +
  theme(
    panel.grid = element_blank(),
    axis.line = element_line(color = "black", linewidth = 1.2),
    axis.ticks = element_line(color = "black", linewidth = 1.2),
    axis.ticks.length = unit(0.3, "cm"),
    axis.text.y = element_text(size = 20, color = "black", family = "Helvetica"),
    axis.text.x = element_text(size = 13, color = "black", family = "Helvetica"),
    axis.title.y = element_text(size = 20, color = "black", family = "Helvetica"),
    axis.title.x = element_blank(),
    legend.position = "none",
    panel.border = element_blank(),
    plot.margin = margin(20, 20, 20, 20)
  )

# Create RMS score boxplot
p_rms <- ggplot(rms_comparison, aes(x = side, y = rms_scaled, fill = side)) +
  geom_boxplot(alpha = 0.8, outlier.shape = NA, width = 0.4, linewidth = 1.2) +
  scale_fill_manual(values = colors) +
  scale_x_discrete(labels = c("Left" = "Left Arm", "Right" = "Right Arm"), 
                   expand = c(0.3, 0.3)) +
  scale_y_continuous(breaks = seq(0, 60, length.out = 5)) +
  coord_cartesian(ylim = c(0, 60)) +
  labs(
    x = "",
    y = expression("RMS Score (×10"^-3*")")
  ) +
  # Add significance bar
  annotate("segment", x = 1, xend = 2, y = 52, yend = 52, linewidth = 1) +
  annotate("segment", x = 1, xend = 1, y = 52, yend = 50, linewidth = 1) +
  annotate("segment", x = 2, xend = 2, y = 52, yend = 50, linewidth = 1) +
  annotate("text", x = 1.5, y = 54.5, label = "***", size = 8) +
  theme_minimal() +
  theme(
    panel.grid = element_blank(),
    axis.line = element_line(color = "black", linewidth = 1.2),
    axis.ticks = element_line(color = "black", linewidth = 1.2),
    axis.ticks.length = unit(0.3, "cm"),
    axis.text = element_text(size = 20, color = "black", family = "Helvetica"),
    axis.title.y = element_text(size = 20, color = "black", family = "Helvetica"),
    axis.title.x = element_blank(),
    legend.position = "none",
    panel.border = element_blank(),
    plot.margin = margin(20, 20, 20, 20)
  )

# Combine plots
combined_plot <- grid.arrange(p_vta, p_rms, ncol = 2)

# Save the combined plot in PDF and png
pdf_file <- file.path(output_dir, 'dual_boxplot_vta_rms.pdf')
png_file <- file.path(output_dir, 'dual_boxplot_vta_rms.png')

ggsave(pdf_file, plot = combined_plot, width = 10, height = 5, device = "pdf")
ggsave(png_file, plot = combined_plot, width = 10, height = 5, dpi = 600)

# Print summary statistics
cat("Left hemisphere: ", nrow(left_merged), "VTAs\n")
cat("Right hemisphere:", nrow(right_merged), "VTAs\n")
cat("Total VTAs:      ", nrow(left_merged) + nrow(right_merged), "\n\n")

vta_stats <- vta_comparison %>% 
  group_by(side) %>% 
  summarise(
    count = n(),
    mean = mean(volume, na.rm = TRUE),
    median = median(volume, na.rm = TRUE),
    Q1 = quantile(volume, 0.25, na.rm = TRUE),
    Q3 = quantile(volume, 0.75, na.rm = TRUE),
    IQR = Q3 - Q1,
    min = min(volume, na.rm = TRUE),
    max = max(volume, na.rm = TRUE)
  )
print(vta_stats)

rms_stats <- rms_comparison %>% 
  group_by(side) %>% 
  summarise(
    count = n(),
    mean = mean(rms_scaled, na.rm = TRUE),
    median = median(rms_scaled, na.rm = TRUE),
    Q1 = quantile(rms_scaled, 0.25, na.rm = TRUE),
    Q3 = quantile(rms_scaled, 0.75, na.rm = TRUE),
    IQR = Q3 - Q1,
    min = min(rms_scaled, na.rm = TRUE),
    max = max(rms_scaled, na.rm = TRUE)
  )
print(rms_stats)

# Perform Wilcoxon tests

# VTA volumes
cat("VTA Volume Wilcoxon Test:\n")
left_vta <- vta_comparison$volume[vta_comparison$side == "Left"]
right_vta <- vta_comparison$volume[vta_comparison$side == "Right"]
# Remove NAs
left_vta <- left_vta[!is.na(left_vta)]
right_vta <- right_vta[!is.na(right_vta)]
wilcox_vta <- wilcox.test(left_vta, right_vta, alternative = "two.sided")
print(wilcox_vta)

# RMS score test
cat("\nRMS score Wilcoxon Test:\n")
left_rms <- rms_comparison$rms_scaled[rms_comparison$side == "Left"]
right_rms <- rms_comparison$rms_scaled[rms_comparison$side == "Right"]
# Remove NAs
left_rms <- left_rms[!is.na(left_rms)]
right_rms <- right_rms[!is.na(right_rms)]
wilcox_rms <- wilcox.test(left_rms, right_rms, alternative = "two.sided")
print(wilcox_rms)

# Save statistical results to file
stats_file <- file.path(output_dir, 'boxplot_statistics.txt')
sink(stats_file)
cat("Left hemisphere: ", nrow(left_merged), "VTAs\n")
cat("Right hemisphere:", nrow(right_merged), "VTAs\n")
cat("Total VTAs:      ", nrow(left_merged) + nrow(right_merged), "\n\n")

#Print results
print(vta_stats)
print(rms_stats)
print(wilcox_vta)
print(wilcox_rms)
sink()