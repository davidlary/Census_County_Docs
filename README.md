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

## Variable Categories

The pipeline processes over 80 variables across multiple categories:

### Demographic Variables
- total_population, male_population, female_population
- median_age, population_under_18, population_65_over
- white_nonhispanic_pct, black_pct, hispanic_latino_pct, asian_pct, native_american_pct
- population_density

### Socioeconomic Variables
- median_household_income, median_earnings, poverty_rate
- gini_index, snap_benefits_pct, food_insecurity_pct
- less_than_highschool_pct, highschool_only_pct, some_college_pct, bachelors_or_higher_pct
- unemployment_rate, labor_force_participation

### Housing Variables
- median_home_value, median_gross_rent, homeownership_rate
- vacant_housing_rate, severe_housing_cost_burden, overcrowded_housing_pct
- housing_no_kitchen_pct, housing_no_plumbing_pct
- severe_housing_problems

### Transportation Variables
- mean_commute_time, commute_public_transit_pct, commute_carpool_pct
- commute_walking_pct, commute_long_pct, no_vehicle_households_pct

### Health Insurance Variables
- uninsured_pct, private_health_insurance_pct, public_health_insurance_pct
- medicaid_pct, medicare_pct, no_health_insurance_pct

### Health Status Variables
- life_expectancy, obesity_pct, smoking_pct, diabetes_pct
- physical_inactivity_pct, poor_mental_health_pct, poor_physical_health_pct
- high_blood_pressure_pct, high_cholesterol_pct, asthma_pct, copd_pct
- coronary_heart_disease_pct, kidney_disease_pct, stroke_pct, cancer_pct
- depression_pct, arthritis_pct, annual_checkup_pct, dental_visit_pct

### Social Context Variables
- single_parent_households_pct, limited_english_pct, non_english_home_pct
- broadband_access_pct, internet_access_pct, computer_access_pct
- grandparents_caregivers_pct, binge_drinking_pct, insufficient_sleep_pct
- air_pollution_pm25

### Disability Variables
- disability_pct, disability_under_18_pct, disability_18_64_pct, disability_65_over_pct
- cognitive_disability_pct, ambulatory_disability_pct, independent_living_disability_pct

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