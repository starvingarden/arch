#!/bin/bash

# run this script by appending "on", "off", or "now" to the command

# this script can toggle swayidle on or off, or it can make the system go to sleep immediately



sleepMode=$1



# turn swayidle on
if [ "$sleepMode" == on ]
then
	swaymsg reload
fi


# turn swayidle off
if [ "$sleepMode" == off ]
then
	pkill swayidle
fi


# sleep immediately
if [ "$sleepMode" == now ]
then
    swaylock
	systemctl suspend-then-hibernate
fi
