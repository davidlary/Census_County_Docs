#!/usr/bin/env Rscript

# AUTO-GENERATED PIPELINE RESTART SCRIPT
# Generated on: 2025-04-12 13:33:03

cat("Restarting pipeline with optimized settings...\n")

# Configure optimized settings
PARALLEL_ENABLED <- TRUE
PARALLEL_CORES <- 2
PARALLEL_STRATEGY <- "multisession"

# Skip interpolation due to previous issues
SKIP_INTERPOLATION <- TRUE

# Use reduced year set to minimize memory usage
REDUCED_YEARS <- c(1980, 1990, 2000, 2010, 2020)

# Export variables to global environment
assign("PARALLEL_ENABLED", PARALLEL_ENABLED, envir = .GlobalEnv)
assign("PARALLEL_CORES", PARALLEL_CORES, envir = .GlobalEnv)
assign("PARALLEL_STRATEGY", PARALLEL_STRATEGY, envir = .GlobalEnv)

assign("SKIP_INTERPOLATION", SKIP_INTERPOLATION, envir = .GlobalEnv)
assign("REDUCED_YEARS", REDUCED_YEARS, envir = .GlobalEnv)

# Run the pipeline with optimized settings
cat("Running pipeline...\n")
source("main_extended.r")

cat("\nRestart completed.\n")
