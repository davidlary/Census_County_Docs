library(tidyverse)
library(duckdb)
library(sf)
library(tigris)
library(ggplot2)
library(viridis)
library(corrplot)
library(patchwork)
library(tidytext)  # For word cloud

#' Example Analysis of Social Determinants of Health County Data
#' 
#' This script demonstrates several analyses that can be performed
#' using the enhanced SDOH county dataset.

# Connect to the database
con <- dbConnect(duckdb(), "us_county_sdoh_data.duckdb")

# Part 1: Basic Exploration -----------------------------------------------------

# Check what variables are available
variables <- dbGetQuery(con, "SELECT * FROM data_dictionary WHERE available_in_dataset = TRUE")
print(paste("Total variables available:", nrow(variables)))

# Get the top 10 variables from each category
top_vars_by_category <- dbGetQuery(con, "
  WITH category_vars AS (
    SELECT 
      category, 
      std_name, 
      ROW_NUMBER() OVER (PARTITION BY category ORDER BY std_name) as category_rank
    FROM data_dictionary
    WHERE available_in_dataset = TRUE
  )
  SELECT category, std_name
  FROM category_vars
  WHERE category_rank <= 3
  ORDER BY category, category_rank
")
print(top_vars_by_category)

# Get latest data
latest_data <- dbGetQuery(con, "SELECT * FROM latest_county_data")
cat("Latest data has", nrow(latest_data), "counties and", ncol(latest_data), "columns\n")

# Basic statistical summary of key variables
key_vars <- c("total_population", "median_household_income", "poverty_rate", 
             "uninsured_pct", "obesity_pct", "diabetes_pct")

summary_stats <- latest_data %>%
  select(all_of(key_vars)) %>%
  summary()

print(summary_stats)

# Part 2: Temporal Trends -------------------------------------------------------

# Get time series data for US overall
national_trends <- dbGetQuery(con, "
  WITH county_years AS (
    SELECT 
      year,
      AVG(poverty_rate) as poverty_rate,
      AVG(median_household_income) as median_household_income,
      AVG(uninsured_pct) as uninsured_pct,
      SUM(total_population) as total_population,
      COUNT(DISTINCT GEOID) as county_count
    FROM county_sdoh_data
    WHERE 
      year BETWEEN 2000 AND 2021
      AND poverty_rate IS NOT NULL
    GROUP BY year
    ORDER BY year
  )
  SELECT *
  FROM county_years
")

# Plot national trends
poverty_trend_plot <- ggplot(national_trends, aes(x = year, y = poverty_rate)) +
  geom_line(color = "darkred", size = 1) +
  geom_point(color = "darkred", size = 2) +
  theme_minimal() +
  labs(title = "National Average Poverty Rate Over Time",
       x = "Year", 
       y = "Average Poverty Rate (%)",
       caption = "Based on county averages (not population-weighted)") +
  theme(plot.title = element_text(face = "bold"))

income_trend_plot <- ggplot(national_trends, aes(x = year, y = median_household_income)) +
  geom_line(color = "darkblue", size = 1) +
  geom_point(color = "darkblue", size = 2) +
  theme_minimal() +
  labs(title = "National Median Household Income Over Time",
       x = "Year", 
       y = "Average Median Household Income ($)",
       caption = "Based on county averages (not population-weighted)") +
  theme(plot.title = element_text(face = "bold"))

# Combine plots
combined_trends <- poverty_trend_plot / income_trend_plot
print(combined_trends)

# Part 3: Geographic Variation --------------------------------------------------

# Get county boundaries for mapping
counties_sf <- counties(cb = TRUE, year = 2021) %>%
  select(GEOID, NAME, STUSPS) %>%
  st_transform(4326)  # WGS84 projection

# Join with our data
counties_data <- counties_sf %>%
  left_join(latest_data, by = "GEOID")

# Create a map of poverty rates
poverty_map <- ggplot(counties_data) +
  geom_sf(aes(fill = poverty_rate), color = NA) +
  scale_fill_viridis(option = "plasma", name = "Poverty Rate (%)",
                    na.value = "gray90") +
  theme_minimal() +
  labs(title = "County-Level Poverty Rates",
       subtitle = "Based on most recent available data",
       caption = "Source: Enhanced SDOH County Dataset") +
  theme(legend.position = "right",
        plot.title = element_text(face = "bold"),
        axis.text.x = element_blank(),
        axis.text.y = element_blank())

# Create a map of uninsured rates
uninsured_map <- ggplot(counties_data) +
  geom_sf(aes(fill = uninsured_pct), color = NA) +
  scale_fill_viridis(option = "viridis", name = "Uninsured (%)",
                    na.value = "gray90") +
  theme_minimal() +
  labs(title = "County-Level Uninsured Rates",
       subtitle = "Based on most recent available data",
       caption = "Source: Enhanced SDOH County Dataset") +
  theme(legend.position = "right",
        plot.title = element_text(face = "bold"),
        axis.text.x = element_blank(),
        axis.text.y = element_blank())

# Combine maps
combined_maps <- poverty_map / uninsured_map
print(combined_maps)

# Part 4: Correlation Analysis and Life Expectancy ------------------------------

# Select key variables for correlation analysis
cor_vars <- c("poverty_rate", "median_household_income", "uninsured_pct",
              "obesity_pct", "diabetes_pct", "high_blood_pressure_pct",
              "bachelors_or_higher_pct", "unemployment_rate", 
              "life_expectancy", "disability_pct", "grandparents_caregivers_pct",
              "internet_access_pct")

# Create correlation matrix
cor_data <- latest_data %>%
  select(all_of(cor_vars)) %>%
  drop_na()  # Remove rows with NA values

cor_matrix <- cor(cor_data, use = "pairwise.complete.obs")
print(cor_matrix)

# Plot correlation matrix
corrplot(cor_matrix, method = "circle", type = "upper", 
         order = "hclust", tl.col = "black", tl.srt = 45,
         title = "Correlation Between Social Determinants of Health",
         mar = c(0, 0, 1, 0))

# Life expectancy analysis
# Check the counties with highest and lowest life expectancy
life_expectancy_analysis <- latest_data %>%
  select(GEOID, NAME, life_expectancy, life_expectancy_female, life_expectancy_male) %>%
  filter(!is.na(life_expectancy)) %>%
  mutate(gender_gap = life_expectancy_female - life_expectancy_male)

# Top 10 counties by life expectancy
top_life_expectancy <- life_expectancy_analysis %>%
  arrange(desc(life_expectancy)) %>%
  head(10)
print("Counties with highest life expectancy:")
print(top_life_expectancy)

# Bottom 10 counties by life expectancy
bottom_life_expectancy <- life_expectancy_analysis %>%
  arrange(life_expectancy) %>%
  head(10)
print("Counties with lowest life expectancy:")
print(bottom_life_expectancy)

# Counties with highest gender gap in life expectancy
gender_gap_counties <- life_expectancy_analysis %>%
  arrange(desc(gender_gap)) %>%
  head(10)
print("Counties with highest gender gap in life expectancy (female - male):")
print(gender_gap_counties)

# Part 5: Urban-Rural Comparison ------------------------------------------------

# Add county size classification based on population
latest_data_classified <- latest_data %>%
  mutate(county_size = case_when(
    total_population >= 1000000 ~ "Large Metro (1M+)",
    total_population >= 250000 ~ "Medium Metro (250K-1M)",
    total_population >= 50000 ~ "Small Metro (50K-250K)",
    total_population >= 10000 ~ "Micropolitan (10K-50K)",
    TRUE ~ "Rural (<10K)"
  ),
  county_size = factor(county_size, levels = c(
    "Large Metro (1M+)", "Medium Metro (250K-1M)", 
    "Small Metro (50K-250K)", "Micropolitan (10K-50K)", "Rural (<10K)"
  )))

# Compare health outcomes by county size
urban_rural_comparison <- latest_data_classified %>%
  group_by(county_size) %>%
  summarise(
    num_counties = n(),
    avg_poverty_rate = mean(poverty_rate, na.rm = TRUE),
    avg_obesity_pct = mean(obesity_pct, na.rm = TRUE),
    avg_diabetes_pct = mean(diabetes_pct, na.rm = TRUE),
    avg_uninsured_pct = mean(uninsured_pct, na.rm = TRUE),
    avg_bachelor_plus = mean(bachelors_or_higher_pct, na.rm = TRUE),
    .groups = "drop"
  )

print(urban_rural_comparison)

# Plot urban-rural comparison
urban_rural_long <- urban_rural_comparison %>%
  select(-num_counties) %>%
  pivot_longer(-county_size, names_to = "variable", values_to = "value") %>%
  mutate(
    variable = case_when(
      variable == "avg_poverty_rate" ~ "Poverty Rate",
      variable == "avg_obesity_pct" ~ "Obesity Rate",
      variable == "avg_diabetes_pct" ~ "Diabetes Rate",
      variable == "avg_uninsured_pct" ~ "Uninsured Rate",
      variable == "avg_bachelor_plus" ~ "Bachelor's Degree or Higher",
      TRUE ~ variable
    )
  )

urban_rural_plot <- ggplot(urban_rural_long, 
                         aes(x = county_size, y = value, fill = county_size)) +
  geom_col() +
  facet_wrap(~variable, scales = "free_y") +
  theme_minimal() +
  scale_fill_viridis_d() +
  labs(title = "Health and Socioeconomic Indicators by County Size",
       x = "", y = "Percentage", fill = "County Size") +
  theme(legend.position = "bottom",
        axis.text.x = element_text(angle = 45, hjust = 1),
        plot.title = element_text(face = "bold"))

print(urban_rural_plot)

# Part 6: Finding Counties with Most Improvement --------------------------------

# Get counties with most improvement in poverty rate since 2010
poverty_improvement <- dbGetQuery(con, "
  WITH county_periods AS (
    SELECT 
      a.GEOID, 
      a.NAME,
      a.poverty_rate as poverty_2010,
      b.poverty_rate as poverty_latest,
      b.year as latest_year,
      a.poverty_rate - b.poverty_rate as poverty_decrease
    FROM 
      county_sdoh_data a
    JOIN (
      SELECT GEOID, MAX(year) as max_year
      FROM county_sdoh_data
      WHERE poverty_rate IS NOT NULL
      GROUP BY GEOID
    ) latest ON a.GEOID = latest.GEOID
    JOIN county_sdoh_data b ON a.GEOID = b.GEOID AND b.year = latest.max_year
    WHERE a.year = 2010
      AND a.poverty_rate IS NOT NULL
      AND b.poverty_rate IS NOT NULL
  )
  SELECT 
    GEOID, NAME, poverty_2010, poverty_latest, latest_year,
    poverty_decrease, 
    ROUND(100.0 * poverty_decrease / poverty_2010, 1) as pct_improvement
  FROM county_periods
  WHERE poverty_decrease > 0
  ORDER BY pct_improvement DESC
  LIMIT 20
")

# Show the counties with most improvement
print(poverty_improvement)

# Part 7: Health Metrics Clustering ---------------------------------------------

# Cluster counties based on health metrics
health_clustering <- latest_data %>%
  select(GEOID, NAME, obesity_pct, diabetes_pct, poor_physical_health_pct, 
         poor_mental_health_pct, smoking_pct, high_blood_pressure_pct) %>%
  drop_na()  # Remove rows with NA values

# Standardize the data
health_clustering_scaled <- health_clustering %>%
  mutate(across(c(obesity_pct, diabetes_pct, poor_physical_health_pct, 
                 poor_mental_health_pct, smoking_pct, high_blood_pressure_pct),
                scale))

# Perform k-means clustering
set.seed(123)
k <- 5  # Number of clusters
health_clusters <- kmeans(health_clustering_scaled %>% select(-GEOID, -NAME), centers = k)

# Add cluster assignments back to the data
health_clustering <- health_clustering %>%
  mutate(cluster = as.factor(health_clusters$cluster))

# Summarize each cluster
cluster_summary <- health_clustering %>%
  group_by(cluster) %>%
  summarise(
    n_counties = n(),
    avg_obesity = mean(obesity_pct),
    avg_diabetes = mean(diabetes_pct),
    avg_poor_physical = mean(poor_physical_health_pct),
    avg_poor_mental = mean(poor_mental_health_pct),
    avg_smoking = mean(smoking_pct),
    avg_high_bp = mean(high_blood_pressure_pct),
    .groups = "drop"
  ) %>%
  arrange(avg_poor_physical)  # Order by one health metric

print(cluster_summary)

# Join cluster information with county data for mapping
counties_with_clusters <- counties_data %>%
  left_join(health_clustering %>% select(GEOID, cluster), by = "GEOID")

# Plot clusters on a map
cluster_map <- ggplot(counties_with_clusters) +
  geom_sf(aes(fill = cluster), color = NA) +
  scale_fill_viridis_d(name = "Health Profile Cluster",
                       na.value = "gray90") +
  theme_minimal() +
  labs(title = "County Health Profile Clusters",
       subtitle = "Based on obesity, diabetes, physical health, mental health, smoking, and blood pressure",
       caption = "Source: Enhanced SDOH County Dataset") +
  theme(legend.position = "right",
        plot.title = element_text(face = "bold"),
        axis.text.x = element_blank(),
        axis.text.y = element_blank())

print(cluster_map)

# Part 8: Identifying Critical Counties -----------------------------------------

# Find counties with multiple poor outcomes
critical_counties <- latest_data %>%
  mutate(
    high_poverty = poverty_rate > quantile(poverty_rate, 0.75, na.rm = TRUE),
    high_uninsured = uninsured_pct > quantile(uninsured_pct, 0.75, na.rm = TRUE),
    high_obesity = obesity_pct > quantile(obesity_pct, 0.75, na.rm = TRUE),
    high_diabetes = diabetes_pct > quantile(diabetes_pct, 0.75, na.rm = TRUE),
    critical_score = (high_poverty * 1) + (high_uninsured * 1) + 
                     (high_obesity * 1) + (high_diabetes * 1)
  ) %>%
  filter(!is.na(critical_score)) %>%
  arrange(desc(critical_score))

# Identify counties with all four poor outcomes
most_critical <- critical_counties %>%
  filter(critical_score >= 4) %>%
  select(GEOID, NAME, poverty_rate, uninsured_pct, obesity_pct, diabetes_pct, critical_score)

print(most_critical)

# Plot critical counties on map
counties_with_critical <- counties_data %>%
  left_join(critical_counties %>% select(GEOID, critical_score), by = "GEOID")

critical_map <- ggplot(counties_with_critical) +
  geom_sf(aes(fill = critical_score), color = NA) +
  scale_fill_viridis(option = "magma", name = "Critical Score\n(0-4)",
                    na.value = "gray90", limits = c(0, 4)) +
  theme_minimal() +
  labs(title = "Counties with Multiple Poor Health and Economic Outcomes",
       subtitle = "Score based on high poverty, uninsured, obesity, and diabetes rates",
       caption = "Source: Enhanced SDOH County Dataset") +
  theme(legend.position = "right",
        plot.title = element_text(face = "bold"),
        axis.text.x = element_blank(),
        axis.text.y = element_blank())

print(critical_map)

# Part 9: Regression Analysis ---------------------------------------------------

# Run regression model to predict diabetes rates from socioeconomic factors
diabetes_model_data <- latest_data %>%
  select(GEOID, diabetes_pct, poverty_rate, median_household_income, 
         uninsured_pct, obesity_pct, bachelors_or_higher_pct) %>%
  drop_na()

diabetes_model <- lm(diabetes_pct ~ poverty_rate + median_household_income + 
                    uninsured_pct + obesity_pct + bachelors_or_higher_pct, 
                    data = diabetes_model_data)

# Show model summary
model_summary <- summary(diabetes_model)
print(model_summary)

# Extract key model metrics
model_r2 <- round(model_summary$r.squared, 3)
model_adj_r2 <- round(model_summary$adj.r.squared, 3)

cat("R-squared:", model_r2, "\n")
cat("Adjusted R-squared:", model_adj_r2, "\n")

# Create residuals map
diabetes_model_data$predicted <- predict(diabetes_model)
diabetes_model_data$residuals <- diabetes_model_data$diabetes_pct - diabetes_model_data$predicted

counties_with_residuals <- counties_data %>%
  left_join(diabetes_model_data %>% select(GEOID, residuals), by = "GEOID")

residuals_map <- ggplot(counties_with_residuals) +
  geom_sf(aes(fill = residuals), color = NA) +
  scale_fill_gradient2(name = "Residuals", 
                      low = "blue", mid = "white", high = "red",
                      midpoint = 0,
                      na.value = "gray90") +
  theme_minimal() +
  labs(title = "Diabetes Rate Model Residuals by County",
       subtitle = paste0("Based on regression model with R² = ", model_r2),
       caption = "Blue = lower than predicted, Red = higher than predicted") +
  theme(legend.position = "right",
        plot.title = element_text(face = "bold"),
        axis.text.x = element_blank(),
        axis.text.y = element_blank())

print(residuals_map)

# Part 10: New Extended Variables Analysis --------------------------------------

# Disability analysis
cat("\n\nDisability Analysis:\n")
disability_data <- latest_data %>%
  select(GEOID, NAME, contains("disability")) %>%
  drop_na(disability_pct)

# Basic statistics on disability rates
disability_stats <- disability_data %>%
  summarize(
    counties_with_data = n(),
    avg_disability_rate = mean(disability_pct, na.rm = TRUE),
    min_disability_rate = min(disability_pct, na.rm = TRUE),
    max_disability_rate = max(disability_pct, na.rm = TRUE),
    
    avg_disability_under18 = mean(disability_under_18_pct, na.rm = TRUE),
    avg_disability_18_64 = mean(disability_18_64_pct, na.rm = TRUE),
    avg_disability_65_over = mean(disability_65_over_pct, na.rm = TRUE),
    
    avg_cognitive_disability = mean(cognitive_disability_pct, na.rm = TRUE),
    avg_ambulatory_disability = mean(ambulatory_disability_pct, na.rm = TRUE),
    avg_independent_living_disability = mean(independent_living_disability_pct, na.rm = TRUE)
  )

print(disability_stats)

# Counties with highest disability rates
top_disability_counties <- disability_data %>%
  arrange(desc(disability_pct)) %>%
  select(NAME, disability_pct, cognitive_disability_pct, ambulatory_disability_pct) %>%
  head(10)

cat("\nCounties with highest disability rates:\n")
print(top_disability_counties)

# Grandparents as caregivers analysis
cat("\n\nGrandparents as Caregivers Analysis:\n")
grandparents_data <- latest_data %>%
  select(GEOID, NAME, grandparents_caregivers_pct, poverty_rate, median_household_income) %>%
  filter(!is.na(grandparents_caregivers_pct))

grandparents_stats <- grandparents_data %>%
  summarize(
    counties_with_data = n(),
    avg_grandparents_caregivers = mean(grandparents_caregivers_pct, na.rm = TRUE),
    min_grandparents_caregivers = min(grandparents_caregivers_pct, na.rm = TRUE),
    max_grandparents_caregivers = max(grandparents_caregivers_pct, na.rm = TRUE)
  )

print(grandparents_stats)

# Counties with highest rates of grandparents as caregivers
top_grandparents_counties <- grandparents_data %>%
  arrange(desc(grandparents_caregivers_pct)) %>%
  select(NAME, grandparents_caregivers_pct, poverty_rate, median_household_income) %>%
  head(10)

cat("\nCounties with highest rates of grandparents as caregivers:\n")
print(top_grandparents_counties)

# Internet access analysis
cat("\n\nInternet Access Analysis:\n")
internet_data <- latest_data %>%
  select(GEOID, NAME, internet_access_pct, broadband_access_pct, computer_access_pct, poverty_rate, median_household_income) %>%
  filter(!is.na(internet_access_pct) | !is.na(broadband_access_pct))

internet_stats <- internet_data %>%
  summarize(
    counties_with_data = n(),
    avg_internet_access = mean(internet_access_pct, na.rm = TRUE),
    avg_broadband_access = mean(broadband_access_pct, na.rm = TRUE),
    avg_computer_access = mean(computer_access_pct, na.rm = TRUE),
    min_internet_access = min(internet_access_pct, na.rm = TRUE),
    max_internet_access = max(internet_access_pct, na.rm = TRUE)
  )

print(internet_stats)

# Counties with lowest internet access
bottom_internet_counties <- internet_data %>%
  arrange(internet_access_pct) %>%
  select(NAME, internet_access_pct, broadband_access_pct, computer_access_pct, poverty_rate) %>%
  head(10)

cat("\nCounties with lowest internet access rates:\n")
print(bottom_internet_counties)

# Part 11: Save Results and Close ----------------------------------------------

# Save some plots
ggsave("poverty_trends.png", plot = poverty_trend_plot, width = 10, height = 6)
ggsave("critical_counties.png", plot = critical_map, width = 12, height = 8)
ggsave("urban_rural_comparison.png", plot = urban_rural_plot, width = 12, height = 8)

# Close database connection
dbDisconnect(con)

# Print end message
cat("\nAnalysis complete! Key findings:\n")
cat("1. Identified", nrow(most_critical), "counties with critical health and economic needs\n")
cat("2. Found", nrow(poverty_improvement), "counties with significant poverty improvement\n")
cat("3. Identified", k, "distinct county health profiles through clustering\n")
cat("4. Socioeconomic factors explain", paste0(round(model_r2 * 100), "%"), "of variation in diabetes rates\n")
cat("5. Strong urban-rural disparities observed in multiple health metrics\n")
cat("6. Life expectancy data analyzed for counties, including gender disparities\n")
cat("7. Analyzed disability rates across age groups and types\n")
cat("8. Examined grandparents serving as primary caregivers for children\n")
cat("9. Assessed internet and digital access disparities across counties\n\n")