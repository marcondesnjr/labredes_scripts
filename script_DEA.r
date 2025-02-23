# Description: This script reads a spreadsheet with data from a set of tests 
# and applies DEA models to evaluate the efficiency of the DMUs. Subsequently, the tests are
# saved in a new spreadsheet with the efficiency values of each the DMUs.
# Author: Marcondes Junior
# github.com/marcondesnjr

library("Benchmarking")
library("openxlsx")


######################################################################################################
BASE_DIR <- file.path("/","home","jmnj","labredes","sctests") # Change this to the path of the directory where the tests are stored
#BASE_DIR <- file.path("/","home","jmnj","projs", "lab-redes", "labredes_scripts") # Change this to the path of the directory where the tests are stored
DATA_XLSX <- file.path(BASE_DIR, "Results.xlsx") # Change this to the path of a file where the tests results are stored
FINAL_TABLE <- file.path(BASE_DIR, "Results_Final.xlsx") # Change this to the path of a file where the tests results will be stored
INPUT_VARS <- c("Fractal.Dimension", "Time.Taken.To.Tests", "Time.Per.Request") # input variables
OUTPUT_VARS <- c("Transfer.Rate", "Requests.Per.Second", "Hurst.Parameter", "Alfa.Tail.Shape") # output variables
SHEETS_NUMS <- c(2:4) # sheets with test data to be read
DMU_SHEET <- 1 # sheet with DMU descriptions
######################################################################################################

WORKBOOK <- loadWorkbook(DATA_XLSX)
WORKBOOK_OUTPUT <- createWorkbook()
SHEET_NAMES <- names(WORKBOOK)[SHEETS_NUMS]
DescSheet <- readWorkbook(WORKBOOK, sheet = DMU_SHEET, rowNames = TRUE)
addWorksheet(WORKBOOK_OUTPUT, sheetName = "DMUS")
writeDataTable(WORKBOOK_OUTPUT, "DMUS", x = DescSheet, rowNames = TRUE, colNames = TRUE, tableStyle = "TableStyleMedium15")

for(sh in SHEET_NAMES){
  
  data <- read.xlsx(WORKBOOK, colNames = TRUE, rowNames = TRUE, startRow=1, sheet=sh) # read spreadsheet
  # delete rows with NA values
  delete.na <- function(DF, n=0) {
    DF[rowSums(is.na(DF)) <= n,]
  }

  dataDEA <- delete.na(data)

  inputs = dataDEA[, INPUT_VARS] # select only input variables values
  outputs = dataDEA[, OUTPUT_VARS] # select only output variables values, SLACK=TRUE
  
  ########
  SCCR_I=sdea(inputs,outputs,RTS="CRS",ORIENTATION="in")
  CCR_I=dea(inputs, outputs, RTS="CRS", ORIENTATION="IN", SLACK=TRUE)
  BCC_I=dea(inputs,outputs,RTS="VRS",ORIENTATION="IN", SLACK=TRUE)
  
  SCCR_O=sdea(inputs,outputs,RTS="CRS",ORIENTATION="out")
  CCR_O=dea(inputs,outputs,RTS="CRS",ORIENTATION="OUT", SLACK=TRUE)
  BCC_O=dea(inputs,outputs,RTS="VRS",ORIENTATION="OUT", SLACK=TRUE)
  
  dea.plot(inputs,outputs,RTS="crs",ORIENTATION  ="in");
  ########
  bestDMU = which.max(SCCR_I$eff)
  badDMU = which.min(SCCR_I$eff)
  
  print(sh)
  print("A DMU mais eficiente segundo o modelo DEA:")
  print(names(bestDMU))
  print("A DMU menos eficiente segundo o modelo DEA:")
  print(names(badDMU))
  
  CCR_IDataframe <- data.frame(CCR_I$eff, CCR_I$slack, CCR_I$sx, CCR_I$sy)
  BCC_IDataframe <- data.frame(BCC_I$eff, BCC_I$slack, BCC_I$sx, BCC_I$sy)
  
  CCR_ODataframe <- data.frame(CCR_O$eff, CCR_O$slack, CCR_O$sx, CCR_O$sy)
  BCC_ODataframe <- data.frame(BCC_O$eff, BCC_O$slack, BCC_O$sx, BCC_O$sy)
  
  addWorksheet(WORKBOOK_OUTPUT, paste(sh, "CCR_I", sep = "."))
  writeDataTable(WORKBOOK_OUTPUT, paste(sh, "CCR_I", sep = "."), x = CCR_IDataframe, rowNames = TRUE, colNames = TRUE, tableStyle = "TableStyleMedium15")
  
  addWorksheet(WORKBOOK_OUTPUT, paste(sh, "BCC_I", sep = "."))
  writeDataTable(WORKBOOK_OUTPUT, paste(sh, "BCC_I", sep = "."), x = BCC_IDataframe, rowNames = TRUE, colNames = TRUE, tableStyle = "TableStyleMedium15")
  
  addWorksheet(WORKBOOK_OUTPUT, paste(sh, "CCR_O", sep = "."))
  writeDataTable(WORKBOOK_OUTPUT, paste(sh, "CCR_O", sep = "."), x = CCR_ODataframe, rowNames = TRUE, colNames = TRUE, tableStyle = "TableStyleMedium15")
  
  addWorksheet(WORKBOOK_OUTPUT, paste(sh, "BCC_O", sep = "."))
  writeDataTable(WORKBOOK_OUTPUT, paste(sh, "BCC_O", sep = "."), x = BCC_ODataframe, rowNames = TRUE, colNames = TRUE, tableStyle = "TableStyleMedium15")
  
  
  effDataframe <- data.frame(SCCR_I$eff, SCCR_O$eff)
  colnames(effDataframe) <- c("SCCR_I", "SCCR_O")
  rownames(effDataframe) <- rownames(dataDEA)
  
  #sheetName <- paste(sh, "Eff", sep="_")
  
  #addWorksheet(WORKBOOK, sheetName)
  #writeDataTable(WORKBOOK, sheetName, x = effDataframe, rowNames = TRUE, colNames = TRUE, tableStyle = "TableStyleMedium15")
  
  compDataframe <- cbind(dataDEA, effDataframe)
  sheetName <- paste(sh, "MAIN", sep=".")
  
  addWorksheet(WORKBOOK_OUTPUT, sheetName)
  writeDataTable(WORKBOOK_OUTPUT, sheetName, x = compDataframe, rowNames = TRUE, colNames = TRUE, tableStyle = "TableStyleMedium15")
  
  # Formatting tables
  
  rowsLength <- dim(compDataframe)[[1]]
  colsLength <- dim(compDataframe)[[2]]
  
  #First col bold
  addStyle(WORKBOOK_OUTPUT, sheetName, style = createStyle(textDecoration = "bold"), cols = 1, rows = 1:rowsLength+1)
  
  ## Number format
  
  colsNumberStyle = c(match(INPUT_VARS,colnames(compDataframe)), match(OUTPUT_VARS,colnames(compDataframe)))+1
  colsPercentStyle = match(colnames(effDataframe), colnames(compDataframe))+1
  
  addStyle(WORKBOOK_OUTPUT, sheetName, style = createStyle(numFmt = "0.00"), cols = colsNumberStyle, rows = 1:rowsLength+1, gridExpand = TRUE)
  addStyle(WORKBOOK_OUTPUT, sheetName, style = createStyle(numFmt = "0.00%"), cols = colsPercentStyle, rows = 1:rowsLength+1, gridExpand = TRUE)

  ## Color Scale
  ### Lower is better, input vars
  cols <- match(INPUT_VARS, colnames(compDataframe))+1
  for(col in cols){
     conditionalFormatting(WORKBOOK_OUTPUT, sheetName, cols=col, rows=1:rowsLength+1,
                        style = c("#77dd77", "#ffff88", "#ff7777"), 
                        type = "colourScale")
  }
  
  ##Higher is better, output vars
  cols <- match(OUTPUT_VARS, colnames(compDataframe))+1
  for(col in cols){
    conditionalFormatting(WORKBOOK_OUTPUT, sheetName, cols=col, rows=1:rowsLength+1,
                        style = c("#ff7777", "#ffff88", "#77dd77"),
                        type = "colourScale")
  }
  ##Higher is better, eff values
  cols <- match(colnames(effDataframe), colnames(compDataframe))+1
  for(col in cols){
    conditionalFormatting(WORKBOOK_OUTPUT, sheetName, cols=col, rows=1:rowsLength+1,
                          style = c("#ff7777", "#ffff88", "#77dd77"),
                          type = "colourScale")
  }
  ####
  
  setHeaderFooter(WORKBOOK_OUTPUT, footer = c("*Transfer rate in bps",NA,NA), sheet = sheetName)
  
  }

#Ordering
sheetsNames <- names(WORKBOOK_OUTPUT)

mainSheets <- sheetsNames[grepl("\\.MAIN$", sheetsNames)]
otherSheets <- sheetsNames[!grepl("\\.MAIN$|DMUS", sheetsNames)]

order <- c("DMUS",mainSheets, otherSheets)

worksheetOrder(WORKBOOK_OUTPUT) <- match(order, sheetsNames)

saveWorkbook(WORKBOOK_OUTPUT, FINAL_TABLE, overwrite = TRUE)
# data.frame(SCCR_I$eff)
#dea.plot(inputs,outputs,RTS="crs",ORIENTATION="in");