library(tidyverse)
library(data.table)
library(foreign)
library(rgdal) 
library(sf)
library(Rcpp)


cube_shp <- "CUBE/CubeUSA_Links_FL.shp"
mtoGIS <- "Output/SF_FL_walked_network.shp"

start_time <- Sys.time()

sf_cube <- st_read(cube_shp)
sf_mto <- st_read(mtoGIS)

end_time <- Sys.time()
end_time - start_time


dt_cube <- sf_cube %>% 
  select(A, B, geometry) %>%
  mutate(type = "cube") %>%
  as.data.table()

dt_mto <- sf_mto %>% 
  select(A, B, geometry) %>%
  mutate(type = "mto") %>%
  as.data.table()

# Compare and flag links
dt_both <- merge(dt_cube, dt_mto, 
                 by.x = c("A", "B"), 
                 by.y = c("A", "B"), 
                 all = TRUE)

# Check of A-B are the same
dt_both <- dt_both[, valid_flag := 0]
dt_both[is.na(type.x), valid_flag := 1]  # Not in cube but in mto
dt_both[is.na(type.y), valid_flag := 2]  # Not in mto but in cube

# Check if geometries are the same
# dt_both <- dt_both[, valid_geom := 0]

# function to compare geometry
# dt_both [, valid_geom := mapply(function(geom_x, geom_y){return(unlist(geom_x[[1]] == geom_y[[1]]))},
#                                 dt_both$geometry.x, dt_both$geometry.y)]
# dt_both[ , valid_geom2 := sapply(valid_geom, function(x) {x[1]})]
# 
# dt_both[ , .N, by = c("valid_flag", "valid_geom2")]

# Compute one geometry
dt_both <- dt_both[ , geometry := geometry.x]
dt_both[is.na(type.x), geometry := geometry.y]
dt_both <- dt_both[ , type := type.x]
dt_both[is.na(type.x), type := type.y]
dt_both <- dt_both[, c("geometry.x", "geometry.y", "type.x", "type.y") := NULL]

dt_both[, .N, by = valid_flag]
sf_both <- st_as_sf(dt_both)



# Check geometry and drop duplicate geometries
check_geometry <- dt_both[valid_flag != 0, ]
d = st_difference(st_as_sf(check_geometry))
data.table(d)[, .N, by = type]

d <- data.table(d)[ , valid_flag := 3]
d <- d[, c("type", "geometry") := NULL]

# Append checked geometry flags
dt_both <- merge(dt_both, d, 
                 by.x = c("A", "B"), 
                 by.y = c("A", "B"), 
                 all.x = TRUE)

dt_both <- dt_both[, valid_flag := valid_flag.x]
dt_both[!is.na(valid_flag.y), valid_flag := valid_flag.y]  

# dt_both_unique = st_difference(st_as_sf(dt_both))
dt_both[, .N, by = valid_flag]
dt_both[, c("valid_flag.x", "valid_flag.y") := NULL]

sf_both <- st_as_sf(dt_both)
st_write(sf_both, "Output/Compare_CUBE_vs_MTO.shp", append = FALSE)

# dt_both <- dt_both_unique[valid_flag == 3, ]
st_write(sf_both, "Output/Compare_CUBE_vs_MTO_geometry_difference.shp", append = FALSE)




