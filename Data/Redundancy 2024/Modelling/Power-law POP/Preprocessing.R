shell('cls'); rm(list=ls())
setwd('C:\\Users\\PGGARR\\Documents\\GitHub\\PostDoctoralWork2020\\P.Smith\\Publishing\\Javascript Experiments\\Daz2024_PostStimCue\\results')
library('dplyr')
library('tidyverse')
library(purrr)
select = dplyr::select

v = list(theme = list())
v$theme = theme(  
  plot.title = element_text(face = "bold", hjust = 0.5, size = 18), 
  axis.title = element_text(face = 'bold', size = 16, color='black'),
  axis.text  = element_text(size=14, color='black'), 
  axis.line = element_line(colour = 'black', size = .5), 
  legend.title = element_blank(), 
  legend.position = 'right',
  legend.text = element_text(size=14),
  panel.grid.major = element_blank(), 
  panel.grid.minor = element_blank(),
  panel.background = element_blank(),
  strip.background = element_blank(),
  strip.text.x = element_text(size = 16, face = "bold"),
  strip.text.y = element_text(size = 14, face = "bold" ))

data = read.csv('CSVresults\\CSVresults_2024-08-05_.csv') 
data1 = read.csv('CSVresults\\CSVresults_2024-08-05_local_data_ES.csv') 
data1[,names(data)[!names(data) %in% names(data1)]] = NA
data = rbind(data, data1[,names(data)])
data1 = read.csv('CSVresults\\CSVresults_2024-10-02_local_data_ES.csv') 
data1[,names(data)[!names(data) %in% names(data1)]] = NA
data = rbind(data, data1[,names(data)])
rm(data1)

# Add in ES' local data
data$session[data$uid %in% 'c867c9c501909b83681c7524605ef053'] = 10
data$session[data$uid %in% '48caf82f0ab6330892f9f0470c51eee1'] = 5
data$survey_code[data$uid %in% c('c867c9c501909b83681c7524605ef053','48caf82f0ab6330892f9f0470c51eee1')] = 'ES'

Paul = c('b88af392cfdd207bd299775a48517b3d', 'ba80bae5697013b8d27ac4f6334c53c3')
Daz = c('54b4cf253f2415909a9b16fd3774cf47', '8b08cb3f0752c7605fbd169fe4f6ffb5')
data$uid = as.character(data$uid)

data$survey_code = as.character(data$survey_code)

data$survey_code[data$uid %in% Paul] = 'PGexp1'
data$survey_code[data$uid %in% Daz] = 'YLexp1'

data$uid = factor(data$survey_code)

demo = data %>% select(uid, response) %>% filter(grepl("age|gender|colorblind", response, ignore.case = TRUE)) %>% 
    mutate(colorblind = str_extract(response, "(?<=colorblind': ')[^']+(?=')"), gender = str_extract(response, "(?<=gender': ')[^']+(?=')"), age = as.numeric(str_extract(response, "(?<=age': ')[^']+(?=')"))) %>% 
    group_by(uid) %>% summarize(age = max(age, na.rm = TRUE),
    gender = first(na.omit(gender)), colorblind = first(na.omit(colorblind)))

data = data %>% filter(trial_event == 'stimulus_wheel_display_event') %>% 
  select(uid, start_date_local, session, num_items, redundancy, 
         target_angle_norotation, response_derotated_degress, response_error_deg, response_RT, 
         response_degrees, response_radians, rotation, leave_center_RT, points, 
         target_color, target_patchN, patch_angles_from_center, all_patch_colors, all_patch_angles, 
         started_outof_center, too_fast_trigger, too_slow_trigger,
         timeout, tab_away_count)

data$redundancy[data$num_items == 1] = 1

data = data %>%
  mutate(all_patch_angles = gsub("\\[|\\]", "", all_patch_angles)) %>% # Remove brackets
  separate(all_patch_angles, into = paste0("Patch_Color_Angle", 1:6), sep = ",\\s*", fill = "right", extra = "drop") %>% 
  mutate(across(starts_with("Patch_Color_Angle"), as.numeric))

data = data %>%
  mutate(patch_angles_from_center = gsub("\\[|\\]", "", patch_angles_from_center)) %>% # Remove brackets
  separate(patch_angles_from_center, into = paste0("Patch_Locations", 1:6), sep = ",\\s*", fill = "right", extra = "drop") %>% 
  mutate(across(starts_with("Patch_Locations"), as.numeric))

data = data %>% rowwise() %>% 
  mutate(ColorN = length(unique(c_across(starts_with("Patch_Color_Angle"))[!is.na(c_across(starts_with("Patch_Color_Angle")))]))) %>%
  ungroup()

for (ii in 1:nrow(demo)){
  data$age[data$uid == demo$uid[ii]] = demo$age[ii]
  data$colorblind[data$uid == demo$uid[ii]] = demo$colorblind[ii]
  data$gender[data$uid == demo$uid[ii]] = demo$gender[ii]
}

# Remove string vector brakets
str2num = function(x, RGB){ 
  if (missing(RGB)){ RGB = FALSE  }
  x = as.character(x)
  x[x == '[None]'] = NA
  s = as.numeric( unlist( str_split( gsub("([,.-])|[[:punct:]]", "\\1", x), ',' ) ) )
  if (RGB){
    sc = 1
    k = data.frame( matrix(-1, length(s)/3, 3))
    names(k) = c('R','G','B')
    for (ii in 1:(length(s)/3) ){
      for (kk in 1:3){
        k[ii,kk] = s[sc]
        sc = sc + 1
      }
    }
    return (k)
  }
  return ( s ) 
}

colnames(data)[colnames(data) == 'response_error_deg'] = 'response_error'

data = data %>% mutate(across(c('response_derotated_degress', 'response_error', "response_degrees", 'response_radians',
                                "rotation", "leave_center_RT", "response_RT", 'points'), str2num))



# Convert items to factors
data$num_items         = factor(data$num_items, 
                                levels = c(1,2,4,6),
                                labels = c('One Item','Two Items','Four Items', 'Six Items')
)

# Convert items to factors
data$redundancy         = factor(data$redundancy, 
                                levels = c(1, 0),
                                labels = c('Redundant Cued','Non-Redundant Cued')
)

data = data %>% mutate(across(.cols = c('started_outof_center', 'too_fast_trigger', 'too_slow_trigger', 'timeout'), ~ .x == '[True]'))

data$ColorN = factor(data$ColorN, 
                     levels= c(1, 2, 4, 6), 
                     labels = c('One Color','Two Colors','Four Colors','Six Colors'))

# Reorder columns for easy viewing
data = data %>% select(uid, start_date_local, session, age, colorblind, gender, num_items, ColorN, redundancy, 
                       response_error, response_RT, rotation,
                       response_degrees, response_radians, target_angle_norotation, response_derotated_degress,
                       target_color, target_patchN, 
                       Patch_Locations1, Patch_Locations2, Patch_Locations3, Patch_Locations4, Patch_Locations5, Patch_Locations6,
                       Patch_Color_Angle1, Patch_Color_Angle2, Patch_Color_Angle3, Patch_Color_Angle4, Patch_Color_Angle5, Patch_Color_Angle6, all_patch_colors,
                       leave_center_RT, started_outof_center, too_fast_trigger, too_slow_trigger, timeout, tab_away_count, points)
 


# Check of Gestalts using a contiguous item-set check
data$Gestalt = NA
x = data$num_items == 'Six Items' & data$ColorN == 'Four Colors' 
Loc = data %>% select(starts_with('Patch_Location'))
Col = data %>% select(starts_with('Patch_Color_Angle'))
isoCheck = 0

for (rows in 1:nrow(data)){
  if (data$num_items[rows] == 'Six Items' & data$ColorN[rows] == 'Four Colors'){
    N = c(1,2,4,6)[as.integer(data$num_items[rows])]
    C = Col[rows,order( as.vector(t( Loc[rows,] )) )]
    Ang = as.integer( names( sort(table(t(C)), decreasing = T)[1] ) )
    Pos = order( C == Ang, decreasing = T )[1:3]
    
    if ( all(Pos %in% c(1,3,5)) || all(Pos %in% c(2,4,6)) ){
      data$Gestalt[rows] = 'Eq.Triangle'
      #print( c( as.character(Pos), 'Eq.Triangle') )
    }
    else if ( all(Pos %in% 1:3 ) || all(Pos %in% 2:4 ) || all(Pos %in% 3:5 ) || all(Pos %in% 4:6 ) || all(Pos %in% c(1,5,6) )  || all(Pos %in% c(1,2,6) ) ) {
      data$Gestalt[rows] = 'Contiguous.Short6'
      #print( c( as.character(Pos), 'Contiguous.Short6') )
    }
    else { 
      data$Gestalt[rows] = 'Iso.Triangle'
      #print( c( as.character(Pos), 'Iso.Triangle') )
      if (isoCheck == 0){
        isoCheck = Pos 
      } else {
        isoCheck = rbind(isoCheck, Pos)
      }
    }
  }
}

# isoCheck    1    2    4
# Pos         2    4    5
# Pos         2    5    6
# Pos         3    5    6
# Pos         1    3    4
# Pos         1    4    5
# Pos         3    4    6
# Pos         1    3    6
# Pos         2    3    5
# Pos         1    2    5
# Pos         1    4    6
# Pos         2    3    6

data$Gestalt[ data$num_items == 'Six Items' & data$ColorN == 'Two Colors'  ] = 'Contiguous.Long'
data$Gestalt[ data$num_items == 'Four Items' & data$ColorN == 'Two Colors'  ] = 'Contiguous.Short4'

data$Gestalt = factor(data$Gestalt, 
                      levels = c("Eq.Triangle","Iso.Triangle","Contiguous.Short6", "Contiguous.Long", "Contiguous.Short4") )



# Save preprocessed data as RData files
preprocessed = list(data = data, v = v, demo = demo)
save(preprocessed, file = 'preprocessed.RData')
write.csv(data, 'DazPreprocessed.csv', row.names = FALSE)