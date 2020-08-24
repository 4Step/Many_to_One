# User Interface for Walk_the_Graph


#---------------------------------------------------------------------------------------------------------------
#User Settings
#---------------------------------------------------------------------------------------------------------------
# This is the User Interface for the "walk_the_graph" model
unzip               <- FALSE
write_Interim       <- TRUE
run_prepSteps       <- FALSE
update_GeoMaster_XY <- TRUE
update_CenCon_XY    <- FALSE
do_reverse          <- TRUE

debug               <- 0          # debug = 1, write debug output

do_iterative_run    <- FALSE      # Iterative run will first consolidate limited access facilities (subgraph) then runs rest of the network
do_compare_iter_regular <- FALSE  # Works only when do_iterative_run = TRUE, also expects a regular run output exists, which is run from "do_iterative_run == FALSE"

#---------------------------------------------------------------------------------------------------------------
# List of files
#---------------------------------------------------------------------------------------------------------------
# List of Input Files
geoMaster_zipFile          <- "Input/GeoMaster.zip"
zone_centroids_zipFile     <- "Input/Zone_Centroids.zip"
zone_cC_zipFile            <- "Input/Centroid_Connectors.zip"
User_NodeIDs_zipFile       <- "Input/Hwy_NodeIds.zip" 

# List of Input Files (or provide shapefiles)
geoMaster_shpFile          <- "Input/temp/GeoMaster.shp"
zone_centroids_ShpFile     <- "Input/temp/Zone_Centroids.shp"
zone_cC_ShpFile            <- "Input/temp/Centroid_Connectors.shp"
User_NodeIDs_shpFile       <- "Input/temp/Hwy_NodeIds.shp"

# Interim file
GeoMaster_node_shpFile     <- "Output/GeoMaster_Nodes.shp"
review_centroid_xy_ShpFile <- "Output/sf_node_unmatch.shp"
final_nodeIDs_ShpFile      <- "Output/node_ids.shp"
sf_CC_rev_shpFile          <- "Output/Centroid_Connectors_reverse.shp"
sf_cc_both_ShpFile         <- "Output/Centroid_Connectors_both.shp"
sf_GeoMaster_CC_ShpFile    <- "Output/GeoMaster_Centroid_Connectors.shp"
Free_Toll_subgrap_ShpFile  <- "Output/SF_FL_Free_Toll_network.shp"
overpass_issue_shpFile     <- "Output/overpass_issue_links.shp"
debug_outFile              <- "Output/graphWalk.log"

# Ouput
consoildate_links_ShpFile           <- "Output/SF_FL_walked_network.shp"
consoildate_links_Node_ShpFile      <- "Output/SF_FL_walked_network_nodes.shp"

consoildate_links_iter_ShpFile      <- "Output/SF_FL_walked_network_v2.shp"
consoildate_links_iter_Node_ShpFile <- "Output/SF_FL_walked_network_nodes_v2.shp"

#---------------------------------------------------------------------------------------------------------------
# Call program
#---------------------------------------------------------------------------------------------------------------
start_all_time <- Sys.time()

# unzip shape files to Output/temp
if(unzip){
  source("Source/0_unzipFiles.R")
  # wait for unzip to finish writing
  # Sys.sleep(1000)
}

# Prepare ONE network file "GeoMaster_Centroid_Connectors.shp" with:
#   Hwy Links + reverse direction for bi-directional links, 
#   Centroid connectors Links + reverse direction
#   Centroid Nodes + User Specified Nodes + All other remaining Highway Nodes

if(run_prepSteps){
  source("Source/1_compute_XY.R")
}

# If all the input is correct, 
#   - Z-levels for all overpass / underpass links are error free
#   - Correct uni-directional links between the segments, 
#     ex: no A->a1->a2<-a3->B, where A, B are userdefined links and all attributes are same for all segments
#         issues is with link a2<-a3, which is coded in reverse direction. 

# Run program (assumes at least overpass are coded correctly)
if(!do_iterative_run){
  source("Source/2_Walk_the_graph.R")
} else{
  source("Source/4a_iterating_subgraphs.R")
}


# To find out if there is an overpass issue, 
# the analyst could run both ways and compare results, requires to
#  - first run the model with do_iterative_run   <- FALSE 
#  - second run the model with do_iterative_run   <- TRUE  & do_compare_iter_regular <- TRUE
if(do_compare_iter_regular){
    source("Source/4c_check_for_overpass_issue.R")
}

end_all_time <- Sys.time()
runTime_total <- end_all_time - start_all_time


# Delete unzipped files
if(unzip){
  unlink("Input/temp", recursive=TRUE)
}

#---------------------------------------------------------------------------------------------------------------
# Print Runtime
#---------------------------------------------------------------------------------------------------------------
if(run_prepSteps){
  print(paste("read_shapeFiles", round(runTime_read_shapeFiles, 2), "Seconds"))
  print(paste("prepare_Inputs", round(runTime_prepareInputs, 2), "Seconds"))
  print(paste("update_XY", round(runTime_updateXY, 2), "Seconds"))
  print(paste("append_user_NodeIds", round(runTime_append_user_NodeIds, 2), "Seconds"))
  print(paste("get_reverse_links", round(runTime_reverse, 2), "Seconds"))
}

runTime_Cpp_dataStructures
runTime_Cpp_Compiler
runTime_walkTheGraph
runTime_mergeLineSegments
runTime_writeShp

runTime_total


