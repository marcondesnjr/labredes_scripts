# Description: This script reads the results of the tests and generates a excel file with the results
# Author: Marcondes Junior
# github.com/marcondesnjr

library("pracma")
library("fractaldim")
library("ptsuite")
library("openxlsx")

##################################################################################
#BASE_DIR <- file.path("/","home","jmnj","labredes","sctests") # Change this to the path of the directory where the tests are stored
BASE_DIR <- file.path("/","home","jmnj","projs", "lab-redes", "labredes_scripts", "Atividade") # Change this to the path of the directory where the tests are stored
DATA_DIR <- file.path(BASE_DIR, "data") # Change this to the path of the directory where the tests are stored
RESULT_DIR <- file.path(BASE_DIR, "Results.xlsx") # Change this to the path of a file where the tests results will be stored
##################################################################################

# Function to read a file, return NA if the file is empty
readValue <- function(file){
  temp <- scan(file = file)
  if (length(temp) == 0) {
    temp <- NA
  }
  return(temp)
}

scaleVector <- c()
dmuindex <- 1

DFList <- list()

DMUDesc = data.frame(
  DMU = c(),
  vram = c(),
  server = c(),
  alg = c()
  
)

DMUDataFrame = data.frame()

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
          statsDir <- file.path(scale, "stats")
          
          if(! scaleName %in% scaleVector){
            scaleVector <- append(scaleVector, scaleName)
          }
          
          #######################
          DMUId <- paste(rownames(DMU) ,basename(scale), sep = "_")
          statsDir <- file.path(scale, "stats")
          
          timeToTest <- readValue(file.path(statsDir, "time_taken_for_tests.txt"))
          transferRate <- readValue(file.path(statsDir, "transfer_rate.txt"))
          TimePerRequest <- readValue(file.path(statsDir, "time_per_req.txt"))
          requestPerSecond <- readValue(file.path(statsDir, "req_per_sec.txt"))
          timeSeries = readValue(file.path(statsDir, "timeseries.txt"))
          if(is.na(timeSeries[1])){
            fdim <- NA
            hurst <- NA
            alfaTailShape <- NA
          }else{
            fdim <- fd.estimate(timeSeries, method="rodogram")[["fd"]]
            hurst <- hurstexp(timeSeries)[["Hs"]] #???
            alfaTailShape <- alpha_mle(timeSeries)[["shape"]]
          }
          
          
          row <- data.frame(
            DMU = DMUId,
            fdim = fdim,
            timeToTest = timeToTest,
            TimePerRequest = TimePerRequest,
            transferRate = transferRate,
            requestPerSecond  = requestPerSecond,
            hurst = hurst,
            alfaTailShape = alfaTailShape
          )
          
          DMUDataFrame <- rbind(DMUDataFrame, row)
      }
    }
  }
}

colnames(DMUDataFrame) <- c("DMU", "Fractal Dimension" ,"Time Taken To Tests", "Time Per Request","Transfer Rate", "Requests Per Second", "Hurst Parameter", "Alfa Tail Shape" )
colnames(DMUDesc) <- c("VRAM" ,"Server", "Algorithm")

wb <- createWorkbook()
addWorksheet(wb, "DMUDesc")
writeDataTable(wb, "DMUDesc", x = DMUDesc, rowNames = TRUE, colNames = TRUE, tableStyle = "TableStyleMedium15")

for(scaleName in scaleVector){
  filtered <- subset(DMUDataFrame, grepl(scaleName, DMU))
  filtered$DMU <- gsub(paste("_", scaleName, sep = ""),"",as.character(filtered$DMU))
  rownames(filtered) <- filtered[[1]]
  filtered <- filtered[, -1]
  addWorksheet(wb, scaleName)
  writeDataTable(wb, scaleName, x = filtered, rowNames = TRUE, colNames = TRUE, tableStyle = "TableStyleMedium15")
}

saveWorkbook(wb, RESULT_DIR, overwrite = TRUE)



