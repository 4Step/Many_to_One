#include <Rcpp.h>
#include <numeric>
#include <string>
#include <sstream>

using namespace Rcpp;


// overcome compiler issue
//https://stackoverflow.com/questions/12975341/to-string-is-not-a-member-of-std-says-g-mingw
namespace patch
{
template < typename T > std::string to_string( const T& n )
  {
    std::ostringstream stm ;
    stm << n ;
    return stm.str() ;
  }
}

// declare constructors
IntegerVector get_indices( IntegerVector Geo_id, int Uid);

List check_get_geom(int seq_tracker, IntegerVector found_GeoID_index, 
                    IntegerVector seq, List geom, IntegerVector A, IntegerVector B);

String get_MultiLineString(List lineseg,  bool last_leg);

String MergeGeometry2(DataFrame df, String ID, String Seq, IntegerVector id_unique);

IntegerVector subset(IntegerVector x, int Anode);
  

// [[Rcpp::export]]
CharacterVector MergeGeometry(DataFrame df, String ID, String Seq, IntegerVector id_unique) {
  // start as same
  IntegerVector id = df["GeoMerge_ID"];
  IntegerVector seq = df["GeoMerge_Order"];
  IntegerVector A = df["A"];
  IntegerVector B = df["B"];
  List geom = df["geometry"];
  
  int uid;
  int seq_tracker;
  bool all_segments_in;
  IntegerVector found_GeoID_index;
  List interim;
  int anode, bnode = 0;

  List geom_seq;
  String merged_geom;
  
  CharacterVector result;
    
  // Loop over unique ids
  for(int u = 0; u < id_unique.length(); ++u){
    
    uid = id_unique[u];
    seq_tracker = 0;
    all_segments_in = 0;
    
    Rcout << " Unique id is " << uid << std::endl;
    
    // find all indicies that match to unique id
    found_GeoID_index = get_indices(id, uid);
    
    while(!all_segments_in){
      
      Rcout << "Seq Tracker " << seq_tracker << " GeoID Index Length " << found_GeoID_index.length() << std::endl;
      
      // get infro for the matched line segment
      interim = check_get_geom(seq_tracker, found_GeoID_index, seq, geom, A, B);
      
      geom_seq = interim["geom"];
      found_GeoID_index = interim["revised_index"];
      
    
      // check segments left (last segment)
      if(found_GeoID_index.length() == 1) all_segments_in = 1;
      
      // need to get Anode as well for the first match
      if(seq_tracker == 0) anode = interim["Anode"];
      
      if(seq_tracker == 0) {
        merged_geom =  "\"LineString (";
      } 
      
      // merge geometry
      merged_geom += get_MultiLineString(geom_seq, 0) ;
      // merged_geom += ", ";
        
      // update tracker to next one
      seq_tracker += 1;
      

    }
    
    // Get the last segment here 
    Rcout << "Seq Tracker " << seq_tracker << " GeoID Index Length " << found_GeoID_index.length() << std::endl;
    geom_seq = geom[found_GeoID_index[0]];
    bnode = B[found_GeoID_index[0]];
    merged_geom += get_MultiLineString(geom_seq, 1);
    merged_geom += ")\";\"" + patch::to_string(uid) + "\";\"" + patch::to_string(anode) + "\";\"" + patch::to_string(bnode) +"\"";
    
    result.push_back(merged_geom);
  }

  return result;
}


// Merge geometry
// [[Rcpp::export]]
String get_MultiLineString(List lineseg, bool last_leg) {
  
  String ML_coords;
  double x, y ;
  
  for(int l = 0; l < lineseg.length(); ++l){
    
    List mat = lineseg[l];
    int coord_size =  mat.length() / 2;
    
    for(int e = 0; e < coord_size; ++e) {
      x = mat[e];
      y = mat[e + coord_size];
      
      // Single String
      if(last_leg & (e + 1 ==  coord_size)) {
        ML_coords += patch::to_string(x) + " " + patch::to_string(y);
      } else{
        ML_coords += patch::to_string(x) + " " + patch::to_string(y) + ", " ;
      }
      
       // ML_coords += patch::to_string(x) + " " + patch::to_string(y) ;
      
    }
  } 
  
  return ML_coords;
}



// Find the geom for the given sequence in the list of provided indices
// [[Rcpp::export]]
List check_get_geom(int seq_tracker, IntegerVector found_GeoID_index, 
                    IntegerVector seq, List geom, IntegerVector A, IntegerVector B) {
  
  List pick_geom;
  IntegerVector sub_GeoID_index;
  int anode = 0;
  List result; 
  
  // loop over all indicies, check & match sequence for a given seq_tracker and extract its geometry
  for(int s = 0; s < found_GeoID_index.length(); ++s){
      
     if(seq_tracker == seq[found_GeoID_index[s]]) {
       
       // get geometry
       pick_geom = geom[found_GeoID_index[s]];
       
       // get Anode for the first sequence (seq_tracker = 0)
       anode = A[found_GeoID_index[s]];
       
       // remove matched index fron the indicies
       sub_GeoID_index = subset(found_GeoID_index, found_GeoID_index[s]);
       
       break;
       
     }
  }
  
  result["geom"] = pick_geom;
  result["revised_index"] = sub_GeoID_index;
  result["Anode"] = anode;
  
  return result;
}


// [[Rcpp::export]]
IntegerVector subset(IntegerVector x, int Anode) {
  
  IntegerVector res;
  
  if(x.length() > 1){
    for(IntegerVector::iterator it = x.begin(); it != x.end(); ++it) {
      if(*it != Anode) {
        res.push_back(*it);
      }
    }
  } else {
    res = x;
  }
  
  return res;
}



// [[Rcpp::export]]
IntegerVector get_indices( IntegerVector Geo_id, int Uid) {
  
  IntegerVector Geo_id_index;
  // iterator
  for( IntegerVector::iterator it = Geo_id.begin(); it != Geo_id.end(); ++it ){

      if(*it == Uid) {
        Geo_id_index.push_back(it - Geo_id.begin());
      }
    }
  
 return Geo_id_index;
}



// [[Rcpp::export]]
String MergeGeometry2(DataFrame df, String ID, String Seq, IntegerVector id_unique) {
  
  // start as same
  IntegerVector id = df["GeoMerge_ID"];
  IntegerVector seq = df["GeoMerge_Order"];
  IntegerVector A = df["A"];
  IntegerVector B = df["B"];
  
  List geom = df["geometry"];
  
  // List combine_geom;
  List lineseg ;
  int uid;
  int tracK_seq;
  double x, y;
  // NumericVector X_coord, Y_coord;
  
  double a, b;
  bool found_first = 0;
  int index;
  String ML_coords;

  for(int u = 0; u < id_unique.length(); ++u){
    
    uid = id_unique[u];
    tracK_seq = 0;
    
    List combine_sub_geom;
    NumericVector X_coord, Y_coord;
    
    for( IntegerVector::iterator it = id.begin(), jt = seq.begin(); it !=  id.end(); ++it, ++jt) {
      
    // for(int i = 0; i < id.length(); ++i){
      
      // TODO:: loop over sequence and check 
      // if(id[i] == uid){
      if((uid == *it) & (tracK_seq == *jt)){
        
        index = it - id.begin();
        
        // Find sequence (loop over and keep track of items)
        // for(int s = 0; s < seq.length(); ++s){
          
          // loop over sequence elements
          // seq[s] == tracK_seq;
          tracK_seq += 1;
          
          // Get Anode from first match 
          if(!found_first) {
            a = A[index];  // a = A[i];
            found_first = 1;
          }
          
          // Update B everytime and the last one is the last B-node
          b = B[index] ;  // b = B[i];
          
          // Rcout << "UID = " << uid << " Order" << seq[i] << std::endl;
          
          lineseg = geom[it - id.begin()]; // lineseg =  geom[i];
          
          for(int l = 0; l < lineseg.length(); ++l){
            
            List mat = lineseg[l];
            int coord_size =  mat.length() / 2;
            
            for(int e = 0; e < coord_size; ++e) {
              x = mat[e];
              y = mat[e + coord_size];
              
              // MULTILINESTRING ((10 10, 20 20, 10 40),
              //                  (40 40, 30 30, 40 20, 30 10))
              
              // Merge line segments (assumed it was read in order)
              // if((i == 0) & (l == 0) & (e == 0)) Rcout << "MultiLineString ((";
              if((tracK_seq == 1) & (l == 0) & (e == 0)) Rcout << "MultiLineString ((";
              Rcout << x << " " << y;
              if((e + 1) < coord_size) Rcout << ", ";
              // if(((e + 1) ==  coord_size) & ((l + 1) ==  lineseg.length()) & ((i+ 1) == id.length())) Rcout << "))," << uid << ", " << a << ", " << b << std::endl;
              if(((e + 1) ==  coord_size) & ((l + 1) ==  lineseg.length()) & ((it + 1 == id.end()))) Rcout << "))," << uid << ", " << a << ", " << b << std::endl;
              
              // Single String
              // if((i == 0) & (l == 0) & (e == 0))  ML_coords = "\"MultiLineString ((";
              if((tracK_seq == 1) & (l == 0) & (e == 0))  ML_coords = "\"MultiLineString ((";
              ML_coords += patch::to_string(x) + " " + patch::to_string(y) ;
              if((e + 1) < coord_size) ML_coords +=  ", " ;
              // if(((e + 1) ==  coord_size) & ((l + 1) ==  lineseg.length()) & ((it.end() + 1) == id.length())) ML_coords += "))\";\"" + patch::to_string(uid) + ";\"" + patch::to_string(a) + ";\"" + patch::to_string(b) +"\" \n";
              if(((e + 1) ==  coord_size) & ((l + 1) ==  lineseg.length()) & ((it + 1 == id.end()))) ML_coords += "))\";\"" + patch::to_string(uid) + ";\"" + patch::to_string(a) + ";\"" + patch::to_string(b) +"\" \n";
              
            }

          }
          
        }
        
      }

    }

  // }

  return ML_coords ;
  
}  

