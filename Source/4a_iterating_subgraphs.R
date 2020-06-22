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
  sf_GeoMaster_CC <- st_read(sf_GeoMaster_CC_ShpFile)
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

# Remove limited, toll and thier ramp links from graph
free_toll_subgraph <- c(11, 12, 16, 71, 72, 75, 76, 79,  91, 92, 97, 98, 99)
DT_exclude <- DT[! (FTEC %in% free_toll_subgraph), ]

# To overcome intersections on limited access facilities do:
# 1. Keep only limited access, toll roads and their ramps
# 2. Run the walk_the_graph program and consolidate links
# 3. Then replace those links in the shape actual file 
# 4. re0run walk_the_graph for rest of the links
# toll ramps = c(71, 72, 75, 76, 79) toll = c(91, 92), freeway = c(11, 12)


# Extract toll, limited access and ramps  
DT <- DT[FTEC %in% free_toll_subgraph, ]
out_Free_Toll_Shp <- Free_Toll_subgrap_ShpFile
produce_node_file <- FALSE

# Run network consolidation 
source("4b_Walk_the_graph.R")

# Not quite intutive but the output from walking the network is now read back
if(!exists("sf_fl")){
  sf_fl <- st_read(out_Free_Toll_Shp)
}

# Merge both consolidate limited access links with rest of the links
DT_free_toll    <- setDT(sf_fl)
original_fields <- colnames(DT_exclude)
DT_free_toll    <- DT_free_toll[ ,..original_fields]
DT              <- rbindlist(list(DT_free_toll, DT_exclude))

out_Free_Toll_Shp      <- consoildate_links_iter_ShpFile
out_Free_Toll_Node_Shp <- consoildate_links_iter_Node_ShpFile
produce_node_file <- TRUE

source("4b_Walk_the_graph.R")


#--------------------------------------------------------------------------------------
# Runtime
# runTime_Cpp_dataStructures
# runTime_Cpp_Compiler
# runTime_walkTheGraph
# runTime_mergeLineSegments
# runTime_writeShp

#--------------------------------------------------------------------------------------
# # Investigate the over pass issue
# do_compare_iter_regular <- TRUE
# 
# if(do_compare_iter_regular) {
# 
#   version_v1 <- "Output/SF_FL_walked_network.shp"
#   version_v2 <- "Output/SF_FL_walked_network_v2.shp"
#   
#   sf_v1 <- st_read(version_v1)
#   DT_v1 <- setDT(sf_v1)
#   DT_v1 <- DT_v1[FTEC %in% c(11, 12, 91, 92), ]
#   
#   sf_v2 <- st_read(version_v2)
#   DT_v2 <- setDT(sf_v2)
#   DT_v2 <- DT_v2[FTEC %in% c(11, 12, 91, 92), c("A", "B")]
#   DT_v2 <- DT_v2[ ,same_as_V1 := 1]
#   
#   DT_compare <- merge(DT_v1, DT_v2, 
#                       by.x = c("A", "B"), 
#                       by.y = c("A", "B"), 
#                       all.x = TRUE)
#   
#   overpass_issue <- DT_compare[is.na(same_as_V1), ]
#   st_write(st_as_sf(overpass_issue), "Output/overpass_issue_links.shp", append = FALSE)
# }

