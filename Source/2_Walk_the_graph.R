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

# Debug:: walk the graph for a selected A-B link and get next_Bnode (B -> next_Bnode)
debug <- FALSE
if(debug) {
  
  lst_Bto   <- createList(dt_lookup, "A" , "bnodes");
  lst_Bfrom <- createList(dt_merge, "B" , "anodes");
  index_A   <- createList(A_lookup, "A" , "index_A");
  index_B   <- createList(B_lookup, "B" , "index_B");
  Atz       <- createList(DT, "row_id", "T_ZLEV");  
  Bfz       <- createList(DT, "row_id", "F_ZLEV");
  uni_bi    <- createList(DT, "row_id", "DIR_TRAVEL_Num");
 
  # Case 1: No intersection, consolidate links
  start_seg_Anode <- 66778   # 66778 -> 66831 -> 207601 -> 207667 -> 207701 -> 66975
  current_Anode   <- 66831
  current_Bnode   <- 207601
  # 
  # # Case 2: Met intersection
  # start_seg_Anode <- 66778   
  # current_Anode   <- 207701 # 207701 -> 66975 -> 66981 (but another link exists 66976 -> 66975)
  # current_Bnode   <- 66975    
  
  # # Case 3: wrongly coded links A->B<-C
  # start_seg_Anode <- 74523
  # current_Anode   <- 74523   # 74523 -> 222819 <- 74733
  # current_Bnode   <- 222819  

  # # Case 4: Merge Node
  # start_seg_Anode <- 222819
  # current_Anode   <- 74733   
  # current_Bnode   <- 74768
  # 
  # # # Case 4: Merge Node
  # start_seg_Anode <- 74733
  # current_Anode   <- 74733   
  # current_Bnode   <- 74768   # 74834
  
  # # Case 4: Merge Node
  start_seg_Anode <- 222252 # 74283
  current_Anode   <- 222252
  current_Bnode   <- 74262   # 74834
  
  # # # Case 5: Overpass
  # start_seg_Anode <- 74258 # Start 74186
  # current_Anode   <- 74258   
  # current_Bnode   <- 74274   # 74834
  
  # # Case 5: wrongly coded links A->B <-C with wrong Z-level info
  # start_seg_Anode <- 50594
  # current_Anode   <- 50594   # 50594
  # current_Bnode   <- 114231    # 114231
  
  # Gets the next A-B
  debug <- 1
  Get_next_Bnode(lst_Bfrom, lst_Bto, 
                  start_seg_Anode, current_Anode, current_Bnode,
                  Atz, Bfz, index_A,  index_B, uni_bi, debug)

  
  # Other functions (find A-B index, subset, nextBnode)
  curr_link_index <- find_AB_Index2(index_A, index_B, 222252, 74262)
    # Atz[curr_link_index]
  # next_link_index <- find_AB_Index2(index_A, index_B, 74274, 74216)
    # Bfz[next_link_index]
}
# Steps To debug
# 1. Select a link, get its row_id
# 2. C++, update debug_row = row_id (#1)
# 3. run and check the outputs (ID1, ID2) of sub-sequent links (next successive Bnodes)
# Ex: see xy

# isVisited <- graphWalk(DT, dt_lookup, dt_merge, A_lookup, B_lookup, compare_fields)
# Calling C++ Functions
# cpp_lookup <- createList(dt_lookup)
# xy2 <- DT[1:20001, ]
# x <- createList(dt_lookup, "A", "bnodes")
# x1 <- createList(A_lookup, "A", "index_A")
# x2 <- createList(B_lookup, "B", "index_B")
# #
# find_AB_Index(DT$A, DT$B, 37152 , 37142)
# find_AB_Index2( x1, x2, 124459, 124460)

# r = 141016 - 1
# nextAB_index = 141692 - 1
# sourceCpp("Compare_Attributes.cpp")
# Compare_Attributes(DT, r, nextAB_index, compare_fields)

# Append columns
DT <- DT[, GeoMerge_ID := isVisited$ID1]
DT <- DT[, GeoMerge_Order := isVisited$ID2]
DT <- DT[, visited := isVisited$visited]

# Merge segements
DT2 <- copy(DT)

# Change order (note cannot run C++ code without putting back (sort by row_id or A, B))
setorderv(DT2, c("GeoMerge_ID", "GeoMerge_Order"))

# end_time <- Sys.time()
# runTime_walkTheGraph <- end_time - start_time


#--------------------------------------------------------------------------------------
# For Demo PPT 
debug <- FALSE
if(debug) {
    # For debugging
    n1 <- DT2 %>% filter(A == 1244 & B == 66778) %>% select(fields, "row_id", "geometry")
    n2 <- DT2 %>% filter(A == 66778 & B == 66831) %>% select(fields, "row_id", "geometry")
    n3 <- DT2 %>% filter(A == 66831 & B == 207601) %>% select(fields,"row_id", "geometry")
    n4 <- DT2 %>% filter(A == 207601 ) %>% select(fields,"row_id", "geometry")
    n5 <- DT2 %>% filter(A == 207667 ) %>% select(fields, "row_id", "geometry")
    n6 <- DT2 %>% filter(A == 207701 ) %>% select(fields, "row_id", "geometry")
    n7 <- DT2 %>% filter(A == 66975 ) %>% select(fields, "row_id", "geometry")
    n8 <- DT2 %>% filter(A == 66981 & B == 208103) %>% select(fields, "row_id", "geometry")
    
    # select all ids and aggregate with st_union
    
    xy <- DT2 [row_id %in% c(n1$row_id, n2$row_id, n3$row_id,
                            n4$row_id, n5$row_id, n6$row_id,
                            n7$row_id), ]
    
    setorderv(xy, c("GeoMerge_ID", "GeoMerge_Order"))
    
    sf_xy <- st_as_sf(xy)
    st_write(sf_xy, "Output/demo_example.shp", append = FALSE)
    
    # Check 
    t1 <- DT[GeoMerge_ID == 66161, ]
    setorder(t1, GeoMerge_Order)
    
    # Overpass check
    t2 <- DT[GeoMerge_ID == 123864, ]
    setorder(t2, GeoMerge_Order)
    
    # Elevated ramps
    t3 <- DT[GeoMerge_ID == 74073, ]
    setorder(t3, GeoMerge_Order)
    
    t3 <- DT[GeoMerge_ID == 121192, ]
    setorder(t3, GeoMerge_Order) 
    
    opn_shp <- st_union(st_as_sf(t3))
    st_crs(opn_shp) = 26917
    st_write(opn_shp, "Output/overpass_network.shp", append = FALSE)
}

#--------------------------------------------------------------------------------------
# Function to merge all segments
mergeGeom <- function(geom_vec){
  x <-  st_sfc(st_multilinestring(list(do.call(rbind, lapply(geom_vec, function(x){x[[1]]})))))
  return(x)
}


# # Function to merge all segments
# mergeGeom_purrr <- function(df){
#   
#   df2 <- df %>% arrange(GeoMerge_Order)
#   x <-  st_sfc(st_multilinestring(list(do.call(rbind, lapply(df2$geometry, function(x){x[[1]]})))))
#   
#   # these are specified outside
#   cnt <<- cnt + 1
#   if(cnt %% 10000 == 0){
#     print(paste("Processing row number", cnt,  "of", max_rows)) 
#   }
#   
#   return(x)
# }


#-------------------------------------------------------------------------------------------------
merge_start_time <- Sys.time()

setorderv(DT2, c("GeoMerge_ID", "GeoMerge_Order"))

# Apply function to merge
# DT2 <- DT2[order(GeoMerge_Order),.SD[1:24], by = GeoMerge_ID]

merged_geometry <- DT2[ ,lapply(.SD, mergeGeom), by=GeoMerge_ID, .SDcols=c("geometry")]


merge_end_time <- Sys.time()
runTime_mergeLineSegments <-merge_end_time - merge_start_time


#-------------------------------------------------------------------------------------------------
# merge_start_time <- Sys.time()
# 
# # Purrr method
# DT2[, N_segments := .N, by = "GeoMerge_ID"]
# DT3 <- DT2[N_segments > 1, ]
# cnt <- 0
# max_rows <- nrow(DT3)
# 
# merged_geometry_purrr <- DT3 %>% 
#   setDF() %>% 
#   group_by(GeoMerge_ID) %>% 
#   nest() %>% 
#   mutate(geo2 = map(data, mergeGeom_purrr)) %>% 
#   unnest()
#   
# merge_end_time <- Sys.time()
# runTime_mergeLineSegments <-merge_end_time - merge_start_time  
# runTime_mergeLineSegments
#-------------------------------------------------------------------------------------------------

# Get first and last A, B and attributes
DT2 <- DT2[, last := .N, by = GeoMerge_ID]
first <- DT2[GeoMerge_Order == 0, ]
first <- first[ , c("B", "T_ZLEV", "geometry") := NULL]
last  <- DT2[GeoMerge_Order == (last - 1), c("B", "T_ZLEV", "GeoMerge_ID")]

# Merge firt Anode, last Bnode and geometry
first_last <- merge(first,last, by.x = "GeoMerge_ID", by.y = "GeoMerge_ID")
first_last_geom <-  merge(first_last, merged_geometry, by.x = "GeoMerge_ID", by.y = "GeoMerge_ID")

# Convert to SF
sf_fl <- st_as_sf(first_last_geom)

merge_end_time <- Sys.time()
runTime_mergeLineSegments <-merge_end_time - merge_start_time

# # Check demo example
# first_last[GeoMerge_ID == 108731, ]

#--------------------------------------------------------------------------------------
write_start_time <- Sys.time()

# Set projection
st_crs(sf_fl) = 26917
st_write(sf_fl, "Output/SF_FL_walked_network.shp", append = FALSE)


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
st_write(sf_fl_Nodes, "Output/SF_FL_walked_network_nodes.shp", append = FALSE)

write_end_time <- Sys.time()
runTime_writeShp <- write_end_time - write_start_time

#--------------------------------------------------------------------------------------
# Runtime
runTime_read_shapeFiles
runTime_prepareInputs
runTime_updateXY
runTime_append_user_NodeIds
runTime_reverse

runTime_Cpp_dataStructures
runTime_Cpp_Compiler
runTime_walkTheGraph
runTime_mergeLineSegments
runTime_writeShp


#--------------------------------------------------------------------------------------
# C++ geometry merg function
#--------------------------------------------------------------------------------------
# xy2 <- DT2[GeoMerge_ID == 41636, ]
# xy3 <- DT2[GeoMerge_ID %in% c(41636, 120115) ]
# 
# # sf_xy <- st_as_sf(xy2)
# # st_write(sf_xy, "Output/demo_example_41636.shp", append = FALSE)
# 
# sourceCpp("merge_Geom.cpp")
# 
# a1 <- MergeGeometry(xy3,  "GeoMerge_ID",  "GeoMerge_Order", unique(xy3$GeoMerge_ID))
# 
# # a2 <- MergeGeometry2(xy2,  "GeoMerge_ID",  "GeoMerge_Order", unique(xy2$GeoMerge_ID))
# 
# header <- c('"wkt_geom";"GeoMerge_ID";"A";"B"')
# 
# write.table(header, "Output/GeoMerge_ID_41636_120115.csv", row.names = FALSE, quote = FALSE, append = FALSE, col.names = FALSE)
# write.table(a1, "Output/GeoMerge_ID_41636_120115.csv", row.names = FALSE, quote = FALSE, append = TRUE, col.names = FALSE)




