
## Table diagnostics, cleaning and export

# Written by Ida M. Mienna
# Adapted by Ruben E. Roos
# Date written: October 2024

# The table should have the same structure and colnames as in export_dirty.xlsx.
filepath_2023 <- "P:/154027_effektovervaking_av_trua_arter_og_naturtyper_2024/07 Prikkrutevinge/Effektovervaaking_prikkrutevinge/Data/Data_Prikkrutevinge_2022_23.xlsx"
filepath_2024 <- "P:/154027_effektovervaking_av_trua_arter_og_naturtyper_2024/07 Prikkrutevinge/Effektovervaaking_prikkrutevinge/DataEffekt_prikkrutevinge_2024_processed/Effekt_prikkrutevinge_2024_export_dirty.xlsx"
filepath_treatments <- "P:/154027_effektovervaking_av_trua_arter_og_naturtyper_2024/07 Prikkrutevinge/Effektovervaaking_prikkrutevinge/Data/Management_overview_2024.xlsx"

## What should the exported files be marked as?
project <- "Effekt_prikkrutevinge_2022-24"

## Path to folder where the processed directories and files should be exported
outputpath <- "P:/154027_effektovervaking_av_trua_arter_og_naturtyper_2024/07 Prikkrutevinge/Effektovervaaking_prikkrutevinge/Data"

## If you have collected high-precision GPS points, let collctd_hpcoords be TRUE 
## and add the full file path with the coordinates. The coordinates should be in
## a csv format as when exporting the GPS points report. If you do not have 
## collctd_hpcoords, change hpcoords to FALSE.
#collctd_hpcoords <- FALSE 
#hpcoordspath <- "P:/154027_effektovervaking_av_trua_arter_og_naturtyper_2024/03 Dragehode/Dracocephalum/Effektovervaaking-Dracocephalum/Data/GPS_effektovervåking_dragehode_16102023.csv"

# Which crs do the coordinates have? Please write either EPSG:XXXXX (see example)
hpcrs <- "EPSG:25832" # EUREF89 UTM sone 32N

## Export dataset after cleaning? (Yes=TRUE, No=FALSE)
export_clean <- TRUE


# When you have edited all the points above to your liking, click "Source" 
# or Ctrl+Shift+Enter and continue to the next sections.


## ---------------------------------------------------------------------------##
##                           DATA CLEANING 
##                     CLEAN NAMES AND COORDINATES
## ---------------------------------------------------------------------------##

# Here, you should do the cleaning you otherwise would have done in Excel.
# The reason for doing this here is to have a reproducible method that others,
# but also you, can run through the data cleaning and end up with the same
# results as before.

# The data cleaning diagnostics itself will be run below under the section "DO 
# NOT CHANGE BELOW". This is to (hopefully) make it more obvious which parts in 
# the table that needs to be changed. I have added typical themes below but these
# can be further worked on beneath "DO NOT CHANGE BELOW" if needed.

## Export files for diagnostics? (Yes=TRUE, No=FALSE)
export_diagnostics <- TRUE

dat_2023 <- readxl::read_excel(filepath_2023)
dat_2024 <- readxl::read_excel(filepath_2024)
dat_treatments <- readxl::read_excel(filepath_treatments)

datasets <- list(dat_2023, dat_2024)

## DO NOT CHANGE (IMPORTING PACKAGES) ---------------------------------------------------------------
Sys.setlocale(locale='no_NB.utf8')

## Packages
packages <- c("dplyr", "readxl", "sf", "tidyr", "openxlsx", "stringr",
              "httr", "jsonlite", "purrr", "data.table", "readr", "mapview", "lubridate", "forcats")

# Require or install packages function
ipak <- function(pkg){
  new.pkg <- pkg[!(pkg %in% installed.packages()[, "Package"])]
  if (length(new.pkg)) 
    install.packages(new.pkg, dependencies = TRUE)
  sapply(pkg, require, character.only = TRUE)
}

ipak(packages)

## -----------------------------------------------------------------------------

#### Select relevant columns

#Create missing columns in 2022-23 data (are present in 2024 data and needed)
dat_2023 <- dat_2023 %>% 
  mutate(month = month(Date),
         day = day(Date))

#Renaming columns in 2022-23 data to match 2024 data, we can be strict here, not all data is needed for our analyses
dat_2023 <- dat_2023 %>% 
  rename(parenteventid = ParentGlobalID, 
        polygon_id = Polygon_ID, 
         plot_id = Plot_nr, 
         cover_field_layer = Cover_plants, 
         cover_vegetation_total = Cover_plants_summed, 
         cover_bottom_layer = Cover_bryophytes, 
         cover_standing_litter = Cover_standing_litter, 
         cover_rock = Cover_rock, 
         cover_bare_soil = Cover_bare_soil, 
         cover_short_vegetation = Cover_short_vegetation, 
         count_plantago = Count_smallkjempe, 
         count_spinn = Count_larvespinn, 
         vegheight1 = Veg_height_1, 
         vegheight2 = Veg_height_2, 
         vegheight3 = Veg_height_3, 
         vegheight4 = Veg_height_4, 
         species = Species, 
         species_cover = Cover_species,
         count_floral_stems = Count_flowers, 
         year = Year)
    

#Store columns we want in a list
selection <- list('parenteventid', 
                  'polygon_id', 
                  'plot_id', 
                  'cover_field_layer', 
                  'cover_vegetation_total', 
                  'cover_bottom_layer', 
                  'cover_standing_litter', 
                  'cover_rock',
                  'cover_bare_soil', 
                  'cover_short_vegetation', 
                  'count_plantago', 
                  'count_spinn' ,
                  'vegheight1', 
                  'vegheight2', 
                  'vegheight3', 
                  'vegheight4', 
                  'species', 
                  'species_cover', 
                  'count_floral_stems',
                  'year', 
                  'month', 
                  'day')

# We purposely do not do anything with treatment, as this will be joined from a seperate datafile. (the observations from S123 are not reliable)

# Function to select columns in multiple datasets
select_columns_multiple <- function(datasets, columns_to_select) {
  datasets <- lapply(datasets, function(df) {
    df %>% select(all_of(columns_to_select))
  })

# Assign the modified datasets back to their original names
list2env(setNames(datasets, names(datasets)), envir = .GlobalEnv)
}

# Put the datasets in a named list so they can be re-assigned correctly
datasets <- list(dat_2023 = dat_2023, dat_2024 = dat_2024)

# Apply the function and update the datasets in the global environment
select_columns_multiple(datasets, unlist(selection))

# Set column types correctly in 2023 data

dat_2023$cover_rock <- as.numeric(dat_2023$cover_rock)
dat_2023$cover_bare_soil <- as.numeric(dat_2023$cover_bare_soil)
dat_2023$count_floral_stems <- as.numeric(dat_2023$count_floral_stems)


# We need to match the column types
for (col_name in names(dat_2023)) {
  target_type <- class(dat_2023[[col_name]])
  dat_2024[[col_name]] <- switch(target_type,
                                  "numeric" = as.numeric(dat_2024[[col_name]]),
                                  "integer" = as.integer(dat_2024[[col_name]]),
                                  "character" = as.character(dat_2024[[col_name]]),
                                  "logical" = as.logical(dat_2024[[col_name]]),
                                  dat_2024[[col_name]] # Default: no conversion
  )
}



#### Merge the two datasets from 2023 and 2024                           

#Check if the dataframes have equal structure                  
all.equal(dat_2023, dat_2024) #Only lengths and string values are different

dat <- bind_rows(dat_2023, dat_2024)


#### Cleaning ------------------------------------------------------------------

#Clean up polygon IDs
dat <- dat %>% 
  mutate(polygon_id = fct_recode(polygon_id, "RU" = "1RU"))

#Clean up plot IDs
dat <- dat %>% 
  mutate(plot_id = fct_collapse(plot_id,
                           S1 = c("S1", "S01"), 
                           S2 = c("S2", "S02"), 
                           S3 = c("S3", "S03"), 
                           S4 = c("S4", "S04"),
                           S5 = c("S5", "S05"),
                           S6 = c("S6", "S06"),
                           S7 = c("S7", "S07"),
                           S8 = c("S8", "S08"),
                           S9 = c("S9", "S09")))

#Create unique plot ID
dat <- dat %>% 
  unite(plot_id2, c("polygon_id", "plot_id"), sep = "-", remove = FALSE)


#### Adding treatment data

dat <- dat %>% 
  left_join(dat_treatments, by = c("year", "plot_id2"))



#### Species names -------------------------------------------------------------

#Explore species names

unique_species <- dat %>% 
  distinct(species) %>%
  arrange(species)  

#Looks good

# A folder for exports will be created (if not already existing).

##  EXPORT FOR DATA ANALYSES ---------------------------------------------------                           

# Will export two datasets: one for analysing plot data and one for species
# Plot dataset will have coverage data and numbers (nr of species etc.)
# Species dataset will have species as columns and plot IDs as rows.

# Should only by TRUE when data is cleaned.
export_analyses <- TRUE



## ---------------------------------------------------------------------------##
##                             Export data                                 
## ---------------------------------------------------------------------------##

#Export xlsx file
write.xlsx(dat, "P:/154027_effektovervaking_av_trua_arter_og_naturtyper_2024/07 Prikkrutevinge/Effektovervaaking_prikkrutevinge/Data/Effekt_prikkrutevinge_2024_cleaned.xlsx")

