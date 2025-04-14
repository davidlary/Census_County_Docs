#!/usr/bin/env Rscript

# Pipeline Monitor Script
# This script monitors the progress of the pipeline and provides a status report

cat("Census Data Pipeline Monitor\n")
cat("==========================\n\n")

# Process command line arguments
args <- commandArgs(trailingOnly = TRUE)
follow_log <- "--follow" %in% args || "-f" %in% args
live_mode <- "--live" %in% args || "-l" %in% args
show_errors <- "--errors" %in% args || "-e" %in% args

# Find the most recent log file
find_latest_log <- function() {
  log_dir <- "logs"
  if (!dir.exists(log_dir)) {
    cat("Logs directory not found\n")
    return(NULL)
  }
  
  log_files <- list.files(log_dir, pattern = "\\.log$", full.names = TRUE)
  if (length(log_files) == 0) {
    cat("No log files found\n")
    return(NULL)
  }
  
  # Get file info for all logs
  log_info <- file.info(log_files)
  log_info$filename <- row.names(log_info)
  
  # Sort by modification time (most recent first)
  log_info <- log_info[order(log_info$mtime, decreasing = TRUE), ]
  
  # Get most recent log
  most_recent <- log_info[1, ]
  
  cat("Most recent log file:", basename(most_recent$filename), "\n")
  cat("Last modified:", format(most_recent$mtime, "%Y-%m-%d %H:%M:%S"), "\n\n")
  
  return(most_recent$filename)
}

# Analyze log file content to extract progress information
analyze_log <- function(log_path) {
  if (!file.exists(log_path)) {
    cat("Log file not found:", log_path, "\n")
    return(NULL)
  }
  
  # Read log content
  log_content <- tryCatch({
    readLines(log_path)
  }, error = function(e) {
    cat("Error reading log file:", conditionMessage(e), "\n")
    return(character(0))
  })
  
  if (length(log_content) == 0) {
    cat("Log file is empty\n")
    return(NULL)
  }
  
  # Look for key progress indicators
  has_started <- any(grepl("SOCIAL DETERMINANTS OF HEALTH DATA PIPELINE STARTED", log_content, fixed = TRUE))
  has_completed <- any(grepl("SOCIAL DETERMINANTS OF HEALTH DATA PIPELINE COMPLETED", log_content, fixed = TRUE))
  has_error <- any(grepl("ERROR", log_content, fixed = TRUE))
  
  # Extract step information
  steps <- c(
    "BUILDING EXTENDED VARIABLE CROSSWALK" = FALSE,
    "FETCHING DATA FROM MULTIPLE SOURCES" = FALSE,
    "PROCESSING AND COMBINING DATA" = FALSE,
    "VALIDATION AND EXAMPLES" = FALSE,
    "GENERATING DOCUMENTATION" = FALSE,
    "PREPARING COUNTY BOUNDARY SHAPEFILES" = FALSE
  )
  
  for (step_name in names(steps)) {
    if (any(grepl(step_name, log_content, fixed = TRUE))) {
      steps[step_name] <- TRUE
    }
  }
  
  # Look for progress indicators
  progress_line <- grep("Progress: \\[", log_content, value = TRUE)
  progress_pct <- 0
  
  if (length(progress_line) > 0) {
    # Extract the progress bar from the last progress line
    last_progress <- tail(progress_line, 1)
    progress_bar <- sub(".*Progress: \\[(.*?)\\].*", "\\1", last_progress)
    
    # Calculate approximate percentage
    total_chars <- nchar(progress_bar)
    filled_chars <- sum(strsplit(progress_bar, "")[[1]] != ".")
    
    if (total_chars > 0) {
      progress_pct <- round(100 * filled_chars / total_chars)
    }
  }
  
  # Look for time estimates
  time_info <- NULL
  time_lines <- grep("elapsed|remaining|seconds|minutes", log_content, value = TRUE)
  if (length(time_lines) > 0) {
    time_info <- tail(time_lines, 3)
  }
  
  # Extract any errors
  errors <- character(0)
  if (has_error) {
    error_lines <- grep("ERROR", log_content, value = TRUE)
    errors <- tail(error_lines, min(5, length(error_lines)))
  }
  
  # Determine current step
  current_step <- NULL
  completed_steps <- sum(steps)
  
  if (has_completed) {
    current_step <- "COMPLETED"
  } else if (has_started) {
    for (i in rev(seq_along(steps))) {
      step_name <- names(steps)[i]
      if (steps[step_name]) {
        current_step <- step_name
        break
      }
    }
  }
  
  # Get last few lines for additional context
  recent_lines <- tail(log_content, min(10, length(log_content)))
  
  return(list(
    has_started = has_started,
    has_completed = has_completed,
    has_error = has_error,
    steps = steps,
    completed_steps = completed_steps,
    total_steps = length(steps),
    current_step = current_step,
    progress_pct = progress_pct,
    time_info = time_info,
    errors = errors,
    recent_lines = recent_lines,
    log_length = length(log_content)
  ))
}

# Display progress bar
display_progress_bar <- function(percent, width = 50) {
  filled <- round(width * percent / 100)
  bar <- paste0(
    "[", 
    paste0(rep("=", filled), collapse = ""),
    paste0(rep(" ", width - filled), collapse = ""),
    "] ",
    percent, "%"
  )
  return(bar)
}

# Display status report
display_status <- function(analysis) {
  if (is.null(analysis)) {
    cat("No status information available\n")
    return()
  }
  
  cat("Pipeline Status: ")
  if (analysis$has_completed) {
    cat("COMPLETED\n")
  } else if (analysis$has_error) {
    cat("ERROR\n")
  } else if (analysis$has_started) {
    cat("RUNNING\n")
  } else {
    cat("NOT STARTED or UNKNOWN\n")
  }
  
  cat("\nSteps Progress:\n")
  for (i in seq_along(analysis$steps)) {
    step_name <- names(analysis$steps)[i]
    status <- if (analysis$steps[step_name]) "✓" else " "
    
    # Highlight current step
    if (!is.null(analysis$current_step) && analysis$current_step == step_name) {
      cat(sprintf(" [%s] %s  <- CURRENT\n", status, step_name))
    } else {
      cat(sprintf(" [%s] %s\n", status, step_name))
    }
  }
  
  # Show overall progress
  if (analysis$has_started && !analysis$has_completed) {
    cat("\nOverall Progress: ", 
        round(100 * analysis$completed_steps / analysis$total_steps), 
        "% of steps completed\n", sep = "")
    
    # If we're in a specific step with progress percentage
    if (analysis$progress_pct > 0) {
      cat("Current Step Progress: ")
      cat(display_progress_bar(analysis$progress_pct), "\n")
    }
    
    # Show time information if available
    if (!is.null(analysis$time_info)) {
      cat("\nTime Information:\n")
      for (line in analysis$time_info) {
        cat(" ", line, "\n")
      }
    }
  }
  
  # Show errors if any and requested
  if (show_errors && length(analysis$errors) > 0) {
    cat("\nErrors Found:\n")
    for (error in analysis$errors) {
      cat(" ", error, "\n")
    }
  }
  
  # Show recent activity
  cat("\nRecent Activity:\n")
  for (line in tail(analysis$recent_lines, 5)) {
    # Skip progress bars in recent activity (they're too long)
    if (!grepl("Progress: \\[", line)) {
      cat(" ", line, "\n")
    }
  }
}

# Function to check database status
check_database <- function() {
  db_path <- "us_county_sdoh_data.duckdb"
  
  if (!file.exists(db_path)) {
    cat("\nDatabase Status: Not created yet\n")
    return()
  }
  
  # Try to load DuckDB package
  if (!requireNamespace("DuckDB", quietly = TRUE)) {
    cat("\nDatabase Status: File exists (", format(file.info(db_path)$size / 1024^2, digits = 2), " MB) but can't check contents (DuckDB package not available)\n", sep = "")
    return()
  }
  
  # Try to connect to database
  tryCatch({
    library(DBI)
    library(duckdb)
    
    con <- dbConnect(duckdb(), db_path)
    
    # Get tables
    tables <- dbListTables(con)
    cat("\nDatabase Status: Created with", length(tables), "tables/views\n")
    
    # Check for main table
    if ("county_sdoh_data" %in% tables) {
      # Count records
      counts <- dbGetQuery(con, "
        SELECT 
          COUNT(*) as total_records,
          COUNT(DISTINCT GEOID) as unique_counties,
          MIN(year) as min_year,
          MAX(year) as max_year
        FROM county_sdoh_data
      ")
      
      cat(sprintf("- Main table: %d records for %d counties from %d to %d\n", 
                  counts$total_records, counts$unique_counties, 
                  counts$min_year, counts$max_year))
    }
    
    # Close connection
    dbDisconnect(con)
  }, error = function(e) {
    cat("\nDatabase Status: File exists but error connecting:", conditionMessage(e), "\n")
  })
}

# Main monitoring function
monitor_pipeline <- function() {
  log_path <- find_latest_log()
  
  if (is.null(log_path)) {
    return()
  }
  
  # Initial analysis
  analysis <- analyze_log(log_path)
  display_status(analysis)
  
  # Check database status
  check_database()
  
  # Follow log file if requested
  if (follow_log) {
    cat("\nFollowing log file. Press Ctrl+C to stop...\n")
    
    last_size <- file.info(log_path)$size
    last_analysis <- analysis
    
    # Keep checking for changes
    while (TRUE) {
      # Wait a bit
      Sys.sleep(2)
      
      # Check if file changed
      current_size <- file.info(log_path)$size
      
      if (current_size != last_size) {
        # Clear screen and show updated status
        cat("\014")  # Form feed character to clear screen
        cat("Census Data Pipeline Monitor (LIVE MODE)\n")
        cat("===================================\n\n")
        
        analysis <- analyze_log(log_path)
        if (!identical(analysis, last_analysis)) {
          display_status(analysis)
          check_database()
          cat("\nLast updated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
        }
        
        last_size <- current_size
        last_analysis <- analysis
      }
    }
  }
}

# Real-time monitor in a loop
if (live_mode) {
  cat("Starting live monitoring mode. Press Ctrl+C to stop...\n\n")
  
  while (TRUE) {
    # Clear screen
    cat("\014")  # Form feed character to clear screen
    cat("Census Data Pipeline Monitor (LIVE MODE)\n")
    cat("===================================\n\n")
    
    # Show status
    monitor_pipeline()
    
    cat("\nLast updated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
    cat("Press Ctrl+C to stop monitoring\n")
    
    # Wait before checking again
    Sys.sleep(5)
  }
} else {
  # One-time monitoring
  monitor_pipeline()
}

cat("\nMonitor complete.\n")