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
  dft = read.csv("../../tremorDBS/Subjects_tremorDBS/tremorallsubs_cleaned2.csv", header = TRUE)
  dft = dft[!is.na(dft$side),] # remove OFF measurements
  dft = dft[!(dft$side == "L" & dft$contact > 8) & !(dft$side == "R" & dft$contact < 9),]
  dft$contact = with(dft, ifelse(contact > 8, contact - 8, contact)) # re-code contact number
  dft$sub = as.factor(gsub("subject","",as.character(dft$sub))) # let "sub" be just a number
  colnames(dft) <- gsub("mA","amp",names(dft)) # rename amplitude column

 # reverse side, keeping possible NAs
  sidena = is.na(dft$side) 
  ## dft$contraside = ifelse(dft$side == "L","R","L")  # this was wrong, side is already hemisphere
  dft$contraside = dft$side ## ! ## this is correct
  dft$contraside[sidena] = NA

 # aggregate across trials 
 dft = aggregate(rms~sub+contraside+contact+amp, data = dft, FUN = mean)


# merge tremor and connectivity datasets
dfm = merge(dft, df , by.x = c("sub", "contraside", "contact", "amp")
                    , by.y = c("sub", "side"      , "contact", "amp")
                    , all.x = FALSE, all.y = FALSE)

#get sweetspot data
dfsl = read.csv("../results/general_SSI_ipsilateral_left_data.csv", header = TRUE)
dfsr = read.csv("../results/general_SSI_ipsilateral_right_data.csv", header = TRUE)
dfs = rbind(dfsl, dfsr)
dfs$ssi = dfs$mean_sweetspot_intensity

# merge datasets
dfm = merge(dfm, dfs, by.x = c("sub"    ,"contraside","contact","amp")
                    , by.y = c("subnum" ,"side.x"    ,"contact","amp")
                    , all.x = FALSE, all.y = FALSE)

dfmm = dfm

for(side in c("both","left","right")){

if(side == "both")  dfm = dfmm
if(side == "left")  dfm = dfmm[dfmm$contraside == "L",]
if(side == "right") dfm = dfmm[dfmm$contraside == "R",]

    

   
# partial least squares ------------------------------------------------
  library(pls)
  library(caret)
  library(cocor)
  set.seed(123)

  dfm$y = log(dfm$rms)
  K <- 10
  ctrl <- trainControl(method = "cv", number = K, savePredictions = "final")

  ## Fit models with CV and collect out-of-fold predictions
  m_lm  <- train(y ~ ssi , data = dfm, method = "lm",  trControl = ctrl)
  m_pls <- train(y ~ .   , data = dfm[,c("y", paste0("X", 1:82))]
                         , method = "pls", trControl = ctrl, tuneLength = 15)

  preds <- merge(
      m_lm$pred[, c("rowIndex", "pred")],
      m_pls$pred[, c("rowIndex", "pred")],
      by = "rowIndex",
      suffixes = c("_lm", "_pls")
      )
  preds$y <- dfm$y[preds$rowIndex]
  write.csv(preds,paste("../results/true_and_predicted_values_",side,".csv",sep = ""))
  yy = preds$y; p1 = preds$pred_lm; p2 = preds$pred_pls;
    

  sink(file = paste("../results/regression_model_summary_and_comparison_",side,".txt",sep = ""))
    cat(paste("PLS model:\n----------\n\n")); print(summary(m_pls$finalModel)); 
    cat(paste("\nCorrelation true vs predicted:\n------------\n\n")); print(cor.test(yy, p2))
    cat(paste("\n\n\n"))
    cat(paste("LM:\n----------\n\n"       )); print(summary(m_lm$finalModel));
    cat(paste("\nCorrelation true vs predicted:\n------------\n\n")); print(cor.test(yy, p1))
    cat(paste("\n\n\n"))
    cat(paste("Model comparison by Williams/Steiger test for two dependent correlations\n"))
    cat(paste("----------\n\n"))
    print(cocor.dep.groups.overlap(r.jk = cor(yy, p1),r.jh = cor(yy, p2),r.kh = cor(p1, p2)
                                  , n = length(yy), alternative = "two.sided", test = "steiger1980"))
    cat(paste("\n\n\n"))
 
  ## permutation test for pls model against Null hypothesis (no effect)
   grid <- expand.grid(ncomp = m_pls$finalModel$ncomp)
   n_perm <- 100
   permcor = rep(NA,n_perm)

   for (i in 1:n_perm) {
       message(paste(side, i))
       dfm$yy <- sample(dfm$y)
       m_pls_prime <- train(yy ~ . , data = dfm[,c("yy", paste0("X", 1:82))]
                         , method = "pls", trControl = ctrl, tuneGrid = grid)
       pyy <- m_pls_prime$pred$pred[order(m_pls_prime$pred$rowIndex)]
       yy <- dfm$yy[m_pls_prime$pred$rowIndex[order(m_lm$pred$rowIndex)]]
       permcor[i] = cor(pyy, yy)
   }
   
  cat(paste("\nT-test of pls true/predicted vs permutation models:\n------------\n\n"))
  print(t.test(permcor, mu = cor(preds$pred_pls, preds$y)))
  
  sink(file = NULL)

  ## extract loadings
  if(TRUE){
    loadings_mat = as.matrix(m_pls$finalModel$loadings)[,1:m_pls$finalModel$ncomp]
    loadings_df = as.data.frame(loadings_mat)
    loadings_df$variable <- rownames(loadings_df)
    dfnames = read.table("seeds.txt")
    colnames(dfnames) <- "name"
    loadings_df = cbind(loadings_df, dfnames)
    write.csv(loadings_df, file = paste("../results/pls_regression_loadings_",side,".csv",sep = ""))
  }

 cat("Finished\n",file = "")
} # end of for loop over sides

