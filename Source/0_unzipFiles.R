library(utils)


# unzip files
geoMaster_zipFile          <- "Input/GeoMaster.zip"
zone_centroids_zipFile     <- "Input/Zone_Centroids.zip"
zone_cC_zipFile            <- "Input/Centroid_Connectors.zip"
User_NodeIDs_zipFile       <- "Input/Hwy_NodeIds.zip" 

input_zipfiles <- c(geoMaster_zipFile, zone_centroids_zipFile, zone_cC_zipFile, User_NodeIDs_zipFile)

# create a temp directory
dir.create("Input/temp")

for (d in 1:length(input_zipfiles)){
  unzip(zipfile = input_zipfiles[d], exdir = "Input/temp")
}


# List of Input Files
geoMaster_shpFile          <- "Input/temp/GeoMaster.shp"
zone_centroids_ShpFile     <- "Input/temp/Zone_Centroids.shp"
zone_cC_ShpFile            <- "Input/temp/Centroid_Connectors.shp"
User_NodeIDs_shpFile       <- "Input/temp/Hwy_NodeIds.shp"


# at the end once program is done, delete unzipped files
# unlink("Output/temp", recursive=TRUE)

