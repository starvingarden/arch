#!/bin/bash

# run this script by appending "connect", "disconnect", "reconnect", "status", or "location" to the command



action=$1



# disconnect from vpn
if [ "$action" == disconnect ] || [ "$action" == reconnect ]
then
    # dont always require vpn
    mullvad lockdown-mode set off

    # dont automatically connect to vpn
    mullvad auto-connect set off

    # disconnect from vpn
    mullvad disconnect

    # stop daemon
    systemctl stop mullvad-daemon.service
fi



# connect to vpn
if [ "$action" == connect ] || [ "$action" == reconnect ]
then

    # start daemon
    systemctl start mullvad-daemon.service

    # set the protocol to wireguard
    mullvad relay set tunnel-protocol wireguard

    # configure obfuscation
    #mullvad obfuscation set mode udp2tcp
    mullvad obfuscation set mode auto

    # enable LAN access
    mullvad lan set allow
    
    # block ads, trackers, and malware
    mullvad dns set default --block-ads --block-malware --block-trackers
    
    # set auto-connect
    mullvad auto-connect set on
    
    # connect to vpn
    mullvad connect
    
    # always require vpn
    mullvad lockdown-mode set on
fi



# check vpn status
if [ "$action" == status ]
then
    mullvad status -v
fi



# print error if $action is blank or invalid
if [ -z "$action" ] || ( [ "$action" != connect ] && [ "$action" != disconnect ] && [ "$action" != reconnect ] && [ "$action" != status ] && [ "$action" != location ] )
then
    printf "\e[1;31mInvalid option. You must append \"connect\", \"disconnect\", \"reconnect\", or \"location\" to the command\n\e[0m"
fi



# change vpn location
if [ "$action" == location ]
then
    # update list of available locations
    mullvad relay update

    # print currently set location and ask user if they want to change
    while true
    do
    mullvadCurrentLocation=$(mullvad relay get)
    read -rp $'\n'"$mullvadCurrentLocation, would you like to switch to a new location? [Y/n] " locationSwitch
        locationSwitch=${locationSwitch:-Y}
        case $locationSwitch in
            [yY][eE][sS]|[yY]) break;;
            [nN][oO]|[nN]) exit;;
            *);;
        esac
        REPLY=
    done

    # select country to connect to
    mapfile -t mullvadCountries < <(mullvad relay list | grep '([a-z][a-z])')
    PS3="Enter the number for the country you want to connect to: "
    select mullvadCountry in "${mullvadCountries[@]}"
    do
        if (( REPLY > 0 && REPLY <= "${#mullvadCountries[@]}" ))
        then
            break
        else
            echo -e "\nInvalid option. Try another one\n"
            sleep 2
            REPLY=
        fi
    done
    mullvadCountry=$(echo -e "$mullvadCountry" | grep -o '(.*)' | grep -Eo '[a-z]*')

    # ask user if they want to specify a city to connect to
    read -rp $'\n'"Would you like to specify a city to connect to? [Y/n] " cityConnect
        cityConnect=${cityConnect:-Y}
    if [ "$cityConnect" == Y ] || [ "$cityConnect" == y ] || [ "$cityConnect" == yes ] || [ "$cityConnect" == YES ] || [ "$cityConnect" == Yes ]
    then
        cityConnect=true
    else
        cityConnect=false
    fi

    # select city to connect to
    if [ "$cityConnect" == true ]
    then
        mapfile -t mullvadCities < <(mullvad relay list | grep '([a-z][a-z][a-z])')
        PS3="Enter the number for the city you want to connect to: "
        select mullvadCity in "${mullvadCities[@]}"
        do
            if (( REPLY > 0 && REPLY <= "${#mullvadCities[@]}" ))
            then
                break
            else
                echo -e "\nInvalid option. Try another one\n"
                sleep 2
                REPLY=
            fi
        done
        mullvadCity=$(echo -e "$mullvadCity" | grep -o '(.*)' | grep -Eo '[a-z]*')
        fi

    # set location to connect to
    if [ "$cityConnect" == true ]
    then
        mullvad relay set location "$mullvadCountry" "$mullvadCity"
    elif [ "$cityConnect" == false ]
    then
        mullvad relay set location "$mullvadCountry"
    fi

    # print new mullvad relay settings
    mullvad relay get
fi
