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
#----------------------------------------------------------------------------------------------
# STEP 7: Check Link connectivity ex:  "D ---> E <---- F"  Find such links

# Find all "A" nodes with no "From"s (ex: "E" above)  and 
# check against "B" nodes with valid "To" (ex: "F")
sf_GM4 <- copy(sf_GeoMaster_CC)

sf_GM4 <- data.frame(sf_GM4) %>% setDT()
from_A <- sf_GM4[ ,  .N, by = "A"]

unique_B <- unique(sf_GM4$B)
paste0("About ", length(unique_B) - nrow(from_A), " links seems to be in reverse")

# get "A" nodes with no From while have To
dt_B <- merge(data.table(B = unique_B), from_A, 
              by.x = "B", by.y = "A", all.x = TRUE)

dt_B[is.na(N), N := 0]
dt_B[, .N, by = "N"]
check_Bs <- dt_B[N == 0, ]

# check if there is a valid From for this B
sf_GM4 <- merge(sf_GM4, check_Bs, by.x = "B", by.y = "B", all.x = TRUE)

inconsistent_links <- sf_GM4[!is.na(N), ]
st_write(st_as_sf(inconsistent_links), "inconsistent_links_direction.shp", append = FALSE)

# How big of an issue is this?
# 1. How many are oneway links, meaning travel is not possible in model
one_vs_twoWay <- inconsistent_links[, .N, by = "TwoWay"]

# Oneway links must be fixed.
#----------------------------------------------------------------------------------------------
# Check for Elevation at the node by from & to directions
# Ex: 114231, shows EB direction is separated to at grade till this node, but
#  the following link shows going from at-grade to grade-seprated. The later part should be flipped.

# Combined master network with centroid connectors
DT <- setDT(sf_GeoMaster_CC)

# At B, to_Zlev
toB   <- DT[, c("B", "T_ZLEV")]
fromA <- DT[, c("A", "F_ZLEV")]

# Note, Links at the intersections with overpass will have different T_ZLEL and F_ZLEV.
# So fisrt identify them and remove (ex: 74298)
toB <- toB[, .N, by = c("B", "T_ZLEV")]
toB2 <- toB[ , FLAG := .N, by = "B"]  # FLAG > 1 two or more levels of elevations
overpass_Bnodes <- toB2[FLAG > 1, ]
other_Bnodes <- toB2[FLAG == 1, ]

fromA <- fromA[,  .N, by = c("A", "F_ZLEV")]
fromA2 <- fromA[ , FLAG := .N, by = "A"]  # FLAG > 1 implies two or more levels of elevations
overpass_Anodes <- fromA2[FLAG > 1, ]
other_Anodes <- fromA2[FLAG == 1, ]

# Investigate the "elevated ramp" issue
overpass_nodes <- unique(c(overpass_Bnodes$B,overpass_Anodes$A))
dt_opn <- data.frame(Hwy_NodeId = overpass_nodes, elevation = TRUE) %>% setDT()
dt_opn <- merge(dt_opn, overpass_Bnodes, by.x = "Hwy_NodeId", by.y = "B", all.x = TRUE)
dt_opn <- merge(dt_opn, overpass_Anodes, by.x = "Hwy_NodeId", by.y = "A", all.x = TRUE)


# Write location of all over-passes
if(!exists("sf_allNodes")){
  sf_allNodes <- st_read("Output/node_ids.shp")
}
dt_allNodes <- as.data.table(sf_allNodes)
dt_allNodes <- merge(dt_allNodes, dt_opn, by.x = "Hwy_NodeId", by.y = "Hwy_NodeId", all.x = TRUE)
dt_allNodes[is.na(elevation), elevation := FALSE]

sf_allNodes <- st_as_sf(dt_allNodes)
write_sf(sf_allNodes, "Output/node_ids.shp")

# No over-pass nodes (but includes ramps going from at-grade to grage-separation)
# other_Bnodes2 <- other_Bnodes[!(B %in% overpass_nodes), ]
# other_Anodes2 <- other_Anodes[!(A %in% overpass_nodes), ]

# Find inconsistent nodes
other_nodes <- merge(overpass_Bnodes, overpass_Anodes, by.x = "B", by.y = "A", all.both = TRUE)

other_nodes[FLAG.x != FLAG.y, FLAG := 1]
inconsistent_elev_nodes <- other_nodes[!is.na(FLAG), ]








