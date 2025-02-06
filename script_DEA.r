library("Benchmarking")
library("ggplot2")
library("openxlsx")

BASE_DIR <- file.path("/","home","jmnj","projs","lab-redes","labredes_scripts")
DATA_XLSX <- file.path(BASE_DIR, "Results.xlsx")
INPUT_VARS <- c("Fractal.Dimension", "Time.Taken.To.Tests", "Time.Per.Request")
OUTPUT_VARS <- c("Transfer.Rate", "Requests.Per.Second", "Hurst.Parameter", "Alfa.Tail.Shape")
SHEETS_NUMS <- c(2:3)

WORKBOOK <- loadWorkbook(DATA_XLSX)
SHEET_NAMES <- names(WORKBOOK)[SHEETS_NUMS]
for(sh in SHEET_NAMES){
  
  data <- read.xlsx(WORKBOOK, colNames = TRUE, rowNames = TRUE, startRow=1, sheet=sh) # read spreadsheet
  inputs = data[, INPUT_VARS] # select only input variables values
  outputs = data[, OUTPUT_VARS] # select only output variables values, SLACK=TRUE
  
  CCR_I=dea(inputs, outputs, RTS="CRS", ORIENTATION="in", SLACK=TRUE) # runs input-oriented CCR DEA model
  SCCR_I=sdea(inputs,outputs,RTS="CRS",ORIENTATION="in") # runs super-efficiency input-oriented CCR DEA model
  CCR_O=dea(inputs,outputs,RTS="CRS",ORIENTATION="out", SLACK=TRUE)
  
  bestDMU = which.max(SCCR_I$eff)
  badDMU = which.min(SCCR_I$eff)
  
  print(sh)
  print("A DMU mais eficiente segundo o modelo DEA:")
  print(names(bestDMU))
  print("A DMU menos eficiente segundo o modelo DEA:")
  print(names(badDMU))
  
  
  effDataframe <- cbind(SCCR_I$eff, CCR_I$eff, CCR_O$eff)
  colnames(effDataframe) <- c("SCCRI", "CCRI", "CCRO")
  rownames(effDataframe) <- rownames(data)
  
  sheetName <- paste(sh, "Eff", sep="_")
  
  addWorksheet(WORKBOOK, sheetName)
  writeData(WORKBOOK, sheetName, x = effDataframe, rowNames = TRUE, colNames = TRUE)
}

saveWorkbook(WORKBOOK, "test.xlsx", overwrite = TRUE)
# data.frame(SCCR_I$eff)
#dea.plot(inputs,outputs,RTS="crs",ORIENTATION="in");
# write.xlsx2(SCCR_I$eff, file='eficiencia.xlsx') #exporta os dados de eficiencia
