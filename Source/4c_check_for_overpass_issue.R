
# Investigate the over pass issue

# Load the first version where user claimed error free GeoMaster
sf_v1 <- st_read(consoildate_links_ShpFile)
DT_v1 <- setDT(sf_v1)
DT_v1 <- DT_v1[FTEC %in% c(11, 12, 91, 92), ]

# Load the second version where limited access subgraph is first run then rest
sf_v2 <- st_read(consoildate_links_iter_ShpFile)
DT_v2 <- setDT(sf_v2)
DT_v2 <- DT_v2[FTEC %in% c(11, 12, 91, 92), c("A", "B")]
DT_v2 <- DT_v2[ ,same_as_V1 := 1]

DT_compare <- merge(DT_v1, DT_v2, 
                    by.x = c("A", "B"), 
                    by.y = c("A", "B"), 
                    all.x = TRUE)

# write out the results
overpass_issue <- DT_compare[is.na(same_as_V1), ]
st_write(st_as_sf(overpass_issue), overpass_issue_shpFile, append = FALSE)
  
