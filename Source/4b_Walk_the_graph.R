
#-------------------------------------------------------------------------------------------------
# Part - 3
#-------------------------------------------------------------------------------------------------

# List of intersections & next_nodes by Anode
setDT(DT)[ , NumA := .N, by = "A"]
DT[ , bnodes := list(list(B)), by = "A"]

#----------------------------------------------------------------------------------------------
# Create Lookup Lists (data.table is faster than C++ here, since no passing)
# Create a A to NextNode lookup
dt_lookup <- copy(DT)
dim(dt_lookup)
dt_lookup <- dt_lookup[, c("A", "bnodes")]
dt_lookup <- unique(dt_lookup, by = "A")

# Lookup Anodes for B (merge nodes)
dt_merge <- copy(DT)
dt_merge[ , anodes := list(list(A)), by = "B"]
dim(dt_merge)
dt_merge <- dt_merge[, c("B", "anodes")]
dt_merge <- unique(dt_merge, by = "B")

# Create Row_id for quick lookup in C++
setorderv(DT, c("A","B"))
DT[ ,row_id := .I]

# List row_ids by A (use in C++)
DT[ , index_A := list(list(row_id)), by = "A"]
A_lookup <- copy(DT)
dim(A_lookup)
A_lookup <- A_lookup[, c("A", "index_A")]
A_lookup <- unique(A_lookup, by = "A")

# List row_ids by B (use in C++)
setorderv(DT, c("A","B"))
DT[ , index_B := list(list(row_id)), by = "B"]
B_lookup <- copy(DT)
dim(B_lookup)
B_lookup <- B_lookup[, c("B", "index_B")]
B_lookup <- unique(B_lookup, by = "B")
B_lookup[is.na(index_B), index_B := 0]

# CRITICAL Setting: make sure row_id is same as internal index 
# Makesure it is in the same order for C++ code
setorderv(DT, c("A","B"))

end_time <- Sys.time()
runTime_Cpp_dataStructures <- end_time - start_time

#==============================================================================================
# Compile C++ code
compile_start_time <- Sys.time()

sourceCpp("walk_the_graph_v3.cpp")

compile_end_time <- Sys.time()
runTime_Cpp_Compiler <- compile_end_time - compile_start_time


# Main program: walks the networks, identifies how to merge and sequence of merge
start_time <- Sys.time()

# isVisited <- graphWalk(DT, dt_lookup, A_lookup, B_lookup, compare_fields) # _v1, _v3
debug <- 0
if(debug == 1){
  sink("Output/graphWalk.log")
  isVisited <- graphWalk(DT, dt_lookup, dt_merge, A_lookup, B_lookup, compare_fields, debug)
  sink()
} else{
  isVisited <- graphWalk(DT, dt_lookup, dt_merge, A_lookup, B_lookup, compare_fields, debug)
}

end_time <- Sys.time()
runTime_walkTheGraph <- end_time - start_time
#==============================================================================================

merge_start_time <- Sys.time()
# Append columns
DT <- DT[, GeoMerge_ID := isVisited$ID1]
DT <- DT[, GeoMerge_Order := isVisited$ID2]
DT <- DT[, visited := isVisited$visited]

# Merge segements
DT2 <- copy(DT)

# Change order (note cannot run C++ code without putting back (sort by row_id or A, B))
setorderv(DT2, c("GeoMerge_ID", "GeoMerge_Order"))

# Function to merge all segments
mergeGeom <- function(geom_vec){
  x <-  st_sfc(st_multilinestring(list(do.call(rbind, lapply(geom_vec, function(x){x[[1]]})))))
  return(x)
}


setorderv(DT2, c("GeoMerge_ID", "GeoMerge_Order"))

merged_geometry <- DT2[ ,lapply(.SD, mergeGeom), by=GeoMerge_ID, .SDcols=c("geometry")]

merge_end_time <- Sys.time()
runTime_mergeLineSegments <-merge_end_time - merge_start_time

#-------------------------------------------------------------------------------------------
  
# Get first and last A, B and attributes
DT2 <- DT2[, last := .N, by = GeoMerge_ID]
first <- DT2[GeoMerge_Order == 0, ]
first <- first[ , c("B", "geometry") := NULL]
last  <- DT2[GeoMerge_Order == (last - 1), c("B", "GeoMerge_ID")]

# Merge firt Anode, last Bnode and geometry
first_last <- merge(first,last, by.x = "GeoMerge_ID", by.y = "GeoMerge_ID")
first_last_geom <-  merge(first_last, merged_geometry, by.x = "GeoMerge_ID", by.y = "GeoMerge_ID")

# Convert to SF
sf_fl <- st_as_sf(first_last_geom)

merge_end_time <- Sys.time()
runTime_mergeLineSegments <-merge_end_time - merge_start_time

#==============================================================================================

write_start_time <- Sys.time()

# Set projection
st_crs(sf_fl) = 26917
st_write(sf_fl, out_Free_Toll_Shp, append = FALSE)

# Produce this only for the last step
if(produce_node_file){
  
  # export corresponding nodes for the shape file
  dt <- as.data.table(sf_fl)
  sf_fl_Anodes <- unique(dt$A)
  sf_fl_Bnodes <- unique(dt$B)
  sf_fl_nodes <- unique(sf_fl_Anodes, sf_fl_Bnodes)
  
  # read all nodes
  sf_allNodes <- st_read("Output/node_ids.shp")
  
  sf_fl_Nodes <- sf_allNodes %>% 
    filter(Hwy_NodeId %in% sf_fl_nodes) %>% 
    select(-elevation) %>%
    rename(N = Hwy_NodeId) 
  
  fl_xy_coords <- st_coordinates(sf_fl_Nodes)
  sf_fl_Nodes <- cbind(sf_fl_Nodes, fl_xy_coords)
  
  st_crs(sf_fl_Nodes) = 26917
  st_write(sf_fl_Nodes, out_Free_Toll_Node_Shp, append = FALSE)
}


write_end_time <- Sys.time()
runTime_writeShp <- write_end_time - write_start_time

