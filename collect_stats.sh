#!/bin/bash

# This script collects performance statistics from output files located in the 'data' directory.
# It processes files with the '_out.txt' suffix and extracts specific metrics:
# - Requests per second
# - Time per request
# - Transfer rate
# - Time taken for tests
# Then, it extracts the time series data from the corresponding CSV files.
# The extracted metrics are saved into corresponding 'stats' subdirectories within the same directory as the input files.
# Each directory can only contain a sigle output file and a single CSV file, or the data will be overwritten.
# Author: Marcondes Junior
# github.com/marcondesnjr

FILE_LIST=$(find data -type f -name '*_out.txt') # Will not work witch spaces on paths :v
for file in $FILE_LIST; do
    DIR_NAME=$(dirname "$file")
    echo
    basename "$file"
    mkdir -p "$DIR_NAME/stats"

    echo -n 'Requests per second: '
    grep 'Requests per second' "$file" | awk '{print $4}' | tee "$DIR_NAME/stats/req_per_sec.txt"

    echo -n 'Time per request: '
    grep 'concurrent request' "$file" | awk '{print $4}' | tee "$DIR_NAME/stats/time_per_req.txt"

    echo -n 'Transfer rate: '
    grep 'Transfer rate' "$file" | awk '{print $3}' | tee "$DIR_NAME/stats/transfer_rate.txt"

    echo -n 'Time taken for tests: '
    grep 'tests' "$file" | awk '{print $5}' | tee "$DIR_NAME/stats/time_taken_for_tests.txt"

    echo -n 'Saving Time Series: '
    time_s=$(find "$DIR_NAME" -type f -name '*.csv')
    tail -n +2 "$time_s" | awk -F ',' '{print $2}' >"$DIR_NAME/stats/timeseries.txt"
    echo 'Done'

done
