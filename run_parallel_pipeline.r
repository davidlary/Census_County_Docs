#!/usr/bin/env Rscript

# Enhanced Census Data Pipeline with Parallel Processing
# This script runs the enhanced pipeline with parallel processing

# Set up logging
logs_dir <- "logs"
if (!dir.exists(logs_dir)) {
  dir.create(logs_dir, showWarnings = FALSE, recursive = TRUE)
}
log_file <- file.path(logs_dir, paste0("parallel_pipeline_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log"))

cat("Starting parallel pipeline. Log will be saved to:", log_file, "\n")

# Record start time for overall benchmarking
overall_start_time <- Sys.time()

# Function to run a command and time it
run_timed <- function(description, command) {
  cat("\n==================================================\n")
  cat("STEP:", description, "\n")
  cat("==================================================\n")
  
  # Record start time
  start_time <- Sys.time()
  
  # Run the command
  result <- tryCatch({
    command()
  }, error = function(e) {
    cat("ERROR:", conditionMessage(e), "\n")
    NULL
  })
  
  # Calculate elapsed time
  end_time <- Sys.time()
  elapsed <- difftime(end_time, start_time, units = "secs")
  
  cat("\nCompleted in", format(elapsed, digits = 2), "seconds\n")
  
  return(list(
    result = result,
    elapsed = elapsed
  ))
}

# 1. Clear caches
run_timed("Clear all caches", function() {
  source("clear_cache.r")
})

# 2. Install required packages if needed
required_packages <- c(
  "tidyverse", "tidycensus", "jsonlite", "duckdb", "ipumsr", "tigris", "sf",
  "zoo", "httr", "parallel", "foreach", "doParallel", "future", "future.apply",
  "progressr", "digest"
)

missing_packages <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]

if (length(missing_packages) > 0) {
  run_timed("Install missing packages", function() {
    source("install_parallel_packages.r")
  })
} else {
  cat("\nAll required packages are already installed.\n")
}

# 3. Run the main pipeline with parallel processing
result <- run_timed("Run main extended pipeline with parallel processing", function() {
  # Automatically detect optimal number of cores
  num_cores <- max(1, parallel::detectCores() - 1)
  
  # Set variables to pass to main script
  parallel_enabled <- TRUE
  parallel_cores <- num_cores
  parallel_strategy <- "multisession"
  
  # Set the variables in global environment so main_extended.r can access them
  assign("PARALLEL_ENABLED", parallel_enabled, envir = .GlobalEnv)
  assign("PARALLEL_CORES", parallel_cores, envir = .GlobalEnv)
  assign("PARALLEL_STRATEGY", parallel_strategy, envir = .GlobalEnv)
  
  cat("Parallel processing enabled with", parallel_cores, "cores using", parallel_strategy, "strategy\n")
  
  # Run the main script
  source("main_extended.r")
})

# Calculate total elapsed time
overall_end_time <- Sys.time()
overall_elapsed <- difftime(overall_end_time, overall_start_time, units = "secs")

cat("\n==================================================\n")
cat("PIPELINE COMPLETED\n")
cat("==================================================\n")
cat("Total execution time:", format(overall_elapsed, digits = 2), "seconds\n")

# Print a summary of the generated data
cat("\nChecking generated data...\n")

run_timed("Analyze generated data", function() {
  # Try to connect to the database
  tryCatch({
    con <- DBI::dbConnect(duckdb::duckdb(), "us_county_sdoh_data.duckdb")
    
    # Get table list
    tables <- DBI::dbListTables(con)
    cat("Database contains", length(tables), "tables/views:", paste(tables, collapse=", "), "\n")
    
    # Count records in main table
    if ("county_sdoh_data" %in% tables) {
      count_query <- "SELECT COUNT(*) as record_count FROM county_sdoh_data"
      count_result <- DBI::dbGetQuery(con, count_query)
      cat("Main table contains", count_result$record_count, "records\n")
      
      # Count by year
      year_query <- "SELECT year, COUNT(*) as record_count FROM county_sdoh_data GROUP BY year ORDER BY year"
      year_counts <- DBI::dbGetQuery(con, year_query)
      cat("Records by year:\n")
      print(year_counts)
      
      # Count variables
      var_query <- "SELECT COUNT(*) as column_count FROM information_schema.columns WHERE table_name = 'county_sdoh_data'"
      var_result <- DBI::dbGetQuery(con, var_query)
      cat("Number of columns:", var_result$column_count, "\n")
    } else {
      cat("Main table 'county_sdoh_data' not found in database.\n")
    }
    
    # Close connection
    DBI::dbDisconnect(con)
  }, error = function(e) {
    cat("Error connecting to database:", conditionMessage(e), "\n")
  })
})

cat("\nParallel pipeline completed successfully! Results saved to database.\n")
cat("You can now query the data using DuckDB or analyze with other tools.\n")
cat("Log file:", log_file, "\n")