library(pracma)
library(fractaldim)
library(ptsuite)

BASE_DIR <- file.path("/","home","jmnj","Área de Trabalho","sc")
DATA_DIR <- file.path(BASE_DIR, "data")

DMUDataFrames <- c()

scaleVector <- c()

DMUDataFrame = data.frame(
  DMU = c(),
  fdim = c(),
  timeToTest = c(),
  transferRate = c(),
  requestPerSecond  = c(),
  hurst = c()
)

rams <- list.dirs(path = DATA_DIR, full.names = TRUE, recursive = FALSE)
for(ram in rams){
  servers <- list.dirs(path = ram, full.names = TRUE, recursive = FALSE)
  for(server in servers){
    algs <- list.dirs(path = server, full.names = TRUE, recursive = FALSE)
    for(alg in algs){
      scales <- list.dirs(path = alg, full.names = TRUE, recursive = FALSE)
        for(scale in scales){
          scaleName <- basename(scale)
          
          if(! scaleName %in% scaleVector){
            scaleVector <- append(scaleVector, scaleName)
          }
          
          #######################
          DMU <- paste(basename(ram), basename(server), basename(alg), basename(scale), sep = "_")
          statsDir <- file.path(scale, "stats")
          
          timeToTest <- scan(file = file.path(scale, "stats", "time_taken_for_tests.txt"))
          transferRate <- scan(file = file.path(scale, "stats", "transfer_rate.txt"))
          requestPerSecond <- scan(file = file.path(scale, "stats", "req_per_sec.txt"))
          timeSeries = scan(file = file.path(scale, "stats", "timeseries.txt"))
          fdim <- fd.estimate(timeSeries, method="rodogram")[2]
          hurst <- hurstexp(timeSeries)[1]
          alfaTailShape <- alpha_mle(timeSeries)[1]
          
          row <- data.frame(DMU, fdim, timeToTest, transferRate, requestPerSecond, hurst, alfaTailShape)
          
          DMUDataFrame <- rbind(DMUDataFrame, row)
      }
    }
  }
}

colnames(DMUDataFrame) <- c("DMU", "Fractal Dimension" ,"Time Taken To Tests", "Transfer Rate", "Requests Per Second", "Hurst Parameter", "Alfa Tail Shape" )

for(scaleName in scaleVector){
  filtered <- subset(DMUDataFrame, grepl(scaleName, DMU))
  write.table(filtered, file.path(BASE_DIR, paste(scaleName, ".csv")), sep = ",", row.names = FALSE, col.names = TRUE)
}