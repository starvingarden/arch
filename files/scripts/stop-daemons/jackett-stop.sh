#!/bin/bash

while true
do
    # is qBittorrent running?
    qbittorrentRunning=$(swaymsg -t get_tree | grep -io 'qbittorrent')

    # if qbittorrent is not running, stop the jackett daemon and exit, if qbittorrent is running, wait then check again
    if [ -z "$qbittorrentRunning" ]
    then
        sudo systemctl stop jackett.service
        break
    else
        sleep 60
    fi
done
