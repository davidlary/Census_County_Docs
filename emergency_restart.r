#!/usr/bin/env Rscript

# EMERGENCY RESTART SCRIPT - MINIMAL VERSION
# This script runs a minimal version of the pipeline without interpolation

cat("EMERGENCY RESTART - Minimal Pipeline Version\n")
cat("==========================================\n\n")

# Load required packages
suppressPackageStartupMessages({
  library(tidyverse)
  library(duckdb)
  library(tidycensus)
})

# Set up logging
log_file <- file.path("logs", paste0("emergency_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log"))
cat("Log will be saved to:", log_file, "\n")

# Set up connection to database
db_path <- "us_county_sdoh_data.duckdb"
cat("Connecting to database:", db_path, "\n")

tryCatch({
  # Try to connect to the database
  con <- dbConnect(duckdb(), db_path)
  
  # Check if main table exists
  if (dbExistsTable(con, "county_sdoh_data")) {
    cat("Found existing county_sdoh_data table in database\n")
    
    # Get years available
    years_query <- dbGetQuery(con, "
      SELECT MIN(year) as min_year, MAX(year) as max_year, COUNT(DISTINCT year) as year_count
      FROM county_sdoh_data
    ")
    
    cat("Database contains data from", years_query$min_year, "to", years_query$max_year, 
        "(", years_query$year_count, "years)\n")
    
    # Get county count
    county_query <- dbGetQuery(con, "
      SELECT COUNT(DISTINCT GEOID) as county_count
      FROM county_sdoh_data
    ")
    
    cat("Database contains", county_query$county_count, "counties\n")
    
    # Skip directly to creating the views and documentation
    cat("\nSkipping data processing and completing pipeline...\n")
    cat("Creating database views...\n")
    
    # Create views
    dbExecute(con, "
      CREATE OR REPLACE VIEW latest_county_data AS
      SELECT * FROM county_sdoh_data
      WHERE (GEOID, year) IN (
        SELECT GEOID, MAX(year) as max_year
        FROM county_sdoh_data
        GROUP BY GEOID
      )
    ")
    
    dbExecute(con, "
      CREATE OR REPLACE VIEW county_time_series AS
      SELECT *
      FROM county_sdoh_data
      ORDER BY GEOID, year
    ")
    
    # Create a data dictionary if it doesn't exist
    if (!dbExistsTable(con, "data_dictionary")) {
      cat("Creating data dictionary...\n")
      
      # Get column names from main table
      cols <- dbGetQuery(con, "PRAGMA table_info('county_sdoh_data')")
      
      # Create a basic dictionary
      dict <- data.frame(
        column_name = cols$name,
        type = cols$type,
        description = paste("Column", cols$name)
      )
      
      # Write to database
      dbWriteTable(con, "data_dictionary", dict, overwrite = TRUE)
    }
    
    # Close connection
    dbDisconnect(con)
    
    cat("\nCreating README file...\n")
    
    # Create a README file
    readme <- c(
      "# Social Determinants of Health County-Level Dataset",
      "",
      paste("Generated on:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
      "",
      "## Overview",
      "",
      "This dataset combines county-level data on social determinants of health from multiple authoritative sources.",
      "",
      "## Usage",
      "",
      "The data is stored in a DuckDB database file (us_county_sdoh_data.duckdb).",
      "You can access it using DuckDB with R, Python, or the DuckDB CLI.",
      "",
      "Example in R:",
      "```r",
      "library(DBI)",
      "library(duckdb)",
      "con <- dbConnect(duckdb(), 'us_county_sdoh_data.duckdb')",
      "counties <- dbGetQuery(con, 'SELECT * FROM latest_county_data')",
      "dbDisconnect(con)",
      "```"
    )
    
    writeLines(readme, "README.md")
    
    cat("\nEmergency restart completed successfully!\n")
    cat("Database and documentation are ready to use.\n")
    cat("Full pipeline with interpolation can be run later if needed.\n")
    
  } else {
    cat("ERROR: county_sdoh_data table not found in database\n")
    cat("Cannot complete emergency restart without existing data.\n")
    cat("Try running the standard pipeline with reduced dataset instead.\n")
  }
  
}, error = function(e) {
  cat("ERROR connecting to database:", conditionMessage(e), "\n")
  cat("Cannot complete emergency restart.\n")
})

cat("\nEmergency restart script completed.\n")