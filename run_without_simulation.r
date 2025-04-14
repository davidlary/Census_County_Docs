#!/usr/bin/env Rscript

# This script runs the pipeline with a strong focus on using only real data

suppressPackageStartupMessages({
  library(tidyverse)
})

cat("Starting Census Data Pipeline with STRICT REAL DATA ONLY mode\n")
cat("========================================================\n\n")

# Step 1: Remove all cached data
cat("Step 1: Removing all cached data...\n")
cache_dir <- "data/cache"
if (dir.exists(cache_dir)) {
  cache_files <- list.files(cache_dir, full.names = TRUE, recursive = TRUE)
  if (length(cache_files) > 0) {
    unlink(cache_files, recursive = TRUE)
    cat(sprintf("  Removed %d cache files\n", length(cache_files)))
  } else {
    cat("  No cache files found\n")
  }
} else {
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  cat("  Created empty cache directory\n")
}

# Step 2: Check and create symbolic links to real data
cat("\nStep 2: Checking for real data files...\n")

# Define possible locations for real data
ihme_dir <- "data/ihme/CSV"
nhgis_dir <- "data/nhgis"
census_hist_dir <- "data/census_historical"

# Create directories if they don't exist
for (dir_path in c(nhgis_dir, census_hist_dir)) {
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
    cat(sprintf("  Created directory: %s\n", dir_path))
  }
}

# Check IHME directory for real files
if (dir.exists(ihme_dir)) {
  ihme_files <- list.files(ihme_dir, pattern = "\\.CSV$|\\.csv$", full.names = TRUE)
  if (length(ihme_files) > 0) {
    cat(sprintf("  Found %d real IHME data files\n", length(ihme_files)))
    
    # Make IHME files available to NHGIS directory
    if (.Platform$OS.type == "unix") {
      # Create symbolic links on Unix/Mac
      for (file in ihme_files) {
        link_cmd <- sprintf("ln -sf '%s' '%s/'", 
                            normalizePath(file), 
                            normalizePath(nhgis_dir))
        system(link_cmd)
      }
      cat("  Created symbolic links from IHME to NHGIS directory\n")
    } else {
      # Copy files on Windows
      file.copy(ihme_files, nhgis_dir, overwrite = TRUE)
      cat("  Copied IHME files to NHGIS directory\n")
    }
  } else {
    cat("  No IHME data files found\n")
    cat("  WARNING: Without real data files, the pipeline will fail\n")
  }
} else {
  cat("  IHME directory not found. Looking elsewhere for data...\n")
}

# Step 3: Create a file that will block simulated data generation
cat("\nStep 3: Setting up simulation blocker...\n")

# Create a file to block simulation
sim_block_file <- "no_simulation.r"
writeLines(c(
  "# This file prevents the creation of simulated data",
  "# It is sourced by the modified fetch_nhgis_data.r script",
  "",
  "prevent_simulation <- function() {",
  "  stop(\"ERROR: Simulation blocked by no_simulation.r - real data required!\")",
  "}",
  "",
  "# Set global flag",
  "NO_SIMULATION <- TRUE"
), sim_block_file)
cat("  Created simulation blocker file:", sim_block_file, "\n")

# Modify fetch_nhgis_data.r to use the blocker
cat("\nStep 4: Modifying fetch_nhgis_data.r to prevent simulation...\n")

fetch_file <- "fetch_nhgis_data.r"
if (file.exists(fetch_file)) {
  # Create backup if it doesn't exist
  backup_file <- paste0(fetch_file, ".original")
  if (!file.exists(backup_file)) {
    file.copy(fetch_file, backup_file)
    cat("  Created backup of fetch_nhgis_data.r at", backup_file, "\n")
  }
  
  # Read file content
  fetch_content <- readLines(fetch_file)
  
  # Add import of simulation blocker at the top
  simulation_import <- "# Source simulation blocker\nif (file.exists('no_simulation.r')) source('no_simulation.r')"
  modified_content <- c(
    fetch_content[1:15], 
    simulation_import,
    fetch_content[16:length(fetch_content)]
  )
  
  # Find simulation section and add block
  sim_section <- grep("# For testing purposes only - generate sample data", modified_content)
  if (length(sim_section) > 0) {
    line_to_modify <- sim_section[1] + 1
    block_code <- "    # Check if simulation is blocked\n    if (exists(\"NO_SIMULATION\") && NO_SIMULATION) {\n      prevent_simulation()\n      return(NULL)\n    }"
    
    # Insert blocking code
    if (line_to_modify <= length(modified_content)) {
      modified_content <- c(
        modified_content[1:(line_to_modify-1)],
        block_code,
        modified_content[line_to_modify:length(modified_content)]
      )
      cat("  Added simulation blocker to fetch_nhgis_data.r\n")
    }
  } else {
    cat("  Warning: Could not find simulation section in fetch_nhgis_data.r\n")
  }
  
  # Write modified file
  writeLines(modified_content, fetch_file)
  cat("  Modified fetch_nhgis_data.r to prevent simulation\n")
} else {
  cat("  Error: fetch_nhgis_data.r not found\n")
}

# Step A special step to modify main_optimized.r 
cat("\nStep 5: Modifying main_optimized.r to force use of real data...\n")

main_file <- "main_optimized.r"
if (file.exists(main_file)) {
  # Create backup if it doesn't exist
  backup_file <- paste0(main_file, ".original")
  if (!file.exists(backup_file)) {
    file.copy(main_file, backup_file)
    cat("  Created backup of main_optimized.r at", backup_file, "\n")
  }
  
  # Modify to add FORCE_REAL_DATA flag
  main_content <- readLines(main_file)
  force_flag_line <- "# Add this flag to force real data only\nFORCE_REAL_DATA <- TRUE\nif (FORCE_REAL_DATA) source('no_simulation.r')"
  
  # Find a good place to insert the flag (after initial setup)
  insert_point <- grep("# Set up logging in logs directory", main_content)[1]
  if (!is.na(insert_point)) {
    main_modified <- c(
      main_content[1:(insert_point-1)],
      force_flag_line,
      main_content[insert_point:length(main_content)]
    )
    
    # Write modified file
    writeLines(main_modified, main_file)
    cat("  Modified main_optimized.r to force use of real data\n")
  } else {
    cat("  Warning: Could not find insertion point in main_optimized.r\n")
  }
} else {
  cat("  Error: main_optimized.r not found\n")
}

# Step 6: Set environment variables
cat("\nStep 6: Setting environment variables for credentials...\n")

# Source credentials script
cred_file <- "utilities/load_ipums_credentials.r"
if (file.exists(cred_file)) {
  cat("  Loading credentials from", cred_file, "\n")
  source(cred_file)
  if (exists("load_ipums_credentials")) {
    result <- load_ipums_credentials()
    cat("  Credential loading result:", result, "\n")
  } else {
    cat("  Error: load_ipums_credentials function not found\n")
  }
} else {
  cat("  Warning: Credentials file not found at", cred_file, "\n")
}

# Step 7: Run the pipeline with force update
cat("\nStep 7: Running the pipeline with --force-update flag...\n")
cat("  This will ensure all cached data is ignored and only real data is used\n\n")

cat("=====================================================================\n")
cat("STARTING PIPELINE - WILL FAIL IF NO REAL DATA FILES ARE AVAILABLE\n")
cat("=====================================================================\n\n")

# Run the script with force update
rscript_cmd <- "Rscript main_optimized.r --force-update --verbose"
system(rscript_cmd)

cat("\n=====================================================================\n")
cat("PIPELINE EXECUTION COMPLETE\n")
cat("=====================================================================\n\n")

# Restore original files
cat("Do you want to restore the original files? (y/n): ")
restore <- readline()
if (tolower(restore) == "y") {
  # Restore fetch_nhgis_data.r
  if (file.exists(paste0(fetch_file, ".original"))) {
    file.copy(paste0(fetch_file, ".original"), fetch_file, overwrite = TRUE)
    cat("Restored original fetch_nhgis_data.r\n")
  }
  
  # Restore main_optimized.r
  if (file.exists(paste0(main_file, ".original"))) {
    file.copy(paste0(main_file, ".original"), main_file, overwrite = TRUE)
    cat("Restored original main_optimized.r\n")
  }
  
  # Remove blocker file
  if (file.exists(sim_block_file)) {
    unlink(sim_block_file)
    cat("Removed simulation blocker file\n")
  }
  
  cat("All files restored to original state\n")
} else {
  cat("Files left in modified state. To restore manually, use the .original backups\n")
}