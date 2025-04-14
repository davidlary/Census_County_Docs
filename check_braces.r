#!/usr/bin/env Rscript

# Simple utility to check for balanced braces in an R script
args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  cat("Usage: Rscript check_braces.r <filename>\n")
  quit(status = 1)
}

filename <- args[1]

if (!file.exists(filename)) {
  cat("Error: File", filename, "does not exist\n")
  quit(status = 1)
}

# Read the file
content <- readLines(filename)

# Initialize counters
open_count <- 0
close_count <- 0
brace_balance <- 0

# Process each line
for (i in seq_along(content)) {
  line <- content[i]
  
  # Count opening braces
  open_in_line <- gregexpr("\\{", line)[[1]]
  if (open_in_line[1] != -1) {
    open_count <- open_count + length(open_in_line)
  }
  
  # Count closing braces
  close_in_line <- gregexpr("\\}", line)[[1]]
  if (close_in_line[1] != -1) {
    close_count <- close_count + length(close_in_line)
  }
  
  # Update balance
  if (open_in_line[1] != -1) {
    brace_balance <- brace_balance + length(open_in_line)
  }
  if (close_in_line[1] != -1) {
    brace_balance <- brace_balance - length(close_in_line)
  }
  
  # Report imbalances
  if (brace_balance < 0) {
    cat("IMBALANCE at line", i, ": Too many closing braces\n")
    cat("Line content:", line, "\n")
    break
  }
}

# Final report
cat("Total opening braces: ", open_count, "\n")
cat("Total closing braces: ", close_count, "\n")
cat("Final balance: ", brace_balance, "\n")

if (open_count != close_count) {
  if (open_count > close_count) {
    cat("ERROR: Missing", open_count - close_count, "closing braces\n")
  } else {
    cat("ERROR: Extra", close_count - open_count, "closing braces\n")
  }
  quit(status = 1)
} else {
  cat("SUCCESS: Braces are balanced\n")
  quit(status = 0)
}