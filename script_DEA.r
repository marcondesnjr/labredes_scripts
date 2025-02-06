library("Benchmarking")
#library("ggplot2")
library("openxlsx")

######################################################################################################
BASE_DIR <- file.path("/","home","jmnj","projs","lab-redes","labredes_scripts")
DATA_XLSX <- file.path(BASE_DIR, "Results.xlsx")
FINAL_TABLE <- file.path(BASE_DIR, "Results_Final.xlsx")
INPUT_VARS <- c("Fractal.Dimension", "Time.Taken.To.Tests", "Time.Per.Request")
OUTPUT_VARS <- c("Transfer.Rate", "Requests.Per.Second", "Hurst.Parameter", "Alfa.Tail.Shape")
SHEETS_NUMS <- c(2:3)
######################################################################################################

WORKBOOK <- loadWorkbook(DATA_XLSX)
SHEET_NAMES <- names(WORKBOOK)[SHEETS_NUMS]
for(sh in SHEET_NAMES){
  
  data <- read.xlsx(WORKBOOK, colNames = TRUE, rowNames = TRUE, startRow=1, sheet=sh) # read spreadsheet
  delete.na <- function(DF, n=0) {
    DF[rowSums(is.na(DF)) <= n,]
  }
  dataDEA <- delete.na(data)
  inputs = dataDEA[, INPUT_VARS] # select only input variables values
  outputs = dataDEA[, OUTPUT_VARS] # select only output variables values, SLACK=TRUE
  
  SCCR_I=sdea(inputs,outputs,RTS="CRS",ORIENTATION="in") # runs super-efficiency input-oriented CCR DEA model
  CCR_I=dea(inputs, outputs, RTS="CRS", ORIENTATION="in", SLACK=TRUE) # runs input-oriented CCR DEA model
  BCC_I=dea(inputs,outputs,RTS="VRS",ORIENTATION="IN", SLACK=TRUE)
  
  SCCR_O=sdea(inputs,outputs,RTS="CRS",ORIENTATION="out")
  CCR_O=dea(inputs,outputs,RTS="CRS",ORIENTATION="out", SLACK=TRUE)
  BCC_O=dea(inputs,outputs,RTS="VRS",ORIENTATION="out", SLACK=TRUE)
  
  bestDMU = which.max(SCCR_I$eff)
  badDMU = which.min(SCCR_I$eff)
  
  print(sh)
  print("A DMU mais eficiente segundo o modelo DEA:")
  print(names(bestDMU))
  print("A DMU menos eficiente segundo o modelo DEA:")
  print(names(badDMU))
  
  
  effDataframe <- cbind(SCCR_I$eff, CCR_I$eff, BCC_I$eff, SCCR_O$eff, CCR_O$eff, BCC_O$eff)
  colnames(effDataframe) <- c("SCCR_I", "CCR_I", "BCC_I", "SCCR_O", "CCR_O", "BCC_O")
  rownames(effDataframe) <- rownames(dataDEA)
  
  sheetName <- paste(sh, "Eff", sep="_")
  
  addWorksheet(WORKBOOK, sheetName)
  writeData(WORKBOOK, sheetName, x = effDataframe, rowNames = TRUE, colNames = TRUE)
}

saveWorkbook(WORKBOOK, FINAL_TABLE, overwrite = TRUE)
# data.frame(SCCR_I$eff)
#dea.plot(inputs,outputs,RTS="crs",ORIENTATION="in");
# write.xlsx2(SCCR_I$eff, file='eficiencia.xlsx') #exporta os dados de eficiencia
