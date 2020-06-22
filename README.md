# Introduction
A street network is procured from TeleAtlas or Navteq or Open Street Map, which contains most detailed network used in navigation devices (GPS in phones & cars) & routing, directions and similar map-based web-applications. For modeling we don't need this resolution and thus many local streets can be omitted and further major roadway network could be consolidated (aggregated from multi-line segment to simple segments).

## Many-to-One Tool:
 "Many-to-One" Tool is a network consolidation tool to condense the street network into modeling network.  The aggregation process works in association with the zone system (centroid connectors, external stations) and the user defined criteria for unionizing the link segments (ex: links of same properties like speed, facility types, area types, capacity, number of lanes). The tool is designed to do the consolidation part for a given network.

 *NOTE: The typical street network doesn't carry modeling attributes such as capacity, area type, facility types and these are appended to the streets network prior to running the tool*.

## History:  
This is the third generation tool.  

**version 1: MTPGIS** - This is the first version written by Jim Fennessy in Tranplan. Requires Tranplan ? not sure.  
**version 2: Many-to-One Tool**  - This is the second version written by Mark Knoblauch in C# as an ArcGIS Add-in (VB first then eventually in C-Sharp). The program is run from ArcGIS and requires ArcGIS 10.6 license.  
**version 3: MTO** : This is written in C++ but interfaced with R to use spatial libraries and data processing. This is open source software and can be run on any device that runs R.

# Input Files
 ### Shape Files
 1. Centroids.shp             : Centroids (node ids)  
 2. HwyNodeIDst.shp           : Hwy Nodes (node ids) - Not available for all nodes  
 3. GeoMaster.shp             : Highway links (A, B, link attributes)  
 4. Centroid_Connectors.shp   : Centroid links (A, B, link attributes)  

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

## C++ (Rcpp) for efficiency
 4a. Create a list of from_Node -> to_Node searchable list  
 4b. Append, number of intersections to Node (either QGIS or loop by Node, direction and get list of A's & B's )  
 4c. Loop over each Link, get A-B, check next link (lookup b in from_Node -> to_node)  
 4d. If attributes of next A-B are same as this A-B and there are no intersections for next B mark as:  
     1) same group with groupN  
     2) add sequence of links  
 4e. group_by or nest (groupN) and run st_union. Try to keep it at the disaggregate level  
 4f. Get first A and last B node for the group (at the end we have same df with 3 extra fields: A, B, unionized MultiLineString)  
 4g. write out groupN for each A, B (MTPGIS lookup) and then write out first row of each group to list  
 4h. write shape file  

# Background:
As part of a developing a "Network Manager" tool to perform:

1. Network Manager for multi-resolution networks (spatial resolution) to add resolution from regional models.
2. Future year project manager,
3. Add detail subarea network (importing regional or even more detailed OSM networks).

The basic concept is, it wraps “many-to-one tool” and makes a series of calls to perform network conflation for projects.  Unfortunately, the second generation “Many-to-One” ArcGIS add-in is not intended for this type of work,  is not scalable to large networks, and further complicated by long runtime.

A brand new tool in C++ and wrapped it under R for the interface is developed, that runs in under 3 minutes (see table below). The first 5 steps are the data preparation steps and next 5 steps are the actual program. I need to finish couple of functions in C++ to reduce mergeLineSegments to a few seconds (currently this is in R  and need to be moved to C++ there by reducing by minute or so).  I have debugged it and added logic to handle various situations (see Data issue section below).

## Processing Run Time

The program runs in less than 3 minutes to consolidate 480k streets line segments into ~200k model network links.  

| N  | Program Step        | Time               |
|----|---------------------|--------------------|
| 1  | read_shapeFiles     | 22.57284   secs    |
| 2  | prepareInputs       | 11.32563   secs    |
| 3  | updateXY            | 7.9782     secs    |
| 4  | append_user_NodeIds | 0.6721101  secs    |
| 5  | reversing_links     | 32.92402   secs    |
| 6  | Cpp_dataStructures  | 6.698382   secs    |
| 7  | Cpp_Compiler        | 0.07978511 secs    |
| 8  | walkTheGraph        | 2.053762   secs    |
| 9  | mergeLineSegments   | 52.15846   secs    |
| 10 | writeShp            | 8.444442   secs    |
|    | Total Time          | 144.90763121  secs |


# Approach:
The approach is completely new (see Network Manager ppt slides 6 - 17) and is totally object oriented program (OOP) where the idea is to walk the entire network (link by link), check current link properties (attributes) against next link’s to identify if they are mergeable. If so then it gives a unique id and keeps the sequence of the links walked.   

**Algorithms**: The C++ program implements two custom algorithms  
1)	First to classify a passing node as:   
    * a) pass-thru,    
    * b) intersection at-grade   
    * c) grade-separated (overpass / underpass)   
    * d) elevated ramps (one end at-grade and the other elevated),   
    * e) merge node or split nodes.   

2)	Second algo to walkTheGraph, where Depth-First Search graph algorithm is used (ELToD logic is Breadth-First Search). See slides 27 – 30 for graph theory and key differences in the two approaches and when to use.    

**Compare network attributes**: One of the handy things is,  the user can specify a list of customable fields to compare successive links.

**Debug / custom runs**: Since C++ functions are exposed to R, user can call these functions in R as well and test a small portion of the network. The demo slides 14-17 are run from R with C++ functions.
Data Structures: In order to make these algorithms extremely fast, two new data structure “linked list” are created in C++ . See slides 24 – 26 for difference in runtime. The “indexed linked-list” takes under a second to find next-node where the standard vector took about 15 minutes to finish the same task.

**Scalability**: See slides 21 – 23. A bit hard to follow needs some explanation of big O concept to understand the charts. Bottom line there is a “find” function written in standard logic cannot scale but algorithmically written (like binary_search function) scales as it reduces dampens the runtime by log(n). This is the critical difference in dropping the runtime significantly. Difference of minutes to milli-seconds.  The first attempt took about 8.5  minutes for the “walkTheGraph” and implement new methods took under 2 seconds for checking 480,000 links, identifying next link, compare against their successive links.

![Overpass Link Segments Consolidation](figures/overpass_details.PNG)

# Input / Output
**Input**:
1) GeoMaster.shp   
2) Hwy_NodeIds.Shp (user defined node IDs)   
3) Zonal Centroids and   
4) Centroid connectors  

**Output**:
SF_FL_walked_network.Shp (several interim files can be written out)

# Data Preparation Steps
- The coordinates of highway links nodes, UserID are recomputed in the very first step. Similarly Centroid connectors an centroids are also updated but it produced inconsistent node coordinates for 202 nodes. Appears zone centroids are not snapped to centroid connectors. So for now this update is not run.  
-	Node numbers are assigned to every node, first user-specified nodes are used and for all remaining nodes, program generates nodes. User can choose to write back these nodes back to the network so that nexttime it can be skipped similar to User specified nodes.  
-	Each link is now coded with A-B link (from N and to N).  
-	Reverses links  
-	Merges all links (GeoMaster, GeoMaster_bi-dir_reverse, Centroid Connectors, Centroid Connectors_reverse) into one file.

**Data issues**: Some of the link data is not accurate or missing in the GeoMaster (see slides 31- 41 for a brief intro overview of variations in link data and  Review_OneWay_links.pptx).  
- All links are coded uni-directional and while this shouldn’t be a problem (see slide 32),
-	There are numerous instances on bi-directional links where they are inconsistently coded like both meeting at the center node  (A -> B <- C).  This confuses “walkTheGraph” algo it treats it as two segments. See slides 33 to 36, about 10K links have this issues (3.5% of the links).  The quick solution was to code in reverse direction for all bi-directional links and let algo solve it.   
- Multiple duplicate user ID nodes (see slide 37). Same location but two or more nodes.  The lowest value is used in the program. Ideally, clean the input file.
-	Missing links (slide 38): Only centroid connectors and externals terminal ends. Exceptions are coded in the program to handle such links.
-Inconsistent Elevation coding (slide 39): elevated ramps (going from at-grade (Z = 0)  to grade-separated (Z = 1)) are not consistently coded between the two successive links. Meaning, say they are two links AB and BC [A -> B -> C], the B elevation is 1 in A-B link and 0 in BC link. Basically, some one has to jump of the bridge to continue this route. “walkTheGraph” algo leaves leave it as is (no merging of such segments). Algo shouldn’t correct the input data errors.
-	Overpasses (slide 40 - 42): Only two nodes show two level overpass and rest of 1909 show single elevation. The overpass nodes are also inconsistently coded. This is not a problem with the algo but just seems odd to look at it.


# Logger
A log file can be reported out for logging of data to ensure the tool make sense and produces nearly identical results as the existing tool.  As the program walks thru each node, it classifies every node and lists out details of situation it encountered (ex: found grade-separated or found a merge link or leaving a split link node or uni-directional or bi-directional with opposite travel,  found inconsistent from / to grades or valid overpass).  Then it reports what action it took, whether it continued to next link or stopped at the node (meaning the link consolidation ends). Also, as required, it compares the next link attributes (whether all user supplied field names are same) in addition to intersection analysis.

![Program Insights](figures/program_insights.PNG)

Overall, the program consolidates 487,764 arcs to 198,156 which is quite close to  the Many-to-One tool with 200,964. This difference exists for two known reasons:
1.	The current Many-to-one keeps links (doesn’t consolidate) if the nodeID is a user supplied node (HwyNodeId), although there is no reason to maintain separate link segments. In my program it makes a logical decision to merge as the situation permits, thinking user meant to do this.  I can add additional logic to skip terminating at such nodes, giving user what they supplied.

2.	There are duplicate nodes in GeoMaster (same location but 3 or more different IDs).  The current tool picks the one it encounters first (which is not a logical pattern for us to know and to implement in this new tool). So, this ends up reporting inconsistent A-B links between the two version tools even though they represent exactly the same link (we know this by comparing geometry).  The only way to overcome this is as, Mark suggested to Chris, find the final HwyIds remained at the end (in the current process) and remove the remaining duplicates from the GeoMaster.

The new program now runs in under 3 minutes without the  “logger” and turning on the logger, the program writes detailed analysis to a text file (as shown in the above figure Program Insights). Note the size is ~ 500 MB and takes 1 additional minute totaling to under 4 minutes. The current logger is using standard R output where the layered information comes from C++ -> R console -> R prints out a text file instead of directly from C++ takes would take only a few seconds. This could be improved in the next version if required.


# Design / Methodology

![Intersection Criteria](figures/program_criteria.PNG)

# User Guide


# Build and Test
Comparison to prior work  
![Program Insights](figures/program_checks.PNG)
