library(pracma)
library(fractaldim)
library(ptsuite)
library(openxlsx)

BASE_DIR <- file.path("/","home","jmnj","projs","lab-redes","labredes_scripts")
DATA_DIR <- file.path(BASE_DIR, "data")


scaleVector <- c()
dmuindex <- 1

DFList <- list()

DMUDesc = data.frame(
  DMU = c(),
  vram = c(),
  server = c(),
  alg = c()
  
)

DMUDataFrame = data.frame(
  DMU = c(),
  fdim = c(),
  timeToTest = c(),
  TimePerRequest = c(),
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
      DMU <- data.frame(basename(ram), basename(server), basename(alg))
      rownames(DMU) <- paste("DMU",dmuindex, sep = "")
      DMUDesc <- rbind(DMUDesc, DMU)
      dmuindex <- dmuindex + 1
      scales <- list.dirs(path = alg, full.names = TRUE, recursive = FALSE)
        for(scale in scales){
          scaleName <- basename(scale)
          
          if(! scaleName %in% scaleVector){
            scaleVector <- append(scaleVector, scaleName)
          }
          
          #######################
          DMUId <- paste(rownames(DMU) ,basename(scale), sep = "_")
          statsDir <- file.path(scale, "stats")
          
          timeToTest <- scan(file = file.path(scale, "stats", "time_taken_for_tests.txt"))
          transferRate <- scan(file = file.path(scale, "stats", "transfer_rate.txt"))
          TimePerRequest <- scan(file = file.path(scale, "stats", "time_per_req.txt"))
          requestPerSecond <- scan(file = file.path(scale, "stats", "req_per_sec.txt"))
          timeSeries = scan(file = file.path(scale, "stats", "timeseries.txt"))
          fdim <- fd.estimate(timeSeries, method="rodogram")[2]
          hurst <- hurstexp(timeSeries)[1]
          alfaTailShape <- alpha_mle(timeSeries)[1]
          
          row <- data.frame(DMUId, fdim, timeToTest, TimePerRequest, transferRate, requestPerSecond, hurst, alfaTailShape)
          
          DMUDataFrame <- rbind(DMUDataFrame, row)
      }
    }
  }
}

colnames(DMUDataFrame) <- c("DMU", "Fractal Dimension" ,"Time Taken To Tests", "Time Per Request","Transfer Rate", "Requests Per Second", "Hurst Parameter", "Alfa Tail Shape" )
colnames(DMUDesc) <- c("VRAM" ,"Server", "Algorithm")
DFList[["DMUDesc"]] <- DMUDesc
for(scaleName in scaleVector){
  filtered <- subset(DMUDataFrame, grepl(scaleName, DMU))
  filtered$DMU <- gsub(paste("_", scaleName, sep = ""),"",as.character(filtered$DMU))
  rownames(filtered) <- filtered[[1]]
  filtered <- filtered[, -1]
  DFList[[scaleName]] <- filtered
  write.table(filtered, file.path(BASE_DIR, paste(scaleName, ".csv", sep = "")), sep = ",", row.names = TRUE, col.names = TRUE)
}

write.xlsx(DFList, file = file.path(BASE_DIR, "Results.xlsx"), rowNames=TRUE, colNames=TRUE)




