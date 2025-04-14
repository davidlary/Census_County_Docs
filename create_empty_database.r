#!/usr/bin/env Rscript

# Emergency script to create a basic database with interpolation capabilities
# Use this when the main pipeline is failing but you need a test database

library(dplyr)
library(duckdb)
library(tidyr)
library(tibble)

cat("Creating emergency database with minimal test data...\n")

# File to create
db_file <- "us_county_sdoh_data.duckdb"

# Check if database already exists
if (file.exists(db_file)) {
  cat("Database already exists. Backing up...\n")
  backup_file <- paste0(db_file, ".backup_", format(Sys.time(), "%Y%m%d_%H%M%S"))
  file.copy(db_file, backup_file)
  unlink(db_file)
}

# Create a connection to a new database
cat("Creating new database...\n")
con <- dbConnect(duckdb::duckdb(), db_file)

# Create some sample county data
cat("Generating sample county data...\n")

# Some real counties 
counties <- tibble(
  GEOID = c("06037", "36061", "17031", "48201", "04013"),
  NAME = c("Los Angeles County, California", "New York County, New York", 
           "Cook County, Illinois", "Harris County, Texas", "Maricopa County, Arizona")
)

# Generate sample data for years 2018-2022
years <- 2018:2022

# Create empty grid of county-years 
county_data <- expand.grid(
  GEOID = counties$GEOID,
  year = years,
  stringsAsFactors = FALSE
) %>%
  as_tibble() %>%
  left_join(counties, by = "GEOID")

# Add numeric data with some NAs to test interpolation
set.seed(42)
county_data <- county_data %>%
  mutate(
    # Population data - complete
    total_population = case_when(
      GEOID == "06037" ~ 10000000 - (2022 - year) * 50000 + rnorm(n(), 0, 10000),
      GEOID == "36061" ~ 1600000 - (2022 - year) * 20000 + rnorm(n(), 0, 5000),
      GEOID == "17031" ~ 5200000 - (2022 - year) * 30000 + rnorm(n(), 0, 8000),
      GEOID == "48201" ~ 4700000 + (2022 - year) * 40000 + rnorm(n(), 0, 12000),
      GEOID == "04013" ~ 4500000 + (2022 - year) * 60000 + rnorm(n(), 0, 15000)
    ),
    
    # Income data - with some NA values
    median_household_income = case_when(
      GEOID == "06037" & year >= 2019 ~ 70000 + (year - 2019) * 2000 + rnorm(1, 0, 500),
      GEOID == "36061" & year >= 2018 ~ 85000 + (year - 2018) * 3000 + rnorm(1, 0, 800),
      GEOID == "17031" & year >= 2020 ~ 65000 + (year - 2020) * 1800 + rnorm(1, 0, 400),
      GEOID == "48201" ~ 60000 + (year - 2018) * 1500 + rnorm(1, 0, 600),
      GEOID == "04013" & year != 2019 ~ 62000 + (year - 2018) * 1700 + rnorm(1, 0, 550),
      TRUE ~ NA_real_
    ),
    
    # Poverty data - missing for some counties in middle years
    poverty_rate = case_when(
      GEOID == "06037" & (year == 2018 | year == 2022) ~ 14 - (year - 2018) * 0.5 + rnorm(1, 0, 0.2),
      GEOID == "36061" ~ 17 - (year - 2018) * 0.7 + rnorm(1, 0, 0.3),
      GEOID == "17031" & year != 2020 ~ 13 - (year - 2018) * 0.4 + rnorm(1, 0, 0.25),
      GEOID == "48201" & year >= 2020 ~ 15 - (year - 2020) * 0.6 + rnorm(1, 0, 0.3),
      GEOID == "04013" & (year <= 2019 | year == 2022) ~ 12 - (year - 2018) * 0.3 + rnorm(1, 0, 0.2),
      TRUE ~ NA_real_
    )
  )

# Add metadata fields
county_data <- county_data %>%
  mutate(
    source = case_when(
      year <= 2020 ~ "ACS 5-Year",
      TRUE ~ "ACS (trend-adjusted)"
    ),
    data_quality = case_when(
      is.na(median_household_income) | is.na(poverty_rate) ~ "missing",
      year <= 2020 ~ "estimate",
      TRUE ~ "estimate"
    ),
    data_source = source,
    data_vintage = paste0(source, " ", year),
    
    # Add flags to test missing data interpolation
    missing_data_flag = is.na(median_household_income) | is.na(poverty_rate)
  )

# Write the data to the database
cat("Saving county data to database...\n")
dbWriteTable(con, "county_sdoh_data", county_data, overwrite = TRUE)

# Create fake county metadata
county_metadata <- counties %>%
  mutate(
    first_year = min(years),
    last_year = max(years),
    years_available = length(years),
    percent_interpolated = 0,
    percent_extended = 0,
    state_abbr = case_when(
      grepl("California", NAME) ~ "CA",
      grepl("New York", NAME) ~ "NY",
      grepl("Illinois", NAME) ~ "IL",
      grepl("Texas", NAME) ~ "TX",
      grepl("Arizona", NAME) ~ "AZ"
    ),
    county_name_only = gsub(", .*$", "", NAME)
  )

dbWriteTable(con, "county_metadata", county_metadata, overwrite = TRUE)

# Create a simple data dictionary
data_dictionary <- tibble(
  std_name = c("total_population", "median_household_income", "poverty_rate"),
  description = c("Total population", "Median household income (dollars)", "Poverty rate (%)"),
  category = c("Demographics", "Socioeconomic", "Socioeconomic"),
  preferred_source = c("Census", "ACS", "ACS"),
  years_available = c("1970-2025", "1980-2025", "1980-2025"),
  interpolate_recommended = c(TRUE, TRUE, TRUE),
  extend_backwards = c(FALSE, TRUE, TRUE),
  extend_method = c(NA, "linear", "linear"),
  available_in_dataset = c(TRUE, TRUE, TRUE)
)

dbWriteTable(con, "data_dictionary", data_dictionary, overwrite = TRUE)

# Create views
cat("Creating database views...\n")

# Latest county data view
dbExecute(con, "
  CREATE OR REPLACE VIEW latest_county_data AS
  WITH ranked_data AS (
    SELECT 
      *,
      ROW_NUMBER() OVER (PARTITION BY GEOID ORDER BY year DESC) as rn
    FROM county_sdoh_data
  )
  SELECT *
  FROM ranked_data 
  WHERE rn = 1
")

# Time series view
dbExecute(con, "
  CREATE OR REPLACE VIEW county_time_series AS
  SELECT * 
  FROM county_sdoh_data
  ORDER BY GEOID, year
")

# Example queries
example_queries <- c(
  "-- Get the latest data for all counties",
  "SELECT * FROM latest_county_data",
  "",
  "-- Get time series data for a specific county",
  "SELECT * FROM county_time_series WHERE GEOID = '06037' ORDER BY year",
  "",
  "-- Get counties with highest poverty rates in the latest year",
  "SELECT GEOID, NAME, year, poverty_rate FROM latest_county_data WHERE poverty_rate IS NOT NULL ORDER BY poverty_rate DESC LIMIT 10",
  "",
  "-- Get counties with missing data",
  "SELECT * FROM county_sdoh_data WHERE missing_data_flag = TRUE"
)

dbWriteTable(con, "example_queries", data.frame(query = example_queries), overwrite = TRUE)

# Create empty table for interpolation statistics
missing_data_stats <- tibble(
  variable = character(),
  year = integer(),
  total_records = integer(),
  has_value_count = integer(),
  has_value_pct = numeric(),
  interpolated_count = integer(),
  interpolated_pct = numeric(),
  missing_interpolated_count = integer(),
  missing_interpolated_pct = numeric(),
  pct_of_interpolations_from_missing = numeric()
)

dbWriteTable(con, "missing_data_interpolation_stats", missing_data_stats, overwrite = TRUE)

# Close the connection
dbDisconnect(con)

cat("Emergency database created successfully with test data!\n")
cat("Use this database to test your interpolation code.\n")
cat("The data contains purposely missing values to test interpolation from missing data.\n")