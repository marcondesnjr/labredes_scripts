\name{script_DEA}
\alias{script_DEA}
\title{Data Envelopment Analysis (DEA) for Efficiency Evaluation}
\description{
  This script reads a spreadsheet containing test data, applies DEA models to assess the efficiency of Decision-Making Units (DMUs), and saves the results in a new spreadsheet.
}

\usage{
  scriptDEA(base_dir, data_xlsx, final_table, input_vars, output_vars, sheets_nums, dmu_sheet)
}

\arguments{
  \item{base_dir}{Path to the base directory where test files are stored.}
  \item{data_xlsx}{Path to the input Excel file with test data.}
  \item{final_table}{Path to save the output Excel file.}
  \item{input_vars}{A vector of input variable names.}
  \item{output_vars}{A vector of output variable names.}
  \item{sheets_nums}{Vector of sheet indices containing test data.}
  \item{dmu_sheet}{Sheet index containing DMU descriptions.}
}

\details{
  The script performs the following tasks:
  \itemize{
    \item Reads test data from an Excel file.
    \item Applies DEA models using the `Benchmarking` package.
    \item Generates efficiency scores for DMUs.
    \item Saves efficiency results in a formatted Excel file.
  }
}

\author{
  Marcondes Junior \email{github.com/marcondesnjr}
}


\seealso{
  \code{\link[Benchmarking]{dea}}, \code{\link[Benchmarking]{sdea}}, \code{\link[openxlsx]{loadWorkbook}}
}
