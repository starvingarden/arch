#!/bin/bash

while true
do
    # is virt-manager running?
    virtmanagerRunning=$(swaymsg -t get_tree | grep -io 'virt-manager')

    # if virt-manager is not running, stop the libvirt daemon and exit, if virt-manager is running, wait then check again
    if [ -z "$virtmanagerRunning" ]
    then
        sudo systemctl stop libvirtd.service
        break
    else
        sleep 60
    fi
done
