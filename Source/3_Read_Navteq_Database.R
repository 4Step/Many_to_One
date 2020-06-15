
library(tidyverse)
library(data.table)
library(foreign)
library(rgdal) 
library(sf)

start_time <- Sys.time()

# USer can read directly if not in memory
if(!exists("sf_Navteq")){
  sf_Navteq <- st_read("Input/NavTeq_Export_20190604/NavTeq_Export_20190604/all_roads_nav.shp")
}

end_time <- Sys.time()
end_time - start_time

# Old database
start_time <- Sys.time()
if(!exists("sf_Navteq11")){
  
  sf_Navteq11 <- st_read("Input/Navteq_2011_q4/Street17.shp")
}

end_time <- Sys.time()
end_time - start_time

sf_Navteq[LINK_ID == 106118338,]

114231