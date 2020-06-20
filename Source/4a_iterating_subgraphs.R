#=======================================================================================================
# PART 3: Main Program
#  actual program starts now --
#----------------------------------------------------------------------------------------------
library(tidyverse)
library(data.table)
library(foreign)
library(rgdal) 
library(sf)
library(Rcpp)

start_time <- Sys.time()

# USer can read directly if not in memory
if(!exists("sf_GeoMaster_CC")){
  sf_GeoMaster_CC <- st_read("Output/GeoMaster_Centroid_Connectors.shp")
}

# Combined master network with centroid connectors
DT <- setDT(sf_GeoMaster_CC)

# Change character fields to integer fields (for simple C++ code)
DT[, DIRECTION := 0 ]
DT[ DIR_TRAVEL != "B" | is.na(DIR_TRAVEL), DIRECTION := 1 ]
DT[ is.na(DIR_TRAVEL), DIR_TRAVEL := "B" ]
DT[ , DIR_TRAVEL_Num := 0]
DT[DIR_TRAVEL != "B", DIR_TRAVEL_Num := 1]

# Just Keep the fields of interest
fields <- c("A", "B", "LINK_ID", "F_ZLEV", "T_ZLEV", "FTEC", "ATEC", "LNEC", "SPEC", 
            "CAP_15", "COSITE", "Count_15", "DIRECTION", "rev_dir", 
            "DIR_TRAVEL_Num", "geometry")

compare_fields <- c("FTEC", "ATEC", "LNEC", "SPEC", "CAP_15", "DIRECTION")

DT <- DT[, ..fields]

# To overcome intersections on limited access facilities do:
# 1. Keep only limited access, toll roads and their ramps
# 2. Run the walk_the_graph program and consolidate links
# 3. Then replace those links in the shape actual file 
# 4. re0run walk_the_graph for rest of the links
# toll ramps = c(71, 72, 75, 76, 79) toll = c(91, 92), freeway = c(11, 12)

DT_exclude <- DT[! (FTEC %in% c(11, 12, 71, 72, 75, 76, 79,  91, 92)), ]

# Settings  
DT <- DT[FTEC %in% c(11, 12, 71, 72, 75, 76, 79,  91, 92), ]
out_Free_Toll_Shp <- "Output/SF_FL_Free_Toll_network.shp"
produce_node_file <- FALSE

source("4b_Walk_the_graph.R")


# Not quite intutive but the output from walking the network is now read back
if(!exists("sf_GeoMaster_CC")){
  sf_fl <- st_read(out_Free_Toll_Shp)
}

# Merge both consolidate limited access links with rest of the links
DT_free_toll    <- setDT(sf_fl)
original_fields <- colnames(DT_exclude)
DT_free_toll    <- DT_free_toll[ ,  original_fields]
DT              <- rbindlist(list(DT_free_toll, DT_exclude))

out_Free_Toll_Shp      <- "Output/SF_FL_walked_network_v2.shp"
out_Free_Toll_Node_Shp <- "Output/SF_FL_walked_network_nodes_v2.shp"
produce_node_file <- TRUE

source("4b_Walk_the_graph.R")


#--------------------------------------------------------------------------------------
# Runtime
runTime_Cpp_dataStructures
runTime_Cpp_Compiler
runTime_walkTheGraph
runTime_mergeLineSegments
runTime_writeShp




