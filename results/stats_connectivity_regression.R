## read in connectivities
df = read.csv("../results/vat_connectivity_matrix.csv",stringsAsFactors = FALSE)
df = df[,-87] # remove "identity" column of self-connectivity (always zero)

# log transform and z-transform connectivity values
conn_cols <- 5:86                      # connectivity columns
df[conn_cols] <- log1p(df[conn_cols])  # Log-transform (to reduce skewness)

my_scale <- function(x) {
# scale ignoring zeros (i.e. avoid NAs due to division by zero)
  if (length(unique(x)) == 1) return(rep(0, length(x)))
  scale(x)[,1]
}
df[conn_cols] <- lapply(df[conn_cols], function(x) { # z-transform per subject
    ave(x, df$subject, FUN = my_scale)})

df$sub = as.factor(gsub("subject","",df$subject))


## get tremor data
  dft = read.csv("../../tremorDBS/Subjects_tremorDBS/tremorallsubs_cleaned.csv", header = TRUE)
  dft = dft[!is.na(dft$side),] # remove OFF measurements
  dft$contact = with(dft, ifelse(contact > 8, contact - 8, contact)) # re-code contact number
  dft$sub = as.factor(gsub("subject","",as.character(dft$sub))) # let "sub" be just a number
 # reverse side, keeping possible NAs
  sidena = is.na(dft$side) 
  dft$contraside = ifelse(dft$side == "L","R","L")  
  dft$contraside[sidena] = NA
  colnames(dft) <- gsub("mA","amp",names(dft)) # rename amplitude column

# merge tremor and connectivity datasets
dfm = merge(dft, df , by.x = c("sub", "contraside", "contact", "amp")
                    , by.y = c("sub", "side"      , "contact", "amp")
                    , all.x = FALSE, all.y = FALSE)

dfmr = dfm[dfm$side == "R",]
dfml = dfm[dfm$side == "L",]

#dfm = dfml

# preparation of predictor and dependent var
y <- with(dfm, rms - ave(rms, sub, FUN = mean)) # manual demeaning
X <- as.matrix(dfm[, paste0("X", 1:82)])  # Assuming VAT–ROI1 to ROI82

    
# Lasso/elastic net -----------------------------------------------------

  library(glmnet)

  fit <- cv.glmnet(X, y, alpha = 1)  # Lasso (use alpha = 0.5 for Elastic Net)
  coef(fit, s = "lambda.min")

  best_lambda <- fit$lambda.1se
  coef_lasso <- coef(fit, s = best_lambda)

 # Convert to readable data frame
  summary_df <- as.data.frame(as.matrix(coef_lasso))
  summary_df$variable <- rownames(summary_df)
  summary_df <- summary_df[summary_df$s1 != 0, ]  # Keep non-zero coefficients

  selected_vars <- rownames(summary_df)[-1]  # remove intercept

 # Fit standard linear model on selected variables to obtain p-values
  lm_fit <- lm(y ~ ., data = as.data.frame(X)[, selected_vars, drop = FALSE])
  summary(lm_fit)

 # Predict for manual R2 calculation
  y_pred <- predict(fit, newx = X, s = "lambda.min")

 # Compute R-squared manually
  rss <- sum((y - y_pred)^2)
  tss <- sum((y - mean(y))^2)
  r_squared <- 1 - rss / tss

  cat("Explained variance Lasso/elastic net (R²):", r_squared, "\n")

# partial least squares ------------------------------------------------
  library(pls)
  pls_model <- plsr(y ~ X, ncomp = 5, validation = "CV")
  summary(pls_model)

  # permutation test
  if(FALSE){
   set.seed(123)
   n_perm <- 10000
   perm_rmsep = rep(NA,n_perm)
   real_rmsep = RMSEP(pls_model)$val[1,1,pls_model$ncomp]

   for (i in 1:n_perm) {
       print(i)
       yy <- sample(y) 
       perm_fit <- plsr(yy ~ X)
       perm_rmsep[i] <- RMSEP(perm_fit)$val[1, 1, perm_fit$ncomp]
   }

  p_value <- mean(perm_rmsep <= real_rmsep)
  cat("Permutation p-value:", p_value)
  }

  # score plot
  library(ggplot2)
  scores_mat <- as.matrix(pls_model$scores)
  #scores_df$subject <- rownames(scores_df)  # optional
  # Pull out components manually and coerce into proper matrix
  scores_df <- data.frame(
    Comp1 = as.numeric(scores_mat[, 1]),
    Comp2 = as.numeric(scores_mat[, 2]),
    Comp3 = as.numeric(scores_mat[, 3]),
    Comp4 = as.numeric(scores_mat[, 4]),
    Comp5 = as.numeric(scores_mat[, 5]))

  ggplot(scores_df, aes(x = Comp1, y = Comp2)) +
      geom_point(size = 3, color = "steelblue") +
      geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
      geom_vline(xintercept = 0, linetype = "dashed", color = "gray") +
      labs(title = "PLS Score Plot",
           x = "Component 1", y = "Component 2") +
      theme_minimal(base_size = 14)

  # loading plot
  loadings_mat <- as.matrix(pls_model$loadings)
  #loadings_df$subject <- rownames(loadings_df)  # optional
  # Pull out components manually and coerce into proper matrix
  loadings_df <- data.frame(
    Comp1 = as.numeric(loadings_mat[, 1]),
    Comp2 = as.numeric(loadings_mat[, 2]),
    Comp3 = as.numeric(loadings_mat[, 3]),
    Comp4 = as.numeric(loadings_mat[, 4]),
    Comp5 = as.numeric(loadings_mat[, 5]))

  loadings_df$variable <- rownames(loadings_df)

  ggplot(loadings_df, aes(x = Comp1, y = Comp2, label = variable)) +
      geom_point(color = "darkred", size = 2) +
      geom_text(size = 3, hjust = 0, vjust = 1.2) +
      geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
      geom_vline(xintercept = 0, linetype = "dashed", color = "gray") +
      labs(title = "PLS Loading Plot",
           x = "Component 1", y = "Component 2") +
      theme_minimal(base_size = 14)

  # vip plot
  vip <- function(object, ncomp) {
      W <- object$loading.weights[,1:ncomp]
      T <- object$scores[,1:ncomp]
      Y <- model.response(model.frame(object))
      p <- ncol(W)
      h <- ncol(T)
      SS <- colSums(T^2) * colSums((fitted(object) - mean(Y))^2) / h
      vip_scores <- sqrt(p * rowSums((W^2) * diag(SS)) / sum(SS))
      return(vip_scores)
  }

  vip_scores <- vip(pls_model, 5)
  regnames = as.character(read.table("seeds.txt")[,1])
  vip_df <- data.frame(variable = read.table("seeds.txt"), VIP = vip_scores)
  colnames(vip_df) <- c("variable","VIP")
#  vip_df <- data.frame(variable = names(vip_scores), VIP = vip_scores)


  ggplot(vip_df[order(-vip_df$VIP)[1:20],], aes(x = reorder(variable, VIP), y = VIP)) +
      geom_col(fill = "darkgreen") +
      coord_flip() +
      labs(title = "Top 20 Variables by VIP Score",
           x = "Variable", y = "VIP Score") +
      theme_minimal(base_size = 14)


# Lasso/elastic net -----------------------------------------------------

if(FALSE){

# manual demeaning
your_data$rms_demeaned <- with(your_data, rms - ave(rms, subject, FUN = mean))
    
# Lasso/elastic    
library(glmnet)
X <- as.matrix(your_data[, paste0("conn_", 1:82)])  # Assuming VAT–ROI1 to ROI82
y <- your_data$rms
fit <- cv.glmnet(X, y, alpha = 1)  # Lasso (use alpha = 0.5 for Elastic Net)
coef(fit, s = "lambda.min")

# PCA
pca <- prcomp(X, scale. = TRUE)
summary(pca)  # Look for number of components explaining, e.g., 90% variance
pcs <- pca$x[, 1:5]
lm_model <- lm(y ~ pcs)
summary(lm_model)

# partial least squares
library(pls)
pls_model <- plsr(rms ~ ., data = as.data.frame(X), ncomp = 5, validation = "CV")
summary(pls_model)

# with ICA
library(fastICA)
ica_result <- fastICA(X, n.comp = 10)
lm_model <- lm(y ~ ica_result$S)


}
