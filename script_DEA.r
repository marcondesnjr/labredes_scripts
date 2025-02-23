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


scriptDEA <- function(
    base_dir = BASE_DIR, 
    data_xlsx = DATA_XLSX, 
    final_table = FINAL_TABLE, 
    input_vars = INPUT_VARS, 
    output_vars = OUTPUT_VARS, 
    sheets_nums = SHEETS_NUMS, 
    dmu_sheet = DMU_SHEET
)
{
  
  workbook <- loadWorkbook(data_xlsx)
  workbook_output <- createWorkbook()
  sheet_names <- names(workbook)[sheets_nums]
  DescSheet <- readWorkbook(workbook, sheet = dmu_sheet, rowNames = TRUE)
  addWorksheet(workbook_output, sheetName = "DMUS")
  writeDataTable(workbook_output, "DMUS", x = DescSheet, rowNames = TRUE, colNames = TRUE, tableStyle = "TableStyleMedium15")
  allDataFrame <- data.frame()
  
  
  for(sh in sheet_names){
    data <- read.xlsx(workbook, colNames = TRUE, rowNames = TRUE, startRow=1, sheet=sh) # read spreadsheet
    dataDEA <- processWorksheet(data, sh, input_vars, output_vars, workbook_output)
    
    escalDataDEA <- dataDEA
    rownames(escalDataDEA) <- paste(rownames(dataDEA), sh, sep = ".")
    allDataFrame <- rbind(allDataFrame, escalDataDEA)
    
  }
  
  processWorksheet(allDataFrame, "FULL", input_vars, output_vars, workbook_output)
  
  #Ordering
  sheetsNames <- names(workbook_output)
  
  mainSheets <- sheetsNames[grepl("\\.MAIN$", sheetsNames)]
  otherSheets <- sheetsNames[!grepl("\\.MAIN$|DMUS", sheetsNames)]
  
  order <- c("DMUS",mainSheets, otherSheets)
  worksheetOrder(workbook_output) <- match(order, sheetsNames)
  saveWorkbook(workbook_output, FINAL_TABLE, overwrite = TRUE)
  
}



##Delete rows with NA values
delete.na <- function(DF, n=0) {
  DF[rowSums(is.na(DF)) <= n,]
}

##Format tables with colors scale based on the input and output  vars
tableFormatter <- function(WORKBOOK, dataFrame, sheetName, numStyle, percStyle,lb, hb ){
  # Formatting tables
  rowsLength <- dim(dataFrame)[[1]]
  colsLength <- dim(dataFrame)[[2]]
  
  #First col bold
  addStyle(WORKBOOK, sheetName, style = createStyle(textDecoration = "bold"), cols = 1, rows = 1:rowsLength+1)
  
  ## Number format
  colsNumberStyle = match(numStyle ,colnames(dataFrame))+1
  colsPercentStyle = match(percStyle, colnames(dataFrame))+1
  
  addStyle(WORKBOOK, sheetName, style = createStyle(numFmt = "0.00"), cols = colsNumberStyle, rows = 1:rowsLength+1, gridExpand = TRUE)
  addStyle(WORKBOOK, sheetName, style = createStyle(numFmt = "0.00%"), cols = colsPercentStyle, rows = 1:rowsLength+1, gridExpand = TRUE)

  ## Color Scale
  ### Lower is better, input vars
  cols <- match(lb, colnames(dataFrame))+1
  for(col in cols){
    conditionalFormatting(WORKBOOK, sheetName, cols=col, rows=1:rowsLength+1,
                          style = c("#77dd77", "#ffff88", "#ff7777"), 
                          type = "colourScale")
  }
  
  ##Higher is better, output vars
  cols <- match(hb, colnames(dataFrame))+1
  for(col in cols){
    conditionalFormatting(WORKBOOK, sheetName, cols=col, rows=1:rowsLength+1,
                          style = c("#ff7777", "#ffff88", "#77dd77"),
                          type = "colourScale")
  }
}

deaCalculator <- function(dataDEA,sh, inputVars=INPUT_VARS, outputVars=OUTPUT_VARS){
  inputs = dataDEA[, inputVars] # select only input variables values
  outputs = dataDEA[, outputVars] # select only output variables values, SLACK=TRUE

  SCCR_I=sdea(inputs,outputs,RTS="CRS",ORIENTATION="in")
  CCR_I=dea(inputs, outputs, RTS="CRS", ORIENTATION="IN", SLACK=TRUE)
  BCC_I=dea(inputs,outputs,RTS="VRS",ORIENTATION="IN", SLACK=TRUE)
  
  SCCR_O=sdea(inputs,outputs,RTS="CRS",ORIENTATION="out")
  CCR_O=dea(inputs,outputs,RTS="CRS",ORIENTATION="OUT", SLACK=TRUE)
  BCC_O=dea(inputs,outputs,RTS="VRS",ORIENTATION="OUT", SLACK=TRUE)
  
  #dea.plot(inputs,outputs,RTS="vrs",ORIENTATION="out", main = sh);
  dea.plot.frontier(inputs, outputs, RTS="crs", main = paste(sh, "Frontier"));
  
  results <- list(SCCR_I = SCCR_I, CCR_I = CCR_I, BCC_I = BCC_I, SCCR_O = SCCR_O, CCR_O = CCR_O, BCC_O = BCC_O)
  
  return(results)
}

writeDataWorksheet <- function(WORKBOOK, sheetName, df){
  addWorksheet(WORKBOOK, sheetName)
  writeDataTable(WORKBOOK, sheetName, x = df, rowNames = TRUE, colNames = TRUE, tableStyle = "TableStyleMedium15")
}

processWorksheet <- function(data, sh, inputVars, outputVars, workbookOutput) {
  dataDEA <- delete.na(data)
  
  allDEA <- deaCalculator(dataDEA, sh, inputVars, outputVars)
  
  SCCR_I <-allDEA$SCCR_I
  CCR_I <- allDEA$CCR_I
  BCC_I <- allDEA$BCC_I
  
  SCCR_O <- allDEA$SCCR_O
  CCR_O <- allDEA$CCR_O
  BCC_O <- allDEA$BCC_O
  
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
  
  writeDataWorksheet(workbookOutput,  paste(sh, "CCR_I", sep = "."),CCR_IDataframe)
  writeDataWorksheet(workbookOutput,  paste(sh, "BCC_I", sep = "."),BCC_IDataframe)
  writeDataWorksheet(workbookOutput,  paste(sh, "CCR_O", sep = "."),CCR_ODataframe)
  writeDataWorksheet(workbookOutput,  paste(sh, "BCC_O", sep = "."),BCC_ODataframe)
  
  effDataframe <- data.frame(SCCR_I$eff, SCCR_O$eff)
  colnames(effDataframe) <- c("SCCR_I", "SCCR_O")
  rownames(effDataframe) <- rownames(dataDEA)
  
  compDataframe <- cbind(dataDEA, effDataframe)
  sheetName <- paste(sh, "MAIN", sep=".")
  writeDataWorksheet(workbookOutput,  sheetName, compDataframe)
  tableFormatter(workbookOutput, compDataframe, sheetName, numStyle = c(inputVars, outputVars) , percStyle = colnames(effDataframe), lb = inputVars, hb = c(outputVars, colnames(effDataframe)))
  
  return(dataDEA)
}

scriptDEA()