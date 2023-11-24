#!/bin/bash

# this script modifies the file old_config_file
# it works by adding all lines before and containing start_marker to ~/temp_file, adding the contents of new_config_file to ~/temp_file, adding all lines containing and after end_marker to ~/temp_file, then replacing old_config_file with ~/temp_file
# config_directory should be where new_config_file resides

# run this script by appending the desired config file to the command





# check if on desktop or laptop
systemType=$(neofetch battery)
if [ -z "$systemType" ]
then
    systemType=desktop
else
    systemType=laptop
fi





# variables
config_directory=~/.config/sway/"$systemType"
old_config_file=~/.config/sway/config
new_config_file=$1

start_marker="# Device Configuration Start"
end_marker="# Device Configuration End"





# check if new_config_file exists
file_exists=$(ls "$config_directory" | grep -Eo "^$new_config_file$")
if [ -z "$file_exists" ]
then
    printf "\e[1;31mInvalid option. Try another one\n\e[0m"
    sleep 2
    exit
fi





# save lines in old_config_file before start_marker and containing start_marker to ~/temp_file
##############################################################################################

# get the line number in old_config_file that contains start_marker
line_number=$(grep -n "$start_marker" "$old_config_file" | head -n 1 | grep -Eo '^[0-9]*')

# save lines in old_config_file before start_marker and lines containing start_marker to ~/temp_file 
head -n +"$line_number" "$old_config_file" >> ~/temp_file





# save contents of new_config_file to ~/temp_file
#################################################

cat "$config_directory"/"$new_config_file" >> ~/temp_file





# save lines in old_config_file containing end_marker and after end_marker to temp_file
#######################################################################################

# get the line number in old_config_file that contains end_marker
line_number=$(grep -n "$end_marker" "$old_config_file" | head -n 1 | grep -Eo '^[0-9]*')

# save lines in old_config_file containing end_marker and lines after end_marker to a temp file 
tail -n +"$line_number" "$old_config_file" >> ~/temp_file





# replace old_config_file file with temp_file
#############################################

mv ~/temp_file "$old_config_file"





# reload the sway config file
#############################

swaymsg reload
