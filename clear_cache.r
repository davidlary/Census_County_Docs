#!/usr/bin/env Rscript

# Script to clear all caches before running the pipeline

cat("Clearing all caches before testing parallel processing...\n")

# 1. Clear our custom cache directory
cache_dir <- "data/cache"
if (dir.exists(cache_dir)) {
  files <- list.files(cache_dir, full.names = TRUE, recursive = TRUE)
  if (length(files) > 0) {
    unlink(files, recursive = TRUE, force = TRUE)
    cat("Cleared", length(files), "files from custom cache directory\n")
  } else {
    cat("Custom cache directory already empty\n")
  }
}

# 2. Clear tidycensus cache 
# The path is typically ~/.cache/R/tidycensus
user_cache <- Sys.getenv("HOME")
tidycensus_cache_dir <- file.path(user_cache, ".cache", "R", "tidycensus")
if (dir.exists(tidycensus_cache_dir)) {
  files <- list.files(tidycensus_cache_dir, full.names = TRUE, recursive = TRUE)
  if (length(files) > 0) {
    unlink(files, recursive = TRUE, force = TRUE)
    cat("Cleared", length(files), "files from tidycensus cache directory:", tidycensus_cache_dir, "\n")
  } else {
    cat("tidycensus cache directory already empty\n")
  }
} else {
  cat("tidycensus cache directory not found at:", tidycensus_cache_dir, "\n")
  
  # Try alternative location
  alt_tidycensus_cache <- file.path(user_cache, "Library", "Caches", "R", "tidycensus")
  if (dir.exists(alt_tidycensus_cache)) {
    files <- list.files(alt_tidycensus_cache, full.names = TRUE, recursive = TRUE)
    if (length(files) > 0) {
      unlink(files, recursive = TRUE, force = TRUE)
      cat("Cleared", length(files), "files from alternative tidycensus cache:", alt_tidycensus_cache, "\n")
    }
  }
}

# 3. Clear R session temporary files
temp_files <- list.files(tempdir(), full.names = TRUE, recursive = TRUE)
if (length(temp_files) > 0) {
  unlink(temp_files, recursive = TRUE, force = TRUE)
  cat("Cleared", length(temp_files), "files from R session temporary directory\n")
} else {
  cat("R session temporary directory already empty\n")
}

cat("All caches cleared successfully!\n")
cat("You can now run the pipeline with: Rscript test_pipeline.r\n")