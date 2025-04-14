#!/usr/bin/env Rscript

# Pipeline Fix and Restart Tool
# This script helps diagnose and fix issues with the pipeline, then restart from the point of failure

cat("Census Data Pipeline Fix & Restart Tool\n")
cat("=====================================\n\n")

# Process command line arguments
args <- commandArgs(trailingOnly = TRUE)
force_restart <- "--force" %in% args || "-f" %in% args
skip_interpolation <- "--skip-interpolation" %in% args || "-s" %in% args
sequential_mode <- "--sequential" %in% args || "-q" %in% args
use_parallel <- "--parallel" %in% args || "-p" %in% args

# Analyze the last run to determine what went wrong
analyze_last_run <- function() {
  log_dir <- "logs"
  if (!dir.exists(log_dir)) {
    cat("No logs directory found. Cannot analyze previous runs.\n")
    return(list(runnable = FALSE))
  }
  
  log_files <- list.files(log_dir, pattern = "\\.log$", full.names = TRUE)
  if (length(log_files) == 0) {
    cat("No log files found. No previous runs to analyze.\n")
    return(list(runnable = FALSE))
  }
  
  # Find most recent log
  log_info <- file.info(log_files)
  log_info$filename <- row.names(log_info)
  log_info <- log_info[order(log_info$mtime, decreasing = TRUE), ]
  most_recent <- log_info[1, ]
  
  cat("Analyzing most recent log:", basename(most_recent$filename), "\n")
  cat("Last modified:", format(most_recent$mtime, "%Y-%m-%d %H:%M:%S"), "\n\n")
  
  # Check if it's too old (more than 1 day)
  age_days <- as.numeric(difftime(Sys.time(), most_recent$mtime, units = "days"))
  if (age_days > 1 && !force_restart) {
    cat("WARNING: Most recent log is", round(age_days, 1), "days old.\n")
    cat("This suggests the pipeline was run a while ago.\n")
    cat("Use --force to analyze and restart anyway.\n")
    return(list(runnable = FALSE))
  }
  
  # Read log content
  log_content <- tryCatch({
    readLines(most_recent$filename)
  }, error = function(e) {
    cat("Error reading log file:", conditionMessage(e), "\n")
    return(character(0))
  })
  
  if (length(log_content) == 0) {
    cat("Log file is empty or cannot be read.\n")
    return(list(runnable = FALSE))
  }
  
  # Check if pipeline completed successfully
  if (any(grepl("SOCIAL DETERMINANTS OF HEALTH DATA PIPELINE COMPLETED", log_content, fixed = TRUE))) {
    cat("The last pipeline run completed successfully!\n")
    cat("No need to restart unless you want to force a complete rebuild.\n")
    
    if (!force_restart) {
      cat("Use --force to restart anyway.\n")
      return(list(runnable = FALSE))
    } else {
      cat("Force restart requested. Will run the pipeline from the beginning.\n")
      return(list(
        runnable = TRUE,
        restart_step = 1,
        problem = "none",
        completed = TRUE
      ))
    }
  }
  
  # Look for step headers to determine where we are
  steps <- c(
    "BUILDING EXTENDED VARIABLE CROSSWALK",
    "FETCHING DATA FROM MULTIPLE SOURCES",
    "PROCESSING AND COMBINING DATA",
    "VALIDATION AND EXAMPLES",
    "GENERATING DOCUMENTATION",
    "PREPARING COUNTY BOUNDARY SHAPEFILES"
  )
  
  step_found <- integer(0)
  for (i in seq_along(steps)) {
    if (any(grepl(steps[i], log_content, fixed = TRUE))) {
      step_found <- c(step_found, i)
    }
  }
  
  last_step <- if (length(step_found) > 0) max(step_found) else 0
  
  # Check for errors
  errors <- grep("ERROR", log_content, value = TRUE)
  has_error <- length(errors) > 0
  
  # Determine the issue
  if (has_error) {
    cat("Found", length(errors), "errors in the log.\n")
    cat("Last few errors:\n")
    for (i in 1:min(3, length(errors))) {
      cat(" - ", errors[length(errors) - i + 1], "\n")
    }
    
    # Look for specific error patterns
    memory_error <- any(grepl("memory|alloc|heap|stack", errors, ignore.case = TRUE))
    timeout_error <- any(grepl("timeout|timed out", errors, ignore.case = TRUE))
    api_error <- any(grepl("API|key|authentication|credential", errors, ignore.case = TRUE))
    file_error <- any(grepl("file|permission|access|open", errors, ignore.case = TRUE))
    
    if (memory_error) {
      cat("\nDiagnosis: MEMORY ERROR\n")
      cat("The pipeline ran out of memory. Recommend running with reduced dataset or sequential processing.\n")
      problem <- "memory"
    } else if (timeout_error) {
      cat("\nDiagnosis: TIMEOUT ERROR\n")
      cat("An operation timed out. This could be due to API limits or slow network.\n")
      problem <- "timeout"
    } else if (api_error) {
      cat("\nDiagnosis: API ERROR\n")
      cat("There was an issue with API access. Check your API keys.\n")
      problem <- "api"
    } else if (file_error) {
      cat("\nDiagnosis: FILE ERROR\n")
      cat("There was an issue with file access. Check permissions.\n")
      problem <- "file"
    } else {
      cat("\nDiagnosis: GENERAL ERROR\n")
      cat("An error occurred but its specific type couldn't be determined.\n")
      problem <- "general"
    }
    
    # Determine restart point
    restart_step <- last_step
    
  } else {
    # No explicit errors, check for stalling or other issues
    
    # Check for interpolation progress
    interpolating <- any(grepl("Interpolating", log_content, fixed = TRUE))
    progress_lines <- grep("Progress: \\[", log_content, value = TRUE)
    
    if (interpolating && length(progress_lines) > 0) {
      # Get the last progress line
      last_progress <- tail(progress_lines, 1)
      
      # Check if it's stuck (incomplete progress bar at the end of the log)
      if (grepl("\\.\\.\\.$", last_progress)) {
        cat("\nDiagnosis: STALLED INTERPOLATION\n")
        cat("The pipeline appears to be stuck in the interpolation step.\n")
        cat("This is often due to memory pressure or complexity of the operation.\n")
        problem <- "interpolation_stall"
      } else {
        cat("\nDiagnosis: IN PROGRESS\n")
        cat("The pipeline appears to be running normally, just not completed yet.\n")
        problem <- "in_progress"
      }
    } else {
      cat("\nDiagnosis: UNKNOWN STATE\n")
      cat("Can't precisely determine what state the pipeline is in.\n")
      problem <- "unknown"
    }
    
    # Determine restart point
    restart_step <- max(1, last_step)
  }
  
  cat("\nRecommended restart point: Step", restart_step, "\n")
  
  return(list(
    runnable = TRUE,
    restart_step = restart_step,
    problem = problem,
    has_error = has_error,
    errors = if (has_error) head(errors, 3) else NULL,
    completed = FALSE
  ))
}

# Generate optimized configuration based on analysis
generate_optimized_config <- function(analysis) {
  # Default settings
  config <- list(
    parallel = TRUE,
    cores = max(1, parallel::detectCores() - 1),  # Default to all cores minus one
    strategy = "multisession",
    skip_interpolation = FALSE,
    reduced_years = FALSE,
    years = NULL
  )
  
  # Override with command line args
  if (sequential_mode) {
    config$parallel <- FALSE
  } else if (use_parallel) {
    config$parallel <- TRUE
  }
  
  if (skip_interpolation) {
    config$skip_interpolation <- TRUE
  }
  
  # Adjust based on problem analysis
  if (!is.null(analysis) && analysis$runnable) {
    # Memory issues - reduce parallelism and dataset size
    if (analysis$problem == "memory" || analysis$problem == "interpolation_stall") {
      config$cores <- 2  # Minimal cores
      config$skip_interpolation <- TRUE
      config$reduced_years <- TRUE
      config$years <- c(1980, 1990, 2000, 2010, 2020)  # Reduced year set
    }
    
    # Timeout issues - add retries and increase timeouts
    if (analysis$problem == "timeout") {
      config$timeout_multiplier <- 2  # Double timeouts
      config$retries <- 3  # Add retries
    }
    
    # API issues - use more caching, fewer parallel requests
    if (analysis$problem == "api") {
      config$cores <- 2  # Reduce parallel requests
      config$force_cache <- TRUE  # Force using cache
    }
  }
  
  return(config)
}

# Generate restart script based on analysis and configuration
generate_restart_script <- function(analysis, config) {
  script_path <- "restart_pipeline.r"
  
  content <- c(
    "#!/usr/bin/env Rscript",
    "",
    "# AUTO-GENERATED PIPELINE RESTART SCRIPT",
    paste("# Generated on:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    "",
    "cat(\"Restarting pipeline with optimized settings...\\n\")",
    "",
    "# Configure optimized settings",
    paste0("PARALLEL_ENABLED <- ", ifelse(config$parallel, "TRUE", "FALSE")),
    paste0("PARALLEL_CORES <- ", config$cores),
    paste0("PARALLEL_STRATEGY <- \"", config$strategy, "\""),
    ""
  )
  
  if (config$skip_interpolation) {
    content <- c(content,
      "# Skip interpolation due to previous issues",
      "SKIP_INTERPOLATION <- TRUE",
      ""
    )
  }
  
  if (config$reduced_years) {
    content <- c(content,
      "# Use reduced year set to minimize memory usage",
      paste0("REDUCED_YEARS <- c(", paste(config$years, collapse = ", "), ")"),
      ""
    )
  }
  
  # Export variables to global environment
  content <- c(content,
    "# Export variables to global environment",
    "assign(\"PARALLEL_ENABLED\", PARALLEL_ENABLED, envir = .GlobalEnv)",
    "assign(\"PARALLEL_CORES\", PARALLEL_CORES, envir = .GlobalEnv)",
    "assign(\"PARALLEL_STRATEGY\", PARALLEL_STRATEGY, envir = .GlobalEnv)",
    ""
  )
  
  if (config$skip_interpolation) {
    content <- c(content,
      "assign(\"SKIP_INTERPOLATION\", SKIP_INTERPOLATION, envir = .GlobalEnv)"
    )
  }
  
  if (config$reduced_years) {
    content <- c(content,
      "assign(\"REDUCED_YEARS\", REDUCED_YEARS, envir = .GlobalEnv)"
    )
  }
  
  # Add steps to run
  content <- c(content,
    "",
    "# Run the pipeline with optimized settings",
    "cat(\"Running pipeline...\\n\")",
    "source(\"main_extended.r\")",
    "",
    "cat(\"\\nRestart completed.\\n\")"
  )
  
  # Write the script
  writeLines(content, script_path)
  Sys.chmod(script_path, mode = "0755")  # Make executable
  
  cat("Created restart script:", script_path, "\n")
  cat("Run it with: Rscript", script_path, "\n")
  
  return(script_path)
}

# Prepare environment for restart
prepare_environment <- function() {
  cat("Preparing environment for restart...\n")
  
  # Check for required packages
  required_packages <- c(
    "tidyverse", "tidycensus", "jsonlite", "duckdb", "ipumsr", "tigris", "sf",
    "zoo", "httr", "parallel", "foreach", "doParallel", "future", "future.apply",
    "progressr", "digest"
  )
  
  missing_packages <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]
  
  if (length(missing_packages) > 0) {
    cat("\nWARNING: Missing packages:", paste(missing_packages, collapse = ", "), "\n")
    cat("These need to be installed for the pipeline to work correctly.\n")
    
    install_code <- paste0("install.packages(c(\"", paste(missing_packages, collapse = "\", \""), "\"))")
    cat("Run this command to install them:\n", install_code, "\n\n")
    
    return(FALSE)
  }
  
  # Check for API key
  census_api_key <- Sys.getenv("CENSUS_API_KEY")
  if (census_api_key == "") {
    cat("\nWARNING: No Census API key found in environment.\n")
    cat("The pipeline may not be able to fetch new data without a key.\n")
    cat("Get a key at: https://api.census.gov/data/key_signup.html\n")
    cat("Then set it with: Sys.setenv(CENSUS_API_KEY=\"your_key_here\")\n\n")
  }
  
  # Ensure directories exist
  dirs <- c(
    "data/cache",
    "data/cdc_places",
    "data/nhgis",
    "data/shapefiles",
    "output",
    "logs"
  )
  
  for (dir in dirs) {
    if (!dir.exists(dir)) {
      dir.create(dir, recursive = TRUE, showWarnings = FALSE)
      cat("Created directory:", dir, "\n")
    }
  }
  
  # Ensure main script exists
  if (!file.exists("main_extended.r")) {
    cat("\nERROR: Main pipeline script (main_extended.r) not found.\n")
    cat("Cannot restart without the main script.\n")
    return(FALSE)
  }
  
  cat("Environment looks good! Ready to restart.\n")
  return(TRUE)
}

# Main execution flow
analysis <- analyze_last_run()

if (analysis$runnable) {
  cat("\nGenerating optimized configuration...\n")
  config <- generate_optimized_config(analysis)
  
  cat("\nOptimized settings:\n")
  cat("- Parallel processing:", if(config$parallel) "ENABLED" else "DISABLED", "\n")
  if (config$parallel) {
    cat("- Cores:", config$cores, "\n")
    cat("- Strategy:", config$strategy, "\n")
  }
  cat("- Skip interpolation:", if(config$skip_interpolation) "YES" else "NO", "\n")
  if (config$reduced_years) {
    cat("- Using reduced year set:", paste(config$years, collapse = ", "), "\n")
  }
  
  cat("\nPreparing environment...\n")
  if (prepare_environment()) {
    cat("\nGenerating restart script...\n")
    script_path <- generate_restart_script(analysis, config)
    
    cat("\nReady to restart pipeline!\n")
    cat("Run the following command to restart:\n")
    cat("Rscript", script_path, "\n")
  } else {
    cat("\nCannot restart due to environment issues. Fix them first.\n")
  }
} else {
  cat("\nNo restart needed or requested.\n")
}

cat("\nFix & Restart tool completed.\n")