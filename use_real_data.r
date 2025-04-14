#!/usr/bin/env Rscript

# A simple script to run the pipeline in standard mode (no simulation allowed by default)
# This ensures only real data is used and no simulated data will be generated

cat("Starting Census Data Pipeline - Standard Mode (No Simulation)\n")
cat("This will use real data only (simulation is disabled by default)\n\n")

# Clear the cache first to ensure fresh data
cat("Clearing cache to ensure fresh data...\n")
cache_dir <- "data/cache"
if (dir.exists(cache_dir)) {
  cache_files <- list.files(cache_dir, full.names = TRUE, recursive = TRUE)
  if (length(cache_files) > 0) {
    unlink(cache_files, recursive = TRUE)
    cat(sprintf("  Removed %d cache files\n", length(cache_files)))
  } else {
    cat("  No cache files found\n")
  }
}

# Check for IHME data and create links if needed
cat("\nChecking for data files...\n")
ihme_dir <- "data/ihme/CSV"
nhgis_dir <- "data/nhgis"

# Create NHGIS directory if needed
if (!dir.exists(nhgis_dir)) {
  dir.create(nhgis_dir, recursive = TRUE, showWarnings = FALSE)
  cat("  Created NHGIS directory\n")
}

# Check for IHME files and link/copy them if needed
if (dir.exists(ihme_dir)) {
  ihme_files <- list.files(ihme_dir, pattern = "\\.CSV$|\\.csv$", full.names = TRUE)
  if (length(ihme_files) > 0) {
    cat(sprintf("  Found %d IHME data files\n", length(ihme_files)))
    
    # Check if NHGIS directory is empty
    nhgis_files <- list.files(nhgis_dir, pattern = "\\.csv$|\\.CSV$", full.names = TRUE)
    if (length(nhgis_files) == 0) {
      cat("  NHGIS directory is empty. Making IHME files available...\n")
      
      # Create links or copy files
      if (.Platform$OS.type == "unix") {
        # On Unix/Mac, create symbolic links
        for (file in ihme_files) {
          system(sprintf("ln -sf '%s' '%s/'", normalizePath(file), normalizePath(nhgis_dir)))
        }
        cat("  Created symbolic links to IHME files in NHGIS directory\n")
      } else {
        # On Windows, copy files
        file.copy(ihme_files, nhgis_dir, overwrite = TRUE)
        cat("  Copied IHME files to NHGIS directory\n")
      }
    } else {
      cat(sprintf("  NHGIS directory already contains %d files\n", length(nhgis_files)))
    }
  } else {
    cat("  No IHME data files found\n")
  }
} else {
  cat("  IHME directory not found\n")
}

# Run the optimized pipeline (no-simulation is now the default)
cmd <- "Rscript main_optimized.r --force-update --verbose"
cat("\nRunning pipeline with default no-simulation mode:\n")
cat(cmd, "\n\n")

# Execute the command
system(cmd)

cat("\nPipeline execution complete\n")
cat("Check above for any simulation errors\n")