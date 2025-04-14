#!/usr/bin/env Rscript

# Installation script for required packages

# Print information about R environment
cat("R version:", R.version.string, "\n")
cat("Platform:", R.Platform$OS.type, "--", R.Platform$pkgType, "\n")
cat("Working directory:", getwd(), "\n\n")

# Define required packages
req_packages <- c(
  "tidyverse",   # Data manipulation and visualization 
  "tidycensus",  # Census data access
  "ipumsr",      # IPUMS data access
  "tigris",      # Geographic data from Census
  "sf",          # Simple features for spatial data
  "duckdb",      # DuckDB database
  "zoo",         # Time series manipulation
  "lubridate",   # Date handling
  "httr",        # HTTP requests
  "readxl",      # Excel file reading
  "jsonlite",    # JSON handling
  "viridis"      # Color palettes for visualization
)

# Install CRAN packages
cat("Installing required packages from CRAN...\n")
new_packages <- req_packages[!req_packages %in% installed.packages()[,"Package"]]

if(length(new_packages) > 0) {
  cat("Installing missing packages:", paste(new_packages, collapse=", "), "\n")
  install.packages(new_packages, repos = "https://cloud.r-project.org")
} else {
  cat("All required packages are already installed.\n")
}

# Check installation status
installed <- req_packages %in% installed.packages()[,"Package"]
status <- data.frame(
  Package = req_packages,
  Installed = installed,
  Version = sapply(req_packages, function(p) {
    if (p %in% installed.packages()[,"Package"]) {
      as.character(packageVersion(p))
    } else {
      "Not installed"
    }
  })
)

cat("\nPackage installation status:\n")
print(status, row.names = FALSE)

if(all(installed)) {
  cat("\nAll required packages successfully installed!\n")
} else {
  cat("\nWARNING: Some packages failed to install. Please check error messages above.\n")
}