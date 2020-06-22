library(tidyverse)
library(data.table)
library(foreign)
library(rgdal) 
library(sf)

#-------------------------------------------------------------------------------------------------------
# To DO this goes into GUI file
# User Settings
write_Interim       <- FALSE
update_GeoMaster_XY <- TRUE
update_CenCon_XY    <- FALSE
do_reverse          <- TRUE

# Read shape files
readshp_start_time <- Sys.time()

sf_GM          <- st_read(geoMaster_shpFile) 
sf_centroids   <- st_read(zone_centroids_ShpFile)
sf_CC          <- st_read(zone_cC_ShpFile)

# Read User Specified Hwy Node ids
sf_nodeIds       <- st_read(User_NodeIDs_shpFile) 
st_crs(sf_nodeIds) = 26917

readshp_end_time <- Sys.time()
runTime_read_shapeFiles <- readshp_end_time - readshp_start_time
  
#=======================================================================================================
# PART 1: Function to Update Link X, Y 
#=======================================================================================================
# Function #1: Update Link X, Y 

 update_XY <- function(sf, type){  
  
  # Get coordinates (x,Y) for every line-segment
  xy  <- st_coordinates(sf)
  
  # check if it is string or multistring (use the last column)
  names <- colnames(xy)
  
  if(type == "line") {
    xy_col_n <- names[ncol(xy)]
    
    # New field names (use same order of columns)
    xy_names <- c("XFROM", "YFROM", "XTO", "YTO") 
    
    # Get First and Last coordinates
    dt_XY <- data.table(xy)
    setnames(dt_XY, xy_col_n, "id")
    dt_XY[, seq := seq(.N), by = "id"]
    dt_XY[, last := 0]
    dt_XY[ , last := max(seq), by = "id"]
    dt_XY[last == seq, first_last := "to"]
    dt_XY[seq == 1, first_last := "from"]
    
    dt_XY <- dt_XY[!is.na(first_last), c("X", "Y", "id", "first_last")]
    
    # Trasnsform as TO, FROM
    dt_XY2 <- dcast(dt_XY, id ~ first_last, value.var = c("X", "Y"))
    setnames(dt_XY2, 
             c("X_from", "Y_from", "X_to", "Y_to"),
             xy_names)
  
  }
  
  if(type == "point"){
    xy_names <- c("X", "Y") 
    dt_XY <- data.table(xy)
    dt_XY2 <- dt_XY[, id := .I]
  }
  
  # check and delete old X,Y fields
  GM.no_sf <- as.data.frame(sf)
  names <- colnames(GM.no_sf)
  names <- names[!(names %in% xy_names)]
  GM.no_sf <- GM.no_sf %>% 
    select(names) %>% 
    setDT()
  
  GM.no_sf <- GM.no_sf[, row_id := .I]
  
  # Append Updated FROM, TO or X,Y
  GM.no_sf2 <- merge(GM.no_sf, dt_XY2, by.x = "row_id", by.y = "id")

  sf_GM2 <- st_as_sf(GM.no_sf2)
  
  return(sf_GM2)
 }
 
 #=======================================================================================================
 # Function to add A,B Nodes based on lookup
 #=======================================================================================================
  append_AB <- function(sf, df_allNodeIds) { #}, df_centroids){
   
   # Add Intergerized X, Y
   df_allNodeIds  <- df_allNodeIds[, c("Xint", "Yint") := list(as.integer(X), as.integer(Y))]
   
   # Data frame
   df <- as.data.frame(sf) 
   
   # check and delete A, B fields if exist
   check_names  <- colnames(df)
   check_names  <- check_names[!(check_names %in% c("A", "B"))]
   df <- df %>% select(check_names) %>% setDT()
   
   # Intergerize X, Y (FROM / TO)
   df <- df[, c("XFint", "YFint", "XTint", "YTint") := list(as.integer(XFROM), 
                                                            as.integer(YFROM),
                                                            as.integer(XTO), 
                                                            as.integer(YTO))]
   
   # Add A Node based on FROM (X, Y)
   df2 <- merge(df, df_allNodeIds, 
                by.x = c("XFint", "YFint"),
                by.y = c("Xint", "Yint"),
                all.x = TRUE)
   
   df2 <- df2[, c("X", "Y") := NULL]
   setnames(df2, "Hwy_NodeId", "A")
   
   # Add B Node based on TO (X, Y)
   df3 <- merge(df2, df_allNodeIds, 
                by.x = c("XTint", "YTint"),
                by.y = c("Xint", "Yint"),
                all.x = TRUE)
   
   df3 <- df3[, c("X", "Y") := NULL]
   setnames(df3, "Hwy_NodeId", "B")
   
   
   # Check if there are any unmapped A,B
   check_AB <- df3[is.na(A) | is.na(B), ]
   if(nrow(check_AB) > 0){
     print(paste0("There are ", nrow(check_AB) , " links not tagged with either A or B"))
   } else{
     print(paste0("All ", nrow(df3) , " links are tagged with A and B nodes"))
   }
   
   df3 <- df3[, c("XFint", "YFint", "XTint", "YTint") := NULL]
              
   # Write out interim file
   sf2 <- st_as_sf(df3)
   
   return(sf2)
 }
 
#=======================================================================================================
# PART 2: Prepare Input Network
#=======================================================================================================
prep_start_time <- Sys.time()

# STEP 1: Extract GeoMaster Endpoints
# Read GeoMaster links

sf_GM2 <- sf_GM  # %>% select(LINK_ID, XFROM, YFROM,  XTO, YTO, geometry )   

# GeoMaster: Update X, Y
if(update_GeoMaster_XY){
  sf_GM2b <- update_XY(sf_GM2, "line")
} else{
  sf_GM2b <- sf_GM2
}

# Get all endpoints from GeoMaster
df_GM <- as.data.frame(sf_GM2b) %>% setDT()
GeoMaster_nodes_from <- df_GM[, c("XFROM", "YFROM")]
setnames(GeoMaster_nodes_from, c("X", "Y"))
GeoMaster_nodes_to <- df_GM[, c("XTO", "YTO")]
setnames(GeoMaster_nodes_to, c("X", "Y"))

GeoMaster_nodes <- rbindlist(list(GeoMaster_nodes_from, GeoMaster_nodes_to))
GeoMaster_nodes <- GeoMaster_nodes[, seq(.N), by = c("X", "Y")]
GeoMaster_nodes <- GeoMaster_nodes[V1 == 1, ]

# Write GeoMaster endpoints  
if(write_Interim){
  sf_GMNodes <- st_as_sf(GeoMaster_nodes, coords = c("X", "Y"), crs = 26917)
  write_sf(sf_GMNodes, GeoMaster_node_shpFile)
}


# STEP 2: Append GeoMaster endpoints with User Specified Nodes
sf_nodeIds2 <- update_XY(sf_nodeIds, "point")

df_nodeIds <- as.data.frame(sf_nodeIds2) %>% 
  select(X, Y,  Hwy_NodeId)  %>% 
  distinct() %>%
  setDT()


# Compute intergerized X, Y
df_nodeIds2 <- df_nodeIds[, c("Xint", "Yint") := list(as.integer(X), as.integer(Y))]
GeoMaster_nodes2 <- GeoMaster_nodes[, c("Xint", "Yint") := list(as.integer(X), as.integer(Y))]
setkeyv(GeoMaster_nodes2, c("Xint", "Yint"))
setkeyv(df_nodeIds2, c("Xint", "Yint"))

# Add Hwy Nodes IDs to endpoints
df_endpoints <- merge(GeoMaster_nodes2, df_nodeIds2, all.x = TRUE)
df_endpoints <- df_endpoints[, c("X.y","Y.y", "V1") := NULL]
setnames(df_endpoints, c("X.x","Y.x"), c("X","Y"))

# unmathced Hwy_Nodes (review found out these nodes are invalid and should be removed)
if(write_Interim){
  check <- df_endpoints[!is.na(Hwy_NodeId), ]
  c1 <- unique(df_nodeIds$Hwy_NodeId)
  c2 <- unique(check$Hwy_NodeId)
  unmatched_nodes <- c1[!(c1 %in% c2)]
  sf_node_unmatch <- sf_nodeIds2 %>% filter(Hwy_NodeId %in% unmatched_nodes)
  st_write(sf_node_unmatch, review_centroid_xy_ShpFile, append = FALSE)
}

# STEP 3: Generate Node Ids for all other nodes (User NOT specified nodes)
# Create two sets of Nodes: 
# 1) Node IDs from HwyNodes.shp and 
# 2) create node ids for rest starting from max node
df_endpoint_user     <- df_endpoints[!is.na(Hwy_NodeId), ] 
max_node_user        <- max(df_endpoint_user$Hwy_NodeId)
df_endpoint_create   <- df_endpoints[is.na(Hwy_NodeId), ] 
df_endpoint_create   <- df_endpoint_create[ , Hwy_NodeId := (.I + max_node_user)]
df_endpointIds       <- rbindlist(list(df_endpoint_user, df_endpoint_create)) 

#-------------------------------------------------------------------------------------------------------
# STEP 4: Add Centroid Nodes IDs to GeoMaster endpoints
# Read zonal centroids

sf_centroids   <- sf_centroids %>% rename(X = XFROM, Y = YFROM, Hwy_NodeId = TSM_NG)
st_crs(sf_centroids) = 26917

# Zone Centroids : Update X,Y for every point 
# NOTE: The zone_centroid.shp and centroid_connectors don't agree for 207 zones
# I uess user might had coded XFROM, YFROM in centroid connectors by hand to fix this problem
sf_centroids2  <- update_XY(sf_centroids, "point")

# Compute intergerized X, Y
df_centroids  <- as.data.frame(sf_centroids2) %>% select(X, Y, Hwy_NodeId) %>% setDT()
df_centroids  <- df_centroids[, c("Xint", "Yint") := list(as.integer(X), as.integer(Y))]
df_allNodeIds <- rbindlist(list(df_centroids, df_endpointIds), use.names = TRUE) 
df_allNodeIds <- df_allNodeIds[, c("Xint", "Yint") := NULL]

# Remove duplicates
df_allNodeIds[, duplicate := seq(.N), by = c("X", "Y")]
df_allNodeIds <- df_allNodeIds[duplicate == 1, ]
df_allNodeIds <- df_allNodeIds[, duplicate := NULL]


# Write all node IDs
if(write_Interim){
  sf_allNodes <- st_as_sf(df_allNodeIds, coords = c("X", "Y"), crs = 26917)
  write_sf(sf_allNodes, final_nodeIDs_ShpFile)
}

prep_end_time <- Sys.time()
runTime_prepareInputs <- prep_end_time - prep_start_time

#-------------------------------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------------------------
# STEP 5: Append A, B nodes for links in GeoMaster and Centroid Connector
# Read Centroid connectors

updateXY_start_time <- Sys.time()

# GeoMaster Links: Update X,Y for each link 
if(update_GeoMaster_XY){
  sf_GM2b <- update_XY(sf_GM2, "line")
} else{
  sf_GM2b <- sf_GM2
}
# Centroid Connectors Links: Update X,Y for each link 
# NOTE: The zone_centroid.shp and centroid_connectors don't agree for 207 zones and 
# so DO NOT update 
if(update_CenCon_XY){
  sf_CC2 <- update_XY(sf_CC, "line")
} else{
  sf_CC2 <- sf_CC
}
 
updateXY_end_time <- Sys.time()
runTime_updateXY <- updateXY_end_time - updateXY_start_time


# Append A,B Nodes
append_start_time <- Sys.time()

sf_CC3 <- append_AB(sf_CC2, df_allNodeIds)
sf_GM3 <- append_AB(sf_GM2b, df_allNodeIds)

# Are there Dupilcates?
# sf_GM3 <- setDT(sf_GM3)[, N := .N , by = "row_id"]
# x <- sf_GM3[N > 1, ]
# sf_GM3[ row_id == 273810 , ]

# Remove duplicates
# setDT(sf_GM3)[, duplicate := seq(.N), by = c("XFROM", "YFROM", "XTO", "YTO")]
# sf_GM3 <- sf_GM3[duplicate == 1, ]
# sf_GM3 <- sf_GM3[, duplicate := NULL]

# Check 
# check_untagged <- sf_CC3 %>% filter(is.na(A) | is.na(B))
# check_untagged <- sf_GM3 %>% filter(is.na(A) | is.na(B))


append_end_time <- Sys.time()
runTime_append_user_NodeIds <- append_end_time - append_start_time

#-------------------------------------------------------------------------------------------------------
# STEP 6: Add Reverse Direction (Let's do this on the consolidated network)
# 1) Add Centroid links for the "inbound" direction
# 2) Add GeoMaster links for "


reverse_start_time <- Sys.time()

if(do_reverse){
  
  sf_GM3 <- sf_GM3 %>% mutate(rev_dir = 0)
  # GeoMaster bi-directional links (get reverse)
  sf_GM3a <- sf_GM3 %>% 
    filter(DIR_TRAVEL == "B")
    
  sf_GM3b <- st_reverse(sf_GM3a) %>%
    mutate(A_rev = B,
           B = A,
           A = A_rev,
           XTO_rev = XFROM,
           YTO_rev = YFROM,
           XFROM = XTO,
           YFROM = YTO,
           XTO = XTO_rev,
           XTO = XTO_rev,
           rev_dir = -1) %>%
    select(-XTO_rev, -YTO_rev, -A_rev)
  
  # Merge layers directions
  df_GM_both <- rbindlist(list(setDT(sf_GM3), setDT(sf_GM3b)), use.names = TRUE)
  
  # Add reverse direction for centroid connectors
  sf_CC3 <- sf_CC3 %>% mutate(rev_dir = 0, DIR_TRAVEL = "B")
  sf_CC_rev <- st_reverse(sf_CC3)
  sf_CC_rev <- sf_CC_rev %>% 
    mutate(DIR = "IN",
           A_rev = B,
           B = A,
           A = A_rev,
           XTO_rev = XFROM,
           YTO_rev = YFROM,
           XFROM = XTO,
           YFROM = YTO,
           XTO = XTO_rev,
           XTO = XTO_rev,
           rev_dir = -1) %>%
    select(-XTO_rev, -YTO_rev, -A_rev)
  
  # Merge layers directions
  sf_cc_both <- rbind(sf_CC3, sf_CC_rev)
  

  
  
  if(write_Interim){
    st_write(sf_CC_rev,  sf_CC_rev_shpFile, append = FALSE)
    st_write(sf_cc_both, sf_cc_both_ShpFile, append = FALSE)
  }
  
  
  # Merge GeoMaster Links and Centroid Connectors (both directions)
  mpt <- st_cast(sf_cc_both, "MULTILINESTRING")
  df_mpt          <- setDT(mpt)
  df_GM_CC        <- rbindlist(list(df_GM_both, df_mpt), fill = TRUE)
  df_GM_CC        <- df_GM_CC[, row_id := .I]
}

#----------------------------------------------------------------------------------------------
# STEP 7: Merge GeoMaster Links and Centroid Connectors (both directions)

# Merge layers directions
# Ensure they both are of same geometry type to merge
# mpt <- st_cast(sf_cc_both, "MULTILINESTRING")

# Uni-directional links
if(!do_reverse){
  mpt <- st_cast(sf_CC3, "MULTILINESTRING")
  df_mpt          <- setDT(mpt)
  df_GM_CC        <- rbindlist(list(sf_GM3, df_mpt), fill = TRUE)
  df_GM_CC        <- df_GM_CC[, row_id := .I]
}

# Merge them from data.table then convert to sf
# df_cc_both <- setDT(sf_cc_both)

sf_GeoMaster_CC <- st_as_sf(df_GM_CC)

if(write_Interim){
  write_start_time <- Sys.time()
  st_write(sf_GeoMaster_CC, sf_GeoMaster_CC_ShpFile, append = FALSE)
  write_end_time <- Sys.time()
  print(paste(write_end_time - write_start_time))
}


reverse_end_time <- Sys.time()
runTime_reverse <- reverse_end_time - reverse_start_time





