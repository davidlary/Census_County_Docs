# Census County-Level Social Determinants of Health Data Pipeline

Generated on: 2025-04-13

## Overview

This comprehensive data pipeline combines county-level Social Determinants of Health (SDOH) data from multiple authoritative sources:

- **U.S. Census Bureau** (Decennial Census, American Community Survey, Population Estimates Program)
- **CDC PLACES** (county-level health indicators)
- **IPUMS NHGIS** (harmonized time series data)
- **IHME** (life expectancy data)

The pipeline processes and harmonizes data across sources and years, handles missing data appropriately, performs intelligent interpolation when justified, and generates visualizations.

## Key Features

- Comprehensive variable coverage (80+ variables across demographic, socioeconomic, housing, health domains)
- Data organized with consistent variable names across sources and years
- Detailed data quality flags indicating source reliability and processing methods
- Variable-specific map visualizations organized by subdirectories
- Sophisticated interpolation with clear tracking of data provenance
- No simulation by default (real data is required; missing data is handled as NAs, not simulated)
- Support for various data quality and processing configurations

## Data Sources

| Source | Years | Description |
| ------ | ----- | ----------- |
| Decennial Census | 2000, 2010, 2020 | Complete count of population and housing |
| American Community Survey (ACS) | 2009-2023 | Detailed demographic, social, economic, and housing data |
| Population Estimates Program (PEP) | 2000-2023 | Annual population estimates |
| CDC PLACES | 2019-2023 | County-level health outcome measures and health-related behaviors |
| IPUMS NHGIS | Various | Harmonized historical census data |
| IHME | 1970-2025 | Life expectancy data |

## Running the Pipeline

### Standard Mode (Real Data Only)

To run the pipeline with full functionality:

```bash
Rscript main_extended.r
```

This runs the complete pipeline with default settings, requiring real data files.

### Alternative Run Modes

For special configurations:

```bash
# Run with no simulation (if not already default)
Rscript main_extended.r --no-simulation

# Force update (clear cache and refresh all data)
Rscript main_extended.r --force-update

# Run with verbose output
Rscript main_extended.r --verbose

# Run without interpolation (for memory constraints)
Rscript main_extended.r --skip-interpolation
```

### Testing and Development

```bash
# Test run with reduced dataset
Rscript test_main_pipeline.r

# Test parallel performance
Rscript test_parallel_performance.r

# Monitoring a running pipeline
Rscript monitor_pipeline.r --live
```

## Pipeline Components

The extended pipeline consists of four main components:

1. **Crosswalk Building**: `build_extended_crosswalk.r`
   - Creates a unified variable mapping across all data sources
   
2. **Data Fetching**: `fetch_extended_data.r`
   - Retrieves data from Census API, CDC PLACES, NHGIS, and IHME sources
   
3. **Data Processing**: `process_extended_data.r`
   - Standardizes, cleans, and validates data
   - Performs intelligent interpolation for missing values
   - Assigns data quality flags
   
4. **Visualization**: `generate_county_maps.r`
   - Creates choropleth maps for all variables
   - Organizes maps by variable in dedicated subdirectories

## Data Structure

The processed data includes:

- **county_sdoh_data_complete.csv**: Main dataset with all variables by county and year
- **county_metadata.csv**: Information about each county (FIPS codes, names, etc.)
- **data_dictionary_complete.csv**: Variable descriptions and metadata
- **variable_crosswalk_extended.csv**: Mapping between standardized variable names and source-specific codes
- **output/maps/**: Directory containing visualization maps organized by variable

## Data Quality Flags

Each record includes data quality indicators:

- `data_quality`: One of: 'direct' (counted), 'estimate' (statistical estimate), 'harmonized' (reconciled across sources), 'interpolated' (gap-filled), 'interpolated_from_missing' (interpolated where data was missing), or 'extended' (extrapolated)
- `data_source`: Original source of the data
- `data_vintage`: Year and specific collection the data came from
- `data_quality_score`: Numeric score (4=best, 0=worst) indicating data quality
- `interpolation_used`: Boolean flag indicating if any values were interpolated
- `interpolation_count`: Count of how many variables were interpolated
- `missing_data_interpolated`: Boolean flag indicating if any values were interpolated from missing data
- `missing_data_interpolation_count`: Count of how many variables were interpolated from missing data

Each variable also has accompanying `*_interpolated` and `*_missing_data_interpolated` flags to indicate if that specific value was interpolated.

## Variable Details and Units

### Demographic Variables
| Variable | Units | Description | Source | Notes |
|----------|-------|-------------|--------|-------|
| total_population | count | Total county population | Census, ACS | No scaling applied |
| male_population | count | Male population | Census, ACS | No scaling applied |
| female_population | count | Female population | Census, ACS | No scaling applied |
| median_age | years | Median age of population | Census, ACS | |
| population_under_18 | count | Population under 18 years of age | Census, ACS | No scaling applied |
| population_65_over | count | Population 65 years and older | Census, ACS | No scaling applied |
| white_nonhispanic_pct | percentage | Percentage of population that is non-Hispanic white | Census, ACS | Range: 0-100 |
| black_pct | percentage | Percentage of population that is Black or African American | Census, ACS | Range: 0-100 |
| hispanic_latino_pct | percentage | Percentage of population that is Hispanic or Latino | Census, ACS | Range: 0-100 |
| asian_pct | percentage | Percentage of population that is Asian | Census, ACS | Range: 0-100 |
| native_american_pct | percentage | Percentage of population that is American Indian or Alaska Native | Census, ACS | Range: 0-100 |
| population_density | people/sq mile | Population per square mile | Derived | Calculated from population and land area |

### Socioeconomic Variables
| Variable | Units | Description | Source | Notes |
|----------|-------|-------------|--------|-------|
| median_household_income | dollars | Median household income | ACS | Not adjusted for inflation |
| median_earnings | dollars | Median earnings for workers | ACS | Not adjusted for inflation |
| poverty_rate | percentage | Percentage of population below poverty level | ACS | Range: 0-100 |
| gini_index | index | Measure of income inequality | ACS | Range: 0-1, higher values indicate more inequality |
| snap_benefits_pct | percentage | Percentage of households receiving SNAP benefits | ACS | Range: 0-100 |
| food_insecurity_pct | percentage | Percentage of population with food insecurity | CDC PLACES | Range: 0-100 |
| less_than_highschool_pct | percentage | Percentage with less than high school education | ACS | Range: 0-100, adults 25+ |
| highschool_only_pct | percentage | Percentage with high school as highest education | ACS | Range: 0-100, adults 25+ |
| some_college_pct | percentage | Percentage with some college education | ACS | Range: 0-100, adults 25+ |
| bachelors_or_higher_pct | percentage | Percentage with bachelor's degree or higher | ACS | Range: 0-100, adults 25+ |
| unemployment_rate | percentage | Unemployment rate | ACS, BLS | Range: 0-100 |
| labor_force_participation | percentage | Labor force participation rate | ACS | Range: 0-100, population 16+ |

### Housing Variables
| Variable | Units | Description | Source | Notes |
|----------|-------|-------------|--------|-------|
| median_home_value | dollars | Median value of owner-occupied housing units | ACS | Not adjusted for inflation |
| median_gross_rent | dollars | Median gross rent | ACS | Not adjusted for inflation |
| homeownership_rate | percentage | Percentage of occupied housing units that are owner-occupied | ACS | Range: 0-100 |
| vacant_housing_rate | percentage | Percentage of housing units that are vacant | ACS | Range: 0-100 |
| severe_housing_cost_burden | percentage | Percentage of households spending >50% of income on housing | ACS | Range: 0-100 |
| overcrowded_housing_pct | percentage | Percentage of housing units with >1 person per room | ACS | Range: 0-100 |
| housing_no_kitchen_pct | percentage | Percentage of housing units lacking complete kitchen facilities | ACS | Range: 0-100 |
| housing_no_plumbing_pct | percentage | Percentage of housing units lacking complete plumbing facilities | ACS | Range: 0-100 |
| severe_housing_problems | percentage | Percentage of households with at least 1 of 4 housing problems | CDC PLACES | Range: 0-100 |

### Transportation Variables
| Variable | Units | Description | Source | Notes |
|----------|-------|-------------|--------|-------|
| mean_commute_time | minutes | Mean commute time to work | ACS | One-way commute |
| commute_public_transit_pct | percentage | Percentage of workers using public transit | ACS | Range: 0-100 |
| commute_carpool_pct | percentage | Percentage of workers carpooling | ACS | Range: 0-100 |
| commute_walking_pct | percentage | Percentage of workers walking to work | ACS | Range: 0-100 |
| commute_long_pct | percentage | Percentage with commute >60 minutes | ACS | Range: 0-100 |
| no_vehicle_households_pct | percentage | Percentage of households with no vehicle available | ACS | Range: 0-100 |

### Health Insurance Variables
| Variable | Units | Description | Source | Notes |
|----------|-------|-------------|--------|-------|
| uninsured_pct | percentage | Percentage of population without health insurance | ACS | Range: 0-100 |
| private_health_insurance_pct | percentage | Percentage with private health insurance | ACS | Range: 0-100 |
| public_health_insurance_pct | percentage | Percentage with public health insurance | ACS | Range: 0-100 |
| medicaid_pct | percentage | Percentage enrolled in Medicaid | ACS | Range: 0-100 |
| medicare_pct | percentage | Percentage enrolled in Medicare | ACS | Range: 0-100 |
| no_health_insurance_pct | percentage | Percentage without health insurance | CDC PLACES | Range: 0-100 |

### Health Status Variables
| Variable | Units | Description | Source | Notes |
|----------|-------|-------------|--------|-------|
| life_expectancy | years | Life expectancy at birth | IHME | |
| obesity_pct | percentage | Percentage of adults with obesity (BMI ≥ 30) | CDC PLACES | Range: 0-100, age-adjusted |
| smoking_pct | percentage | Percentage of adults who smoke | CDC PLACES | Range: 0-100, age-adjusted |
| diabetes_pct | percentage | Percentage of adults with diagnosed diabetes | CDC PLACES | Range: 0-100, age-adjusted |
| physical_inactivity_pct | percentage | Percentage of adults with no leisure-time physical activity | CDC PLACES | Range: 0-100, age-adjusted |
| poor_mental_health_pct | percentage | Percentage reporting poor mental health for ≥14 days in past month | CDC PLACES | Range: 0-100, age-adjusted |
| poor_physical_health_pct | percentage | Percentage reporting poor physical health for ≥14 days in past month | CDC PLACES | Range: 0-100, age-adjusted |
| high_blood_pressure_pct | percentage | Percentage of adults with high blood pressure | CDC PLACES | Range: 0-100, age-adjusted |
| high_cholesterol_pct | percentage | Percentage of adults with high cholesterol | CDC PLACES | Range: 0-100, age-adjusted |
| asthma_pct | percentage | Percentage of adults with asthma | CDC PLACES | Range: 0-100, age-adjusted |
| copd_pct | percentage | Percentage of adults with COPD | CDC PLACES | Range: 0-100, age-adjusted |
| coronary_heart_disease_pct | percentage | Percentage of adults with coronary heart disease | CDC PLACES | Range: 0-100, age-adjusted |
| kidney_disease_pct | percentage | Percentage of adults with kidney disease | CDC PLACES | Range: 0-100, age-adjusted |
| stroke_pct | percentage | Percentage of adults who have had a stroke | CDC PLACES | Range: 0-100, age-adjusted |
| cancer_pct | percentage | Percentage of adults with cancer (excluding skin cancer) | CDC PLACES | Range: 0-100, age-adjusted |
| depression_pct | percentage | Percentage of adults with depression | CDC PLACES | Range: 0-100, age-adjusted |
| arthritis_pct | percentage | Percentage of adults with arthritis | CDC PLACES | Range: 0-100, age-adjusted |
| annual_checkup_pct | percentage | Percentage who had a routine checkup in past year | CDC PLACES | Range: 0-100, age-adjusted |
| dental_visit_pct | percentage | Percentage who visited a dentist in past year | CDC PLACES | Range: 0-100, age-adjusted |

### Social Context Variables
| Variable | Units | Description | Source | Notes |
|----------|-------|-------------|--------|-------|
| single_parent_households_pct | percentage | Percentage of households with single parent | ACS | Range: 0-100 |
| limited_english_pct | percentage | Percentage of households with limited English | ACS | Range: 0-100 |
| non_english_home_pct | percentage | Percentage speaking language other than English at home | ACS | Range: 0-100 |
| broadband_access_pct | percentage | Percentage of households with broadband internet | ACS | Range: 0-100 |
| internet_access_pct | percentage | Percentage of households with internet access | ACS | Range: 0-100 |
| computer_access_pct | percentage | Percentage of households with a computer | ACS | Range: 0-100 |
| grandparents_caregivers_pct | percentage | Percentage of grandparents responsible for grandchildren | ACS | Range: 0-100 |
| binge_drinking_pct | percentage | Percentage of adults reporting binge drinking | CDC PLACES | Range: 0-100, age-adjusted |
| insufficient_sleep_pct | percentage | Percentage of adults with insufficient sleep (<7 hours) | CDC PLACES | Range: 0-100, age-adjusted |
| air_pollution_pm25 | μg/m³ | Annual average ambient PM2.5 concentration | CDC PLACES | Micrograms per cubic meter |

### Disability Variables
| Variable | Units | Description | Source | Notes |
|----------|-------|-------------|--------|-------|
| disability_pct | percentage | Percentage of population with a disability | ACS | Range: 0-100 |
| disability_under_18_pct | percentage | Percentage under 18 with a disability | ACS | Range: 0-100 |
| disability_18_64_pct | percentage | Percentage 18-64 with a disability | ACS | Range: 0-100 |
| disability_65_over_pct | percentage | Percentage 65+ with a disability | ACS | Range: 0-100 |
| cognitive_disability_pct | percentage | Percentage with cognitive difficulty | ACS | Range: 0-100 |
| ambulatory_disability_pct | percentage | Percentage with ambulatory difficulty | ACS | Range: 0-100 |
| independent_living_disability_pct | percentage | Percentage with independent living difficulty | ACS | Range: 0-100 |

## Maps and Visualization

The pipeline generates county-level choropleth maps for all available variables and years. Maps are organized in the `output/maps/` directory, with each variable having its own subdirectory.

For each variable, maps are generated for all available years, using appropriate color scales and consistent formatting. Map filenames include both the variable name and year for easy identification.

## Shapefiles and Geographic Data

County boundary files for mapping are stored in the `data/shapefiles/` directory:

- **counties_YEAR.rds**: County boundary shapefiles for benchmark years (1990, 2000, 2010, 2020)
- **counties_YEAR_metadata.txt**: Metadata about each shapefile
- **shapefile_index.csv**: Index of all available shapefiles

Mapping between data years and boundary files:
- 1970-1995: Use 1990 boundaries
- 1996-2005: Use 2000 boundaries
- 2006-2015: Use 2010 boundaries
- 2016-present: Use 2020 boundaries

## No-Simulation Mode

The pipeline is configured to use real data by default and not generate simulated values:

1. When starting, it checks for real data files
2. It fails with a clear error message if no real data files are found
3. It requires data files in the appropriate directories:
   - `data/nhgis/` for NHGIS files
   - `data/ihme/CSV/` for IHME life expectancy files
   - `data/cdc_places/` for CDC PLACES data

To enable simulation for testing (not recommended for production):
```bash
Rscript main_extended.r --allow-simulation
```

## DuckDB Database Structure and Access

The pipeline stores data in a DuckDB database, which is a high-performance analytical database system designed for analytical workloads. The database file is stored as `us_county_sdoh_data.duckdb`.

### Database Tables

The database contains the following main tables:

- `county_sdoh_data`: Main data table with all variables by county and year
- `county_metadata`: Information about each county
- `data_dictionary`: Descriptions and metadata for each variable
- `variable_crosswalk`: Mapping between standardized variable names and source-specific codes
- `data_quality_summary`: Summary of data completeness by year and source
- `data_quality_detailed`: Detailed information about interpolation and extension

### Database Views

The database includes several prebuilt views:

- `latest_county_data`: The most recent data available for each county
- `county_time_series`: All years of data for all counties
- `county_health_metrics`: Health-specific metrics for all counties
- Several category-specific views (demographics, socioeconomic, etc.)

### Accessing DuckDB from Different Languages

#### From R

```r
# Using DBI package
library(DBI)
library(duckdb)

# Connect to the database
con <- dbConnect(duckdb::duckdb(), "path/to/us_county_sdoh_data.duckdb", read_only = TRUE)

# Query data
result <- dbGetQuery(con, "SELECT * FROM latest_county_data WHERE poverty_rate < 10")

# List tables
tables <- dbListTables(con)

# Disconnect when done
dbDisconnect(con)
```

#### From Python

```python
# Using duckdb package
import duckdb
import pandas as pd

# Connect to the database
conn = duckdb.connect("path/to/us_county_sdoh_data.duckdb", read_only=True)

# Query data (returns pandas DataFrame)
df = conn.execute("SELECT * FROM latest_county_data WHERE poverty_rate < 10").fetchdf()

# List tables
tables = conn.execute("SHOW TABLES").fetchall()

# Close connection when done
conn.close()
```

#### From Julia

```julia
# Using DuckDB.jl package
using DuckDB
using DataFrames

# Connect to the database
conn = DBInterface.connect(DuckDB.DB, "path/to/us_county_sdoh_data.duckdb")

# Query data
df = DataFrame(DBInterface.execute(conn, "SELECT * FROM latest_county_data WHERE poverty_rate < 10"))

# List tables
tables = DataFrame(DBInterface.execute(conn, "SHOW TABLES"))

# Close connection when done
DBInterface.close!(conn)
```

### SQL Example Queries

```sql
-- Get the counties with the highest poverty rates
SELECT GEOID, NAME, year, poverty_rate 
FROM latest_county_data 
WHERE poverty_rate IS NOT NULL 
ORDER BY poverty_rate DESC 
LIMIT 10;

-- Compare health metrics between counties with high and low education levels
SELECT 
  CASE 
    WHEN bachelors_or_higher_pct > 40 THEN 'High Education' 
    WHEN bachelors_or_higher_pct < 15 THEN 'Low Education'
    ELSE 'Medium Education'
  END as education_group,
  COUNT(*) as county_count,
  AVG(life_expectancy) as avg_life_expectancy,
  AVG(obesity_pct) as avg_obesity_rate,
  AVG(smoking_pct) as avg_smoking_rate
FROM latest_county_data
WHERE bachelors_or_higher_pct IS NOT NULL
  AND life_expectancy IS NOT NULL
GROUP BY education_group
ORDER BY education_group;

-- Track poverty rate over time for a specific county
SELECT year, poverty_rate
FROM county_sdoh_data
WHERE GEOID = '06037' -- Los Angeles County
ORDER BY year;
```

### DuckDB Performance Tips

1. **Use Filters Early**: Apply WHERE clauses to filter data as early as possible
2. **Avoid SELECT ***: Only select the columns you need
3. **Use Prepared Statements**: For repeated queries with different parameters
4. **Use Views**: Leverage the pre-built views for common queries
5. **Consider Parallelism**: DuckDB can utilize multiple cores for query execution

## Troubleshooting

If you encounter issues:

1. **No NHGIS/IHME data**: Ensure data files are present in the appropriate directories
   - Check for files in `data/nhgis/` and `data/ihme/CSV/`
   - Use `Rscript test_nhgis_fix.r` to diagnose data file issues

2. **Memory errors during interpolation**:
   - Run with `--skip-interpolation` flag
   - Use the `run_parallel_pipeline.r` script for optimized parallel processing

3. **Pipeline stalls or crashes**:
   - Check log files in the `logs/` directory
   - Use `Rscript fix_restart_pipeline.r` to diagnose and fix issues
   - Try `Rscript clear_cache.r` to remove potentially corrupted cache files

4. **Monitoring progress**:
   - Use `Rscript monitor_pipeline.r --live` for real-time monitoring
   - Use `Rscript check_pipeline_status.r` for a quick status check

## Requirements

The pipeline requires:

1. **R packages**:
   - tidyverse (dplyr, tidyr, ggplot2, etc.)
   - tidycensus, tigris, sf (for Census API and geographic data)
   - DBI, duckdb (for database operations)
   - zoo (for interpolation)
   - viridis (for maps)

2. **Data files**:
   - NHGIS data files in `data/nhgis/`
   - IHME life expectancy files in `data/ihme/CSV/`
   - CDC PLACES data in `data/cdc_places/`

3. **Credentials**:
   - Census API key (set in environment or in .Renviron)
   - IPUMS credentials (if using API access)

## Utility Scripts

The pipeline includes several utility scripts:

- **monitor_pipeline.r**: Real-time monitoring of pipeline progress
- **check_braces.r**: Checks for syntax errors in R scripts
- **clear_cache.r**: Manages and clears the data cache
- **check_pipeline_status.r**: Provides pipeline status overview
- **fix_restart_pipeline.r**: Diagnoses and fixes pipeline issues
- **restart_pipeline.r**: Auto-generated script to restart the pipeline
- **emergency_restart.r**: Special restart for crashed pipelines

## Citation

If you use this dataset in your research or applications, please cite it as:

```
Social Determinants of Health County-Level Dataset (2025). Generated using data from U.S. Census Bureau, CDC PLACES, IPUMS NHGIS, and IHME.
```