#!/usr/bin/env Rscript

# Census Data Pipeline Status Checker
# This script checks the current state of the pipeline execution and provides a status report

cat("Checking Census Data Pipeline Status...\n\n")

# Function to check if a package is installed
is_pkg_installed <- function(pkg) {
  return(requireNamespace(pkg, quietly = TRUE))
}

# Function to check if a file exists and get its info
check_file <- function(filepath, description) {
  if (file.exists(filepath)) {
    file_info <- file.info(filepath)
    size_mb <- round(file_info$size / (1024 * 1024), 2)
    modified <- format(file_info$mtime, "%Y-%m-%d %H:%M:%S")
    cat(sprintf("✓ %s: %s (%.2f MB, last modified: %s)\n", 
                description, filepath, size_mb, modified))
    return(TRUE)
  } else {
    cat(sprintf("✗ %s not found: %s\n", description, filepath))
    return(FALSE)
  }
}

# Function to check log files
check_logs <- function(log_dir = "logs") {
  if (!dir.exists(log_dir)) {
    cat(sprintf("✗ Log directory not found: %s\n", log_dir))
    return(NULL)
  }
  
  log_files <- list.files(log_dir, pattern = "\\.log$", full.names = TRUE)
  
  if (length(log_files) == 0) {
    cat("✗ No log files found in logs directory\n")
    return(NULL)
  }
  
  # Get file info for all logs
  log_info <- file.info(log_files)
  log_info$filename <- rownames(log_info)
  
  # Sort by modification time (most recent first)
  log_info <- log_info[order(log_info$mtime, decreasing = TRUE), ]
  
  # Get most recent log
  most_recent <- log_info[1, ]
  
  cat(sprintf("✓ Found %d log files. Most recent: %s (modified: %s)\n", 
              length(log_files), 
              basename(most_recent$filename),
              format(most_recent$mtime, "%Y-%m-%d %H:%M:%S")))
  
  # Check log content for progress indicators
  if (file.exists(most_recent$filename)) {
    log_content <- readLines(most_recent$filename)
    
    # Look for key progress indicators
    has_started <- any(grepl("SOCIAL DETERMINANTS OF HEALTH DATA PIPELINE STARTED", log_content, fixed = TRUE))
    has_completed <- any(grepl("SOCIAL DETERMINANTS OF HEALTH DATA PIPELINE COMPLETED", log_content, fixed = TRUE))
    has_error <- any(grepl("ERROR", log_content, fixed = TRUE))
    
    # Extract step information
    steps <- c(
      "BUILDING EXTENDED VARIABLE CROSSWALK",
      "FETCHING DATA FROM MULTIPLE SOURCES",
      "PROCESSING AND COMBINING DATA",
      "VALIDATION AND EXAMPLES",
      "GENERATING DOCUMENTATION",
      "PREPARING COUNTY BOUNDARY SHAPEFILES"
    )
    
    completed_steps <- 0
    for (step in steps) {
      if (any(grepl(step, log_content, fixed = TRUE))) {
        completed_steps <- completed_steps + 1
      }
    }
    
    # Return status summary
    return(list(
      filename = most_recent$filename,
      has_started = has_started,
      has_completed = has_completed,
      has_error = has_error,
      completed_steps = completed_steps,
      total_steps = length(steps),
      content = log_content
    ))
  }
  
  return(NULL)
}

# Function to check database
check_database <- function(db_path = "us_county_sdoh_data.duckdb") {
  if (!file.exists(db_path)) {
    cat(sprintf("✗ Database not found: %s\n", db_path))
    return(NULL)
  }
  
  # Check if DuckDB package is available
  if (!is_pkg_installed("DuckDB")) {
    cat("✗ Cannot check database: DuckDB package not installed\n")
    return(NULL)
  }
  
  # Try to connect and get basic info
  tryCatch({
    library(DBI)
    library(duckdb)
    
    con <- dbConnect(duckdb(), db_path)
    
    # Get tables
    tables <- dbListTables(con)
    cat(sprintf("✓ Database contains %d tables/views\n", length(tables)))
    
    # Check for main table
    if ("county_sdoh_data" %in% tables) {
      # Count records
      record_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM county_sdoh_data")$count
      
      # Count unique counties
      county_count <- dbGetQuery(con, "SELECT COUNT(DISTINCT GEOID) as count FROM county_sdoh_data")$count
      
      # Get year range
      year_range <- dbGetQuery(con, "SELECT MIN(year) as min_year, MAX(year) as max_year FROM county_sdoh_data")
      
      cat(sprintf("✓ Main table contains %d records for %d counties\n", record_count, county_count))
      cat(sprintf("✓ Data spans from %d to %d\n", year_range$min_year, year_range$max_year))
      
      result <- list(
        tables = tables,
        record_count = record_count,
        county_count = county_count,
        min_year = year_range$min_year,
        max_year = year_range$max_year
      )
      
      # Close the connection
      dbDisconnect(con)
      
      return(result)
    } else {
      cat("✗ Main 'county_sdoh_data' table not found in database\n")
      dbDisconnect(con)
      return(NULL)
    }
  }, error = function(e) {
    cat(sprintf("✗ Error checking database: %s\n", conditionMessage(e)))
    return(NULL)
  })
}

# Function to check cache directory
check_cache <- function(cache_dir = "data/cache") {
  if (!dir.exists(cache_dir)) {
    cat(sprintf("✗ Cache directory not found: %s\n", cache_dir))
    return(NULL)
  }
  
  cache_files <- list.files(cache_dir, recursive = TRUE)
  
  if (length(cache_files) == 0) {
    cat("✗ No files found in cache directory\n")
    return(NULL)
  }
  
  # Calculate total size
  total_size <- 0
  for (file in list.files(cache_dir, recursive = TRUE, full.names = TRUE)) {
    if (file.exists(file)) {
      total_size <- total_size + file.info(file)$size
    }
  }
  
  total_size_mb <- round(total_size / (1024 * 1024), 2)
  
  cat(sprintf("✓ Cache contains %d files (%.2f MB)\n", length(cache_files), total_size_mb))
  
  # Group cache files by type
  census_files <- grep("census|acs|pep|decennial", cache_files, value = TRUE)
  nhgis_files <- grep("nhgis", cache_files, value = TRUE)
  places_files <- grep("places", cache_files, value = TRUE)
  life_exp_files <- grep("life|expectancy|ihme", cache_files, ignore.case = TRUE, value = TRUE)
  
  return(list(
    count = length(cache_files),
    size_mb = total_size_mb,
    census_count = length(census_files),
    nhgis_count = length(nhgis_files),
    places_count = length(places_files),
    life_exp_count = length(life_exp_files)
  ))
}

# Function to check API credentials
check_credentials <- function() {
  # Check Census API key
  census_api_key <- Sys.getenv("CENSUS_API_KEY")
  if (census_api_key != "") {
    cat(sprintf("✓ Census API key found in environment (length: %d)\n", nchar(census_api_key)))
  } else {
    cat("✗ Census API key not found in environment\n")
  }
  
  # Check IPUMS credentials
  ipums_username <- Sys.getenv("IPUMS_USERNAME")
  ipums_password <- Sys.getenv("IPUMS_PASSWORD")
  
  if (ipums_username != "" && ipums_password != "") {
    cat("✓ IPUMS credentials found in environment\n")
  } else {
    cat("✗ IPUMS credentials not found in environment\n")
    
    # Check for credentials file
    creds_file <- file.path(Sys.getenv("HOME"), ".ipums_credentials/config")
    if (file.exists(creds_file)) {
      cat("✓ IPUMS credentials file found at ~/.ipums_credentials/config\n")
    } else {
      cat("✗ IPUMS credentials file not found at ~/.ipums_credentials/config\n")
    }
  }
}

# Run all checks
cat("=== SYSTEM CHECKS ===\n")

# Check for required packages
required_packages <- c(
  "tidyverse", "tidycensus", "jsonlite", "duckdb", "ipumsr", "tigris", "sf",
  "zoo", "httr", "parallel", "foreach", "doParallel", "future", "future.apply",
  "progressr", "digest"
)

missing_packages <- required_packages[!sapply(required_packages, function(pkg) is_pkg_installed(pkg))]

if (length(missing_packages) == 0) {
  cat("✓ All required packages are installed\n")
} else {
  cat(sprintf("✗ Missing %d required packages: %s\n", 
              length(missing_packages), 
              paste(missing_packages, collapse = ", ")))
}

# Check API credentials
cat("\n=== CREDENTIAL CHECKS ===\n")
check_credentials()

# Check file structure
cat("\n=== FILE CHECKS ===\n")

# Check main pipeline script
main_script_exists <- check_file("main_extended.r", "Main pipeline script")

# Check data directories
if (dir.exists("data")) {
  cat("✓ Data directory exists\n")
  
  # Check subdirectories
  subdirs <- c("cache", "cdc_places", "nhgis", "shapefiles")
  for (subdir in subdirs) {
    full_path <- file.path("data", subdir)
    if (dir.exists(full_path)) {
      file_count <- length(list.files(full_path, recursive = TRUE))
      cat(sprintf("  ✓ %s directory exists with %d files\n", subdir, file_count))
    } else {
      cat(sprintf("  ✗ %s directory not found\n", subdir))
    }
  }
} else {
  cat("✗ Data directory not found\n")
}

# Check output directory
if (dir.exists("output")) {
  cat("✓ Output directory exists\n")
  output_files <- list.files("output", recursive = TRUE)
  cat(sprintf("  Found %d files in output directory\n", length(output_files)))
} else {
  cat("✗ Output directory not found\n")
}

# Check database file
db_info <- check_database()

# Check README
check_file("README.md", "README documentation")

# Check logs
cat("\n=== LOG ANALYSIS ===\n")
log_status <- check_logs()

if (!is.null(log_status)) {
  if (log_status$has_completed) {
    cat("✓ Pipeline has COMPLETED according to the most recent log\n")
  } else if (log_status$has_error) {
    cat("✗ Pipeline has ERRORS in the most recent log\n")
    
    # Extract error messages
    error_lines <- grep("ERROR", log_status$content, value = TRUE)
    if (length(error_lines) > 0) {
      cat("\nError messages found:\n")
      for (i in 1:min(3, length(error_lines))) {
        cat("  - ", error_lines[i], "\n")
      }
      if (length(error_lines) > 3) {
        cat(sprintf("  ... and %d more errors\n", length(error_lines) - 3))
      }
    }
  } else if (log_status$has_started) {
    if (log_status$completed_steps > 0) {
      cat(sprintf("⟳ Pipeline is IN PROGRESS (%d of %d steps completed)\n", 
                  log_status$completed_steps, log_status$total_steps))
      
      # Get last few lines for progress
      progress_indicator <- tail(log_status$content, 10)
      progress_text <- grep("Progress|Completed|Started", progress_indicator, value = TRUE)
      
      if (length(progress_text) > 0) {
        cat("\nRecent progress indicators:\n")
        for (line in progress_text) {
          cat("  ", line, "\n")
        }
      }
    } else {
      cat("⟳ Pipeline has STARTED but no steps completed yet\n")
    }
  } else {
    cat("? Could not determine pipeline status from log\n")
  }
}

# Check cache
cat("\n=== CACHE ANALYSIS ===\n")
cache_info <- check_cache()

if (!is.null(cache_info)) {
  cat(sprintf("Cache contains:\n"))
  cat(sprintf("  - %d Census/ACS/PEP files\n", cache_info$census_count))
  cat(sprintf("  - %d NHGIS files\n", cache_info$nhgis_count))
  cat(sprintf("  - %d CDC PLACES files\n", cache_info$places_count))
  cat(sprintf("  - %d Life Expectancy files\n", cache_info$life_exp_count))
}

# Calculate overall status
cat("\n=== OVERALL STATUS ===\n")

if (!is.null(db_info) && file.exists("README.md") && !is.null(log_status) && log_status$has_completed) {
  cat("✅ Pipeline appears to have COMPLETED SUCCESSFULLY\n")
  cat(sprintf("   Database contains %d records for %d counties from %d to %d\n", 
              db_info$record_count, db_info$county_count, db_info$min_year, db_info$max_year))
} else if (!is.null(log_status) && log_status$has_started && !log_status$has_completed && !log_status$has_error) {
  cat("⟳ Pipeline appears to be IN PROGRESS\n")
} else if (!is.null(log_status) && log_status$has_error) {
  cat("❌ Pipeline has ERRORS and may need to be fixed and restarted\n")
} else if (!main_script_exists) {
  cat("❌ Pipeline is NOT READY - main script missing\n")
} else {
  cat("❔ Pipeline status is UNKNOWN\n")
}

# Provide next steps
cat("\n=== SUGGESTED NEXT STEPS ===\n")

if (!is.null(db_info) && !is.null(log_status) && log_status$has_completed) {
  cat("The pipeline has completed. You can:\n")
  cat("1. Query the database using: Rscript -e 'con <- DBI::dbConnect(duckdb::duckdb(), \"us_county_sdoh_data.duckdb\"); data <- DBI::dbGetQuery(con, \"SELECT * FROM county_sdoh_data LIMIT 10\"); print(data); DBI::dbDisconnect(con)'\n")
  cat("2. Run the pipeline again with the force update flag: Rscript main_extended.r --force-update\n")
  cat("3. Run example analyses: Rscript example_sdoh_analysis.r\n")
} else if (!is.null(log_status) && log_status$has_started && !log_status$has_completed && !log_status$has_error) {
  cat("The pipeline is currently running. You can:\n")
  cat("1. Wait for it to complete\n")
  cat("2. Check progress in the log file: tail -f", log_status$filename, "\n")
} else if (!is.null(log_status) && log_status$has_error) {
  cat("The pipeline has errors. You can:\n")
  cat("1. Check the full log file for details: less", log_status$filename, "\n")
  cat("2. Fix any issues and restart: Rscript main_extended.r\n")
  cat("3. Run with parallel processing: Rscript run_parallel_pipeline.r\n")
} else if (length(missing_packages) > 0) {
  cat("You need to install missing packages. Run:\n")
  cat("Rscript install_packages.r\n")
} else {
  cat("Start the pipeline with one of these commands:\n")
  cat("1. Standard run: Rscript main_extended.r\n")
  cat("2. Force update: Rscript main_extended.r --force-update\n")
  cat("3. Parallel run: Rscript run_parallel_pipeline.r\n")
}

cat("\nStatus check completed.\n")