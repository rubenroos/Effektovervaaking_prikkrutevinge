
## Survey123 registrations to readable table

# Written by Ida M. Mienna
# Date written: October 2024

## File path
# File can be a file geodatabase (FGDB), geodatabase (GBD) or Excel
# If downloaded as a FGDB or GBD, the file can also be zipped
# The path MUST have forward slash and NOT backslash
# Substitute æ,ø,å with other letters before importing
# Examples beneath

filepath <- "P:/154027_effektovervaking_av_trua_arter_og_naturtyper_2024/07 Prikkrutevinge/Effektovervaaking_prikkrutevinge/Data/2024_S123_prikkrutevinge.xlsx"

## Path to folder where the processed directories and files should be exported
outputpath <- "P:/154027_effektovervaking_av_trua_arter_og_naturtyper_2024/07 Prikkrutevinge/Effektovervaaking_prikkrutevinge/Data"

## What should the exported files be marked as?
project <- "Effekt_prikkrutevinge_2024"

## Export dataset before cleaning? (Yes=TRUE, No=FALSE)
export_dirty <- TRUE

# When you have edited all the points above to your liking, click "Source" 
# or Ctrl+Shift+Enter.


####------------------------------------------------------------------------####
####                       DO NOT CHANGE BELOW
####------------------------------------------------------------------------####

Sys.setlocale("LC_CTYPE", "nb_NO.UTF-8")

## Packages
packages <- c("dplyr", "readxl", "sf", "tidyr", "openxlsx", "stringr",
              "httr", "jsonlite", "purrr", "data.table")


# Require or install packages function
ipak <- function(pkg){
  new.pkg <- pkg[!(pkg %in% installed.packages()[, "Package"])]
  if (length(new.pkg)) 
    install.packages(new.pkg, dependencies = TRUE)
  sapply(pkg, require, character.only = TRUE)
}

ipak(packages)

## Import files
openfiles <- function(filepath){
  
  filetype <- sub(".*\\.", "", filepath)
  
  if(filetype == "zip"){
    filepathfolder <- sub("/[^/]*$", "", filepath)

    unzip(filepath,exdir = filepathfolder)
    
    # List all folders in filepath
    folders <- list.dirs(filepathfolder, full.names = TRUE, recursive = FALSE)
    
    # Get the most recent folder by checking modification time
    gdb_folder <- folders[which.max(file.info(folders)$mtime)]
    
    data_survey <- st_read(gdb_folder, layer = "surveyPoint")
    data_art <- st_read(gdb_folder, layer = "art")
      
  }
  
  if(filetype == "gdb"){
    
    data_survey <- st_read(filepath, layer = "surveyPoint")
    data_art <- st_read(filepath, layer = "art")
    
  }
  
  if(filetype == "xlsx"){
    
    data_survey <- read_excel(filepath, sheet="surveyPoint_0")
    data_art <- read_excel(filepath, sheet="art_1")
    
  }
  
  return(list(survey = data_survey, art = data_art))
  
}

data <- openfiles(filepath)
env <- data$survey
species <- data$art

# Add coordinates as separate columns if object is a sf object (shapefile)
if(class(env)[1] == "sf"){
  coordinates <- st_coordinates(env)
  env$longitude <- coordinates[, 1]
  env$latitude <- coordinates[, 2]
  # Drop geometry
  env <- env %>% st_drop_geometry()
} else {
  # If imported from Excel
  env <- env %>%
    rename("longitude" = x,
           "latitude" = y)
}

## ---------------------------------------------------------------------------##
##                            DATA STRUCTURING                                ##
## ---------------------------------------------------------------------------##


#What we basically want to do is join the species df to the env file, joining them by "ParentGlobalID", we then want to clean this datafile so that it can be used for analyses
# Column headers will change in how they are capitalized or not depending on
# file type. Have headers in lowercase
names(env) <- tolower(names(env))
names(species) <- tolower(names(species))

env <- env %>% 
  rename(parentglobalid = globalid)

dat <- env %>% left_join(., species, by = "parentglobalid", keep = FALSE)
#head(dat)

dat <- dat %>% 
  #filter out some of the data we do not need
  select(-any_of(c('veg_html_rows',
                   'objectid.x',
                    'display_tot',
                    'creationdate.x',
                    'creator.x',
                    'editdate.x',
                    'editor.x',
                    #'hovedtype_1m2',
                    #'ke_beskrivelse_1m2',
                    #'sp_dekning',
                    #'sp_fertil',
                    'veg_html_row',
                    'creationdate.y',
                    'creator.y',
                    'editdate.y',
                    'editor.y',
                   'objectid.y')),
                    -starts_with("ruternr"))

#str(dat) #check

# Rename columns so they make sense, remove spaces, etc.
# Rename columns so they make sense, remove spaces, etc.
renames <- list(
  eventTime = c('registreringsdato', 'registreringsdato:', 'dato'),
  locality = "lokalitet",
  polygon_id = c('polygon_id', 'polygon id'), 
  plot_id = c('rute_id', 'rute-id'),
  registrator = c('bruker_navn', 'observatør'),
  
  weather = c('vaer','værforhold'),
  
  gps_accuracy = 'noeyaktighet',
  
  # Plant cover
  cover_field_layer = c('dekning % av karplanter i feltsjikt'),
  cover_vegetation_total = c('tot_dekning', 'total dekning % av arter registrert'),
  cover_bottom_layer = c('bunnsjikt_dekning','dekning % av bunnsjikt'),
  cover_bryophytes = c('dekning_moser','moser_dekning'),
  cover_lichens = c('dekning_lav', 'lav_dekning'),
  cover_litter = c('stroe_dekning', 'strø_dekning', 'dekning_strø', 'dekning % av strø'),
  cover_rock = c('grus_stein_berg_fjell_dekning', 'dekning % av grus/stein/berg/fjell'),
  cover_crust = 'crust_dekning',
  cover_bare_soil = c('jord_dekning', 'dekning % av bar jord'),
  cover_woody_plants_field_layer = c('dekning % av vedplanter i feltsjikt'), 
  cover_shrub_layer = 'dekning % av vedplanter i busksjikt', 
  cover_tree_layer = 'dekning % tresjikt',
  cover_standing_litter = 'dekning % av stående død biomasse',
  cover_short_vegetation = 'dekning % av kort vegetasjon < 5 cm', 
  
  
  # Vegetation heights
  vegheight1 = c('vegetasjonshøyde måling 1','veg_hoyde1'),
  vegheight2 = c('vegetasjonshøyde måling 2', 'veg_hoyde2'),
  vegheight3 = c('vegetasjonshøyde måling 3', 'veg_hoyde3'),
  vegheight4 = c('vegetasjonshøyde måling 4', 'veg_hoyde4'),
  
  # Fastmerker
  benchmarked = c('fastmerker','er det satt ned fastmerker?'),
  
  # Skjøtsel og behandlinger
  treatment_2024 = c('skjøtsel - rute', 'skjøtsel'),
  count_plantago = 'antall smalkjemperosetter', 
  count_spinn = 'antall larvespinn', 
  count_floral_stems = 'sp_blomterskudd',
  
  # Sub-plots
  species = c('navn', 'species_name'),
  preferred_popularname = "sp_species",
  fertile = 'fertile skudd',
  sub_plots = c('smårutene nr.', "ruter"),
  species_cover = c('sp_dekning'),
  
  # globalid
  parenteventid = 'parentglobalid',
  eventid = 'globalid'
  
)

# Function to rename columns based on their existence
rename_if_exists <- function(df, renames) {
  for (new_name in names(renames)) {
    # Find the first old column name that exists in the dataframe
    old_name <- renames[[new_name]][renames[[new_name]] %in% names(df)]
    
    # If such a column exists, rename it to the new name
    if (length(old_name) > 0) {
      df <- df %>% rename(!!new_name := !!sym(old_name[1]))
    }
  }
  return(df)
}

# Renaming only existing columns
dat <- rename_if_exists(dat, renames)

# Function to reorder numbers within each string
reorder_numbers <- function(x) {
  sapply(strsplit(x, ","), function(y) paste(sort(as.numeric(y)), collapse = ","))
}

dat <- dat %>%
  mutate(
    # Convert to Date and keep only the date part
    eventTime = as.Date(eventTime, format = "%Y-%m-%d %H:%M:%S"),
    
    # Extract year, month and day
    year = format(as.Date(eventTime), "%Y"),
    month = format(as.Date(eventTime), "%m"),
    day = format(as.Date(eventTime), "%d"),
    
    # Remove "-" in eventTime
    eventTime = gsub("-", "", format(eventTime, "%Y-%m-%d")),
    
    # Reorder the sub-plot numbers chronologically (if exists)
    sub_plots=if("sub_plots" %in% colnames(df)) {reorder_numbers(sub_plots)},
    
    # Make mean vegetation height column (if exists)
    mean_vegheight = rowMeans(select(., any_of(c('vegheight1','vegheight2','vegheight3','vegheight4'))), na.rm = TRUE),
    
    # Only have preferred_popularname name in the preferred_popularname column
    preferred_popularname = str_extract(preferred_popularname, "(?<=\\().+?(?=\\))")
    
    ) %>%
  select(
    # Remove columns if only containing NAs
    where(~ !all(is.na(.)))#,
    #Reorder known columns. Unknown columns will end up in the back
    #any_of(c("plot_nr")), # CHANGE LATER FOR REORDERING
    #everything()
    )


# Create a folder for processed data (if it does not exist)
processed_folder <- paste0(outputpath, project,"_processed/")
if (!dir.exists(processed_folder)) {
  dir.create(processed_folder)
  cat(paste0("Directory created for processed data: ", processed_folder))
}

#Export xlsx file
if(export_dirty) {
  dat %>% write.xlsx(file = paste0(processed_folder, project,"_export_dirty.xlsx"), colNames = TRUE)
}

