#!/usr/bin/env Rscript

# Targeted Interpolation Script
# This script performs interpolation only on specific years and variables to avoid memory issues

cat("Targeted Interpolation for Census Data\n")
cat("====================================\n\n")

# Load required packages
suppressPackageStartupMessages({
  library(tidyverse)
  library(duckdb)
  library(zoo)  # For na.approx
  library(parallel)
  library(future)
  library(future.apply)
  library(progressr)
})

# Set up parallel processing
num_cores <- 2  # Use a small number to avoid memory issues
cat("Using", num_cores, "cores for parallel processing\n")

# Enable progress reporting
options(progressr.enable = TRUE)
handlers(global = TRUE)
handlers("progress")

# Function to interpolate data for one county
interpolate_county <- function(county_data, vars_to_interpolate) {
  # Skip if no data
  if (nrow(county_data) <= 1) {
    return(county_data)
  }
  
  # Sort by year
  county_data <- county_data %>% arrange(year)
  
  # Store original values for counting
  original_values <- list()
  for (var in vars_to_interpolate) {
    original_values[[var]] <- county_data[[var]]
  }
  
  # Interpolate each variable
  for (var in vars_to_interpolate) {
    # Only interpolate if there are some non-NA values
    if (sum(!is.na(county_data[[var]])) > 1) {
      county_data[[var]] <- zoo::na.approx(county_data[[var]], na.rm = FALSE)
    }
  }
  
  # Add flags for interpolated values
  interpolation_count <- 0
  for (var in vars_to_interpolate) {
    flag_name <- paste0(var, "_interpolated")
    county_data[[flag_name]] <- is.na(original_values[[var]]) & !is.na(county_data[[var]])
    interpolation_count <- interpolation_count + county_data[[flag_name]]
  }
  
  # Set the interpolation flags
  county_data$interpolation_count <- interpolation_count
  county_data$interpolation_used <- interpolation_count > 0
  
  return(county_data)
}

# Function to interpolate all counties with progress tracking
interpolate_all_counties <- function(data, vars_to_interpolate) {
  # Get unique counties
  counties <- unique(data$GEOID)
  cat("Interpolating data for", length(counties), "counties...\n")
  
  # Set up parallel processing
  future::plan(future::multisession, workers = num_cores)
  on.exit(future::plan(future::sequential))
  
  # Set up progress tracking
  p <- progressr::progressor(steps = length(counties))
  
  # Process each county in parallel
  result <- future.apply::future_lapply(counties, function(county_id) {
    # Get data for this county
    county_data <- data %>% filter(GEOID == county_id)
    
    # Interpolate
    interpolated <- interpolate_county(county_data, vars_to_interpolate)
    
    # Update progress
    p(message = sprintf("County %s", county_id))
    
    return(interpolated)
  }, future.seed = TRUE)
  
  # Combine results
  bind_rows(result)
}

# Main execution
cat("Connecting to database...\n")
con <- dbConnect(duckdb(), "us_county_sdoh_data.duckdb")

# Define variables to interpolate - focusing on the most important ones with missing values
vars_to_interpolate <- c(
  "median_household_income",
  "poverty_rate",
  "unemployment_rate",
  "uninsured_pct"
)

cat("Will interpolate the following variables:", paste(vars_to_interpolate, collapse=", "), "\n")

# Get data for years with missing values (2020, 2023)
target_years <- c(2019, 2020, 2021, 2022, 2023, 2024)
cat("Focusing on years", paste(target_years, collapse=", "), "\n")

# Get the data to interpolate
data_to_interpolate <- dbGetQuery(con, sprintf("
  SELECT GEOID, NAME, year, data_source, data_quality, data_vintage, %s
  FROM county_sdoh_data
  WHERE year IN (%s)
  ORDER BY GEOID, year
", paste(vars_to_interpolate, collapse=", "), paste(target_years, collapse=",")))

cat("Retrieved", nrow(data_to_interpolate), "rows for interpolation\n")

# If no data to interpolate, exit
if (nrow(data_to_interpolate) == 0) {
  cat("No data to interpolate. Exiting.\n")
  dbDisconnect(con)
  quit(status = 0)
}

# Add interpolation columns if not present
for (var in vars_to_interpolate) {
  flag_name <- paste0(var, "_interpolated")
  if (!(flag_name %in% names(data_to_interpolate))) {
    data_to_interpolate[[flag_name]] <- FALSE
  }
}

if (!("interpolation_count" %in% names(data_to_interpolate))) {
  data_to_interpolate$interpolation_count <- 0
}

if (!("interpolation_used" %in% names(data_to_interpolate))) {
  data_to_interpolate$interpolation_used <- FALSE
}

# Print missing value counts before interpolation
for (var in vars_to_interpolate) {
  missing_count <- sum(is.na(data_to_interpolate[[var]]))
  missing_pct <- round(100 * missing_count / nrow(data_to_interpolate), 1)
  cat(sprintf("Variable %s has %d missing values (%.1f%%)\n", 
              var, missing_count, missing_pct))
}

# Perform interpolation
cat("\nStarting interpolation...\n")
interpolated_data <- interpolate_all_counties(data_to_interpolate, vars_to_interpolate)

# Print results after interpolation
for (var in vars_to_interpolate) {
  missing_before <- sum(is.na(data_to_interpolate[[var]]))
  missing_after <- sum(is.na(interpolated_data[[var]]))
  filled <- missing_before - missing_after
  
  cat(sprintf("Variable %s: %d values interpolated (%.1f%% of missing filled)\n", 
              var, filled, if(missing_before > 0) round(100 * filled / missing_before, 1) else 0))
}

# Update the database with interpolated values
cat("\nUpdating database with interpolated values...\n")

# Use a transaction for safety
dbExecute(con, "BEGIN TRANSACTION")

# Update each row
update_count <- 0
for (i in 1:nrow(interpolated_data)) {
  row <- interpolated_data[i,]
  
  # Skip if no interpolation happened for this row
  if (!row$interpolation_used) {
    next
  }
  
  # Build update statement with all interpolated variables
  update_cols <- c()
  for (var in vars_to_interpolate) {
    flag_name <- paste0(var, "_interpolated")
    if (row[[flag_name]]) {
      update_cols <- c(update_cols, sprintf("%s = %s", var, 
                                          if(is.na(row[[var]])) "NULL" else row[[var]]))
    }
  }
  
  # Add interpolation flags
  update_cols <- c(update_cols, 
                  sprintf("interpolation_used = %s", if(row$interpolation_used) "TRUE" else "FALSE"),
                  sprintf("interpolation_count = %d", row$interpolation_count))
  
  # Only update if we have changes
  if (length(update_cols) > 0) {
    update_sql <- sprintf("
      UPDATE county_sdoh_data
      SET %s
      WHERE GEOID = '%s' AND year = %d
    ", paste(update_cols, collapse=", "), row$GEOID, row$year)
    
    dbExecute(con, update_sql)
    update_count <- update_count + 1
  }
}

# Commit the transaction
dbExecute(con, "COMMIT")

cat("Updated", update_count, "rows in the database\n")

# Verify the updates
verification <- dbGetQuery(con, "
  SELECT 
    SUM(CASE WHEN interpolation_used = TRUE THEN 1 ELSE 0 END) as interpolated_rows,
    COUNT(*) as total_rows,
    ROUND(100.0 * SUM(CASE WHEN interpolation_used = TRUE THEN 1 ELSE 0 END) / COUNT(*), 1) as pct_interpolated
  FROM county_sdoh_data
")

cat("\nInterpolation summary:\n")
cat(sprintf("- %d of %d rows have interpolated values (%.1f%%)\n", 
           verification$interpolated_rows, verification$total_rows, verification$pct_interpolated))

# Get remaining missing value counts
missing_counts <- dbGetQuery(con, sprintf("
  SELECT 
    %s
  FROM (
    SELECT 
      %s
    FROM county_sdoh_data
  )
", 
paste(sprintf("SUM(CASE WHEN %s IS NULL THEN 1 ELSE 0 END) as %s_missing", 
              vars_to_interpolate, vars_to_interpolate), collapse=", "),
paste(sprintf("%s", vars_to_interpolate), collapse=", ")))

cat("\nRemaining missing values:\n")
for (var in vars_to_interpolate) {
  missing_col <- paste0(var, "_missing")
  cat(sprintf("- %s: %d values still missing\n", var, missing_counts[[missing_col]]))
}

# Close the database connection
dbDisconnect(con)

cat("\nTargeted interpolation completed successfully!\n")