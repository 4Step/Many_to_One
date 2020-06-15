# Introduction 
## Many-to-One Tool: 
 "Many-to-One" Tool is a network consolidation tool to condense the street network into modeling network. A street network is procured from TeleAtlas or Navteq or Open Street Map, which contains most detailed network used in navigation devices (GPS in phones & cars) & routing, directions and similar map-based web-applications. For modeling we don't need this resolution and thus many local streets can be omitted and further major roadway network could be consolidated (aggregated from multi-line segment to simple segments). However the aggregation process works  in assosication to zone system (centroid connectors, external stations) and the user defined criteria for unionizing the links (links need to carry same speed, facility types, area types, capacity, number of lanes and many mores..). The tool is designed to do the consolidation part for a given network. 

 **NOTE: The typical street network doesn't carry modeling attributes such as capacity, area type, facility types and these are appended to the streets network prior to running the tool. 

## History:  
This is the third generation tool. 
version 1: MTPGIS - This is the first version written by Jim Fennessy in Tranplan. Requires Tranplan ? not sure.
version 2: Many-to-One Tool - This is the second version written by Mark Knoblauch in C# as an ArcGIS Add-in (VB first then eventually in C-Sharp). The program is run from ArcGIS and requires ArcGIS 10.6 license.
version 3: This is written in C++ but interfaced with R to use spatial libraries and data processing. This is open source softwares and can be run on any device that runs R. 

# Input Files
 Shape Files
 Centroids.shp             : Centroids (node ids)
 HwyNodeIDst.shp           : Hwy Nodes (node ids) - Not available for all nodes
 GeoMaster.shp             : Highway links (no A, B nodes)
 Centroid_Connectors.shp   : Centroid links (A, B)

## Processing Steps
 1. Create a list Node id from the four files   
      - Create endpoints for GeoMaster.shp (GeoMaster_Nodes.shp)
      - Create centroid connector other-end nodes (one end is zone, the other-end is highway, get that node)
         - Process multilinestrings to write out the first & last coordinates and pick the end that is not zone centroid.
      - Read HwyNodeIDst.shp for list of user specified Node IDs
      - Read Centroids.shp for list of user speicified TSM Zone IDs
      - Add both user specified nodes into one list and generate nodes for all other unlisted nodes in GeoMaster
 2. Append Node ids as A, B to both GeoMaster.shp and Centroid_Connectors.shp
      - Update X,Y for each link
 3. Merge GeoMaster.Shp and Centroid_Connectors.shp into one file

## RCPP for efficiency
 4a. Create a list of from_Node -> to_Node searchable list 
 4b. Append, number of intersections to Node (either QGIS or loop by Node, direction and get list of A's & B's )
 4c. Loop over each Link, get A-B, check next link (lookup b in from_Node -> to_node)
 4d. If attributes of next A-B are same as this A-B and there are no intersections for next B mark as 
     1) same group with groupN
     2) add sequence of links
 4e. group_by or nest (groupN) and run st_union. Try to keep it at the disaggregate level
 4f. Get first A and last B node for the group (at the end we have same df with 3 extra fields: A, B, unionized MultiLineString)
 4g. write out groupN for each A, B (MTPGIS lookup) and then write out first row of each group to list
 4h. write shape file


# Design / Methodology 

# User Guide

# Build and Test
Comparison to prior work


