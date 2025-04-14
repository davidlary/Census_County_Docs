# NHGIS Data Fix

This document explains the changes made to fix the recurring NHGIS data issue in the county-level social determinants of health data pipeline.

## Problem
The pipeline was unable to find or correctly use NHGIS data files, even though they existed in `/Users/davidlary/Dropbox/Environments/Code/GetData/US-Census-Claude/County/census_time_series/R/data/ihme/CSV` and a credentials script existed at `/Users/davidlary/Dropbox/Environments/Code/GetData/US-Census-Claude/County/census_time_series/R/utilities/load_ipums_credentials.r`.

## Solution
Multiple changes were made to address this issue:

1. **Properly source the IPUMS credentials script**
   - Modified `main_optimized.r` to correctly source the existing credentials file
   - Added explicit error handling for credential loading

2. **Find IHME data and make it available to the NHGIS module**
   - Added code to check the IHME directory for data files
   - Created symbolic links (Unix/Mac) or copied files (Windows) from the IHME directory to the NHGIS directory
   - Updated the search patterns to handle case sensitivity (.csv vs .CSV)

3. **Enhanced IHME file format detection and parsing**
   - Added special handling for IHME life expectancy files
   - Modified the parser to extract years from IHME filenames
   - Added standardized conversion of IHME data to the format needed by the pipeline
   
4. **Improved directory checking and creation**
   - Added code to check for the existence of all required directories
   - Added logic to display helpful messages about where files are found
   - Created a broader search for NHGIS/IHME data files across the data directory hierarchy

## New Scripts

1. **run_optimized.r**
   - A launcher script that sets up the environment correctly
   - Checks for and makes IHME data available to the NHGIS module
   - Sources the credentials file if it exists

2. **test_nhgis_fix.r**
   - A test script to verify that the fix is working
   - Checks for credentials and data files
   - Tests the IHME file processing functionality
   - Reports whether real or simulated data is being used

## Usage

To run the optimized pipeline with the fixes:

```
Rscript run_optimized.r
```

To test just the NHGIS data fix:

```
Rscript test_nhgis_fix.r
```

## Technical Details

1. The fix creates symbolic links (on Unix/Mac) or copies files (on Windows) from the IHME directory to the NHGIS directory, making the existing data files available where the pipeline expects to find them.

2. The IHME file parser now extracts years from filenames following the pattern:
   `IHME_USA_LE_COUNTY_RACE_ETHN_2000_2019_LT_2010_BOTH_Y2022M06D16.CSV`
   Where 2010 is the year to extract.

3. The pipeline now sources the existing credentials script and properly sets the IPUMS credentials environment variables.

4. Directory checks now use case-insensitive patterns to find both .csv and .CSV files.

5. The pipeline now shows detailed information about where data files are found and how they're being processed.

## Future Improvements

For future development, consider:

1. Making a universal data location configuration that isn't hard-coded
2. Consolidating credentials management into a single approach
3. Adding explicit support for IHME files rather than treating them as NHGIS files
4. Providing a UI/config file for setting paths to data directories