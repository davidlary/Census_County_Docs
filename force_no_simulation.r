#!/usr/bin/env Rscript

# This script removes all simulated data and forces the pipeline to use only real data

cat("Starting fresh data pipeline with NO simulated data\n")

# Clear cache
cat("Clearing cache...\n")
cache_files <- list.files("data/cache", pattern = "\\.rds$", full.names = TRUE)
if (length(cache_files) > 0) {
  unlink(cache_files)
  cat(sprintf("Removed %d cache files\n", length(cache_files)))
} else {
  cat("No cache files found\n")
}

# Modify fetch_nhgis_data.r to prevent simulation
fetch_nhgis_file <- "fetch_nhgis_data.r"
if (file.exists(fetch_nhgis_file)) {
  fetch_content <- readLines(fetch_nhgis_file)
  
  # Find the simulation function
  simulation_start <- grep("# For testing purposes only - generate sample data", fetch_content)
  if (length(simulation_start) > 0) {
    cat("Temporarily disabling simulation code...\n")
    
    # Create backup if it doesn't exist
    backup_file <- paste0(fetch_nhgis_file, ".backup")
    if (!file.exists(backup_file)) {
      file.copy(fetch_nhgis_file, backup_file)
      cat("Created backup at", backup_file, "\n")
    }
    
    # Find where to insert stop code
    line_to_modify <- simulation_start[1] + 1
    
    # Insert code to exit instead of simulating
    if (line_to_modify <= length(fetch_content)) {
      fetch_content[line_to_modify] <- paste(
        fetch_content[line_to_modify],
        "\n    print_msg(\"ERROR: NO SIMULATION ALLOWED BY force_no_simulation.r\")",
        "\n    print_msg(\"Please provide actual NHGIS/IHME data files\")",
        "\n    stop(\"Simulation prevented by force_no_simulation.r\")",
        sep = ""
      )
      
      # Write modified file
      writeLines(fetch_content, fetch_nhgis_file)
      cat("Modified", fetch_nhgis_file, "to prevent simulation\n")
    }
  } else {
    cat("Could not locate simulation code section in fetch_nhgis_data.r\n")
  }
} else {
  cat("fetch_nhgis_data.r not found\n")
}

# Set force flag to ensure no cached data is used
force_update <- TRUE

# Run the pipeline with force update
cat("\nRunning pipeline with force update and no simulation...\n")
source("run_optimized.r")
