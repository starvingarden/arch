#!/bin/bash

# This is a script that sets a user-defined app as the default for specific mime types.
# Run this script by appending "app.desktop" to the command.

defaultApp=$1

# get list of supported mime types for $defaultApp
mimetypeList=$(grep -E '^MimeType=' /usr/share/applications/"$defaultApp" | sed 's/MimeType=//g')


# create $mimeTypes array from $mimetypeList using ";" as the separator
IFS=';' read -ra mimeTypes <<< "$mimetypeList"


# set $defaultApp to open each file type specified in the $mimeTypes array
for element in "${mimeTypes[@]}"; do
	xdg-mime default "$defaultApp" "$element"
done
