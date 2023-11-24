#!/bin/bash

maxVolume=95
defaultSink=$(pactl get-default-sink)
currentVolume=$(pactl get-sink-volume "$defaultSink" | grep -Eio '[0-9]*%' | head -n 1 | grep -Eio '[0-9]*')

if [[ $currentVolume -le $maxVolume ]]
then
	pactl set-sink-volume "$defaultSink" +5%
fi

if [[ $currentVolume -g $maxVolume ]]
then
	pactl set-sink-volume "$defaultSink" 100%
fi
