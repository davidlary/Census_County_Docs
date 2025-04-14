#!/usr/bin/env Rscript

# This script runs the optimized census data pipeline with improved NHGIS/IHME data handling

# Log startup
cat("Starting optimized census data pipeline with improved NHGIS/IHME data handling...\n")

# Check if required packages are installed
required_packages <- c("tidyverse", "tidycensus", "duckdb", "future", "parallel", "ipumsr", "sf", "zoo")
missing_packages <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]

if (length(missing_packages) > 0) {
  cat("Installing missing required packages:", paste(missing_packages, collapse = ", "), "\n")
  install.packages(missing_packages)
}

# Make sure utilities directory exists
if (!dir.exists("utilities")) {
  warning("utilities directory not found. Creating it.")
  dir.create("utilities", showWarnings = FALSE)
}

# Check if IPUMS credentials script exists
ipums_credential_path <- "utilities/load_ipums_credentials.r"
if (!file.exists(ipums_credential_path)) {
  cat("IPUMS credentials script not found at:", ipums_credential_path, "\n")
  cat("Using the existing one located at the provided path...\n")
  
  # Get the correct path from the environment
  source_path <- "/Users/davidlary/Dropbox/Environments/Code/GetData/US-Census-Claude/County/census_time_series/R/utilities/load_ipums_credentials.r"
  
  if (file.exists(source_path)) {
    # Create utilities directory if needed
    if (!dir.exists("utilities")) {
      dir.create("utilities", showWarnings = FALSE)
    }
    
    # Copy or link the file
    if (.Platform$OS.type == "unix") {
      # On Unix/Mac: create symbolic link
      system(sprintf("ln -sf '%s' '%s'", normalizePath(source_path), ipums_credential_path))
      cat("Created symbolic link to IPUMS credentials script\n")
    } else {
      # On Windows: copy the file
      file.copy(source_path, ipums_credential_path)
      cat("Copied IPUMS credentials script\n")
    }
  } else {
    cat("Warning: Could not find the IPUMS credentials at source path: ", source_path, "\n")
  }
}

# Check for IHME data directory and link files to NHGIS directory if needed
ihme_data_dir <- "data/ihme/CSV"
nhgis_data_dir <- "data/nhgis"

if (dir.exists(ihme_data_dir)) {
  ihme_files <- list.files(ihme_data_dir, pattern = "\\.CSV$", full.names = TRUE)
  cat(sprintf("Found %d IHME data files\n", length(ihme_files)))
  
  # Ensure NHGIS directory exists
  if (!dir.exists(nhgis_data_dir)) {
    dir.create(nhgis_data_dir, recursive = TRUE, showWarnings = FALSE)
    cat("Created NHGIS data directory\n")
  }
  
  # Check if NHGIS directory is empty
  nhgis_files <- list.files(nhgis_data_dir, pattern = "\\.csv$|\\.CSV$", full.names = TRUE)
  
  if (length(nhgis_files) == 0) {
    cat("NHGIS directory is empty. Making IHME files available...\n")
    
    # Create links or copy files
    if (.Platform$OS.type == "unix") {
      # On Unix/Mac, create symbolic links
      system(sprintf("ln -sf %s/*.CSV %s/", normalizePath(ihme_data_dir), normalizePath(nhgis_data_dir)))
      cat("Created symbolic links to IHME files in NHGIS directory\n")
    } else {
      # On Windows, copy files
      file.copy(ihme_files, nhgis_data_dir)
      cat("Copied IHME files to NHGIS directory\n")
    }
  } else {
    cat(sprintf("NHGIS directory already contains %d files\n", length(nhgis_files)))
  }
} else {
  cat("IHME data directory not found at:", ihme_data_dir, "\n")
}

# Run the optimized pipeline script
cat("\nExecuting main_optimized.r script...\n\n")
source("main_optimized.r")

cat("\nOptimized pipeline execution complete!\n")