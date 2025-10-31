calc.tremor <- function(fname, fwin = c(4,7)){
  df = read.csv(fname, header = TRUE)
  df$d = sqrt(df$x^2 + df$y^2 + df$z^2)
  samp.freq <- 1/mean(diff(df$time))
  N <- length(df$time)
  fk <- fft(df$d)
  freq <- (1:(length(fk)))*samp.freq/(2*length(fk))
  amp <- Mod(fk)
  #pha <- Arg(fk) 
  meanamp = mean(amp[freq>=fwin[1] & freq <= fwin[2]], na.rm = TRUE)
  rms = mean(sqrt((df$x^2 + df$y^2 + df$z^2)/3), na.rm = TRUE)
  mA   = substr(fname,gregexpr("mA",  fname)[[1]][1]-3,gregexpr("mA" ,fname)[[1]][1]-1)
  cond = substr(fname,gregexpr("mA",  fname)[[1]][1]+3,gregexpr("mA" ,fname)[[1]][1]+4)
  sub  = substr(fname,gregexpr("data",fname)[[1]][1]+5,gregexpr("stn",fname)[[1]][1]-2)
  side = substr(fname,gregexpr("stn" ,fname)[[1]][1]+3,gregexpr("stn",fname)[[1]][1]+3)
  contact = substr(fname,gregexpr("stn" ,fname)[[1]][1]+6,gregexpr("stn",fname)[[1]][1]+7)
  contact = gsub("_","",contact)
  return(data.frame(sub, mA = mA, cond = cond, side = side, contact = contact
                   ,meanamp = meanamp, rms = rms))
}


files = system("find ../data -iname '*.csv'", intern = TRUE)
df = lapply(files,calc.tremor)
ddf = do.call(rbind,df)
write.csv(ddf, "tremor.csv")

dfr = subset(ddf, cond == "re")
dfr$AMP = as.numeric(as.character(dfr$mA))
dfr$AMP[is.na(dfr$AMP)] = 0
