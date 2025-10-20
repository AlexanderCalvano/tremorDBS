# Load required libraries
library(ggplot2)
library(gridExtra)
library(dplyr)

# Read the data
data_left <- read.csv("local_plotting/true_and_predicted_values_left.csv")
data_right <- read.csv("local_plotting/true_and_predicted_values_right.csv")

# Calculate correlation coefficients for left hemisphere
cor_pls_left <- cor(data_left$y, data_left$pred_pls)
cor_lm_left <- cor(data_left$y, data_left$pred_lm)
r2_pls_left <- cor_pls_left^2
r2_lm_left <- cor_lm_left^2

# Calculate correlation coefficients for right hemisphere
cor_pls_right <- cor(data_right$y, data_right$pred_pls)
cor_lm_right <- cor(data_right$y, data_right$pred_lm)
r2_pls_right <- cor_pls_right^2
r2_lm_right <- cor_lm_right^2

# Set consistent axis limits
all_values <- c(data_left$y, data_left$pred_pls, data_left$pred_lm,
                data_right$y, data_right$pred_pls, data_right$pred_lm)
x_min <- min(all_values)
x_max <- max(all_values)
y_min <- x_min
y_max <- x_max

# Create Left PLS scatter plot (top-left)
plot_pls_left <- ggplot(data_left, aes(x = y, y = pred_pls)) +
  geom_point(alpha = 0.7, color = "#FFB366", size = 1.5) +
  geom_smooth(method = "lm", se = TRUE, color = "black", linewidth = 1, fill = "gray80", alpha = 0.3) +
  scale_x_continuous(breaks = seq(-6, 0, 2), limits = c(-6.5, 0)) +
  scale_y_continuous(breaks = seq(-6, 0, 2), limits = c(-6.5, 0)) +
  labs(x = "", y = "") +
  theme_minimal() +
  theme(
    panel.grid = element_blank(),
    axis.line = element_line(color = "black", linewidth = 1.2),
    axis.ticks = element_line(color = "black", linewidth = 1.2),
    axis.ticks.length = unit(0.3, "cm"),
    axis.text = element_text(size = 20, color = "black"),
    panel.border = element_blank(),
    plot.margin = margin(20, 20, 20, 20)
  ) +
  annotate("text", x = -6.2, y = -0.5, 
           label = paste0("r = ", round(cor_pls_left, 3), ", R² = ", round(r2_pls_left, 3)), 
           hjust = 0, size = 4)

# Create Right PLS scatter plot (top-right)
plot_pls_right <- ggplot(data_right, aes(x = y, y = pred_pls)) +
  geom_point(alpha = 0.7, color = "#6B9BD2", size = 1.5) +
  geom_smooth(method = "lm", se = TRUE, color = "black", linewidth = 1, fill = "gray80", alpha = 0.3) +
  scale_x_continuous(breaks = seq(-6, 0, 2), limits = c(-6.5, 0)) +
  scale_y_continuous(breaks = seq(-6, 0, 2), limits = c(-6.5, 0)) +
  labs(x = "", y = "") +
  theme_minimal() +
  theme(
    panel.grid = element_blank(),
    axis.line = element_line(color = "black", linewidth = 1.2),
    axis.ticks = element_line(color = "black", linewidth = 1.2),
    axis.ticks.length = unit(0.3, "cm"),
    axis.text = element_text(size = 20, color = "black"),
    panel.border = element_blank(),
    plot.margin = margin(20, 20, 20, 20)
  ) +
  annotate("text", x = -6.2, y = -0.5, 
           label = paste0("r = ", round(cor_pls_right, 3), ", R² = ", round(r2_pls_right, 3)), 
           hjust = 0, size = 4)

# Create Left LM scatter plot (bottom-left)
plot_lm_left <- ggplot(data_left, aes(x = y, y = pred_lm)) +
  geom_point(alpha = 0.7, color = "#FFB366", size = 1.5) +
  geom_smooth(method = "lm", se = TRUE, color = "black", linewidth = 1, fill = "gray80", alpha = 0.3) +
  scale_x_continuous(breaks = seq(-6, 0, 2), limits = c(-6.5, 0)) +
  scale_y_continuous(breaks = seq(-6, 0, 2), limits = c(-6.5, 0)) +
  labs(x = "", y = "") +
  theme_minimal() +
  theme(
    panel.grid = element_blank(),
    axis.line = element_line(color = "black", linewidth = 1.2),
    axis.ticks = element_line(color = "black", linewidth = 1.2),
    axis.ticks.length = unit(0.3, "cm"),
    axis.text = element_text(size = 20, color = "black"),
    panel.border = element_blank(),
    plot.margin = margin(20, 20, 20, 20)
  ) +
  annotate("text", x = -6.2, y = -0.5, 
           label = paste0("r = ", round(cor_lm_left, 3), ", R² = ", round(r2_lm_left, 3)), 
           hjust = 0, size = 4)

# Create Right LM scatter plot (bottom-right)
plot_lm_right <- ggplot(data_right, aes(x = y, y = pred_lm)) +
  geom_point(alpha = 0.7, color = "#6B9BD2", size = 1.5) +
  geom_smooth(method = "lm", se = TRUE, color = "black", linewidth = 1, fill = "gray80", alpha = 0.3) +
  scale_x_continuous(breaks = seq(-6, 0, 2), limits = c(-6.5, 0)) +
  scale_y_continuous(breaks = seq(-6, 0, 2), limits = c(-6.5, 0)) +
  labs(x = "", y = "") +
  theme_minimal() +
  theme(
    panel.grid = element_blank(),
    axis.line = element_line(color = "black", linewidth = 1.2),
    axis.ticks = element_line(color = "black", linewidth = 1.2),
    axis.ticks.length = unit(0.3, "cm"),
    axis.text = element_text(size = 20, color = "black"),
    panel.border = element_blank(),
    plot.margin = margin(20, 20, 20, 20)
  ) +
  annotate("text", x = -6.2, y = -0.5, 
           label = paste0("r = ", round(cor_lm_right, 3), ", R² = ", round(r2_lm_right, 3)), 
           hjust = 0, size = 4)

# Combine plots in 2x2 layout
combined_plot_2x2 <- grid.arrange(
  plot_pls_left, plot_pls_right,
  plot_lm_left, plot_lm_right,
  nrow = 2, ncol = 2
)

# Save individual plots in high res resolution 
ggsave("local_plotting/true_vs_predicted_PLS_left.png", plot_pls_left, 
       width = 6, height = 6, dpi = 600)
ggsave("local_plotting/true_vs_predicted_PLS_right.png", plot_pls_right, 
       width = 6, height = 6, dpi = 600)
ggsave("local_plotting/true_vs_predicted_LM_left.png", plot_lm_left, 
       width = 6, height = 6, dpi = 600)
ggsave("local_plotting/true_vs_predicted_LM_right.png", plot_lm_right, 
       width = 6, height = 6, dpi = 600)

ggsave("local_plotting/true_vs_predicted_2x2_combined.png", combined_plot_2x2, 
       width = 12, height = 12, dpi = 600)
print(combined_plot_2x2)