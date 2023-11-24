#!/bin/bash

# get current brightness
currentBrightness=$(light)

# set adjust amount
adjustAmount=$(qalc "$currentBrightness"/10 | grep -Eio '[[:graph:]]+$')

# check to see if adjust amount is less than 1
minadjustBoolean=$(echo -e "$adjustAmount < 1" | bc)
if [ "$minadjustBoolean" == 1 ]
then
	adjustAmount=1
fi

# get new brightness level
newBrightness=$(qalc "$currentBrightness"+"$adjustAmount" | grep -Eio '[[:graph:]]+$')

# set new brightness level
light -S "$newBrightness"
