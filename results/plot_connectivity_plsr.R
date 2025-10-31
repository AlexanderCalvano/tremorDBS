install.packages("ggseg")
install.packages("ggsegDk")

library(ggseg)
library(ggsegDk)


s = l[,1] # loadings from plsr model, number assigns component

vip_df <- data.frame(
    region_full = names(s),
    vip = as.numeric(s),
    stringsAsFactors = FALSE
)

                                        # Split into hemisphere and region
vip_df$hemi <- ifelse(grepl("^l-", vip_df$region_full), "left", "right")
vip_df$region <- gsub("^(l|r-)", "", vip_df$region_full)

                                        # Clean region names for ggseg (lowercase, no underscores)
vip_df$region <- tolower(gsub("_", "", vip_df$region))


ggseg(data = vip_df,
      atlas = dk,
      mapping = aes(fill = vip),
      position = "dispersed") +  # disperses hemispheres side by side
    scale_fill_viridis_c(option = "plasma", na.value = "grey90") +
    theme_void() +
    theme(legend.position = "right") +
    labs(title = "PLS VIP Scores by Brain Region",
         fill = "VIP Score")
