#!/bin/bash

# run this script by appending either "dark" or "light" to the command

# this script switches the entire system to dark or light theme

# see arch wiki pages "Dark mode switching", "GTK#Themes", and "Qt#Configuration")



theme=$1



currentTheme=$(gsettings get org.gnome.desktop.interface color-scheme)
if [ "$currentTheme" == "'prefer-light'" ]
then
    currentTheme=light
elif [ "$currentTheme" == "'prefer-dark'" ]
then
    currentTheme=dark
elif [ "$currentTheme" == "'default'" ]
then
    currentTheme=light
fi



# switch to desired theme if desired theme is not already set

# dark theme
if [ "$theme" == dark ] && [ "$currentTheme" == light ]
then
    # set fuzzel dark theme
    fuzzel-theme.sh dark

    # set gtk dark theme
    gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    export GTK2_RC_FILES=/usr/share/themes/Adwaita-dark/gtk-2.0/gtkrc
    sed -i 's|export GTK2_RC_FILES=/usr/share/themes/Adwaita/gtk-2.0/gtkrc|export GTK2_RC_FILES=/usr/share/themes/Adwaita-dark/gtk-2.0/gtkrc|' ~/.bashrc

    # set qt dark theme
    export QT_STYLE_OVERRIDE=adwaita-dark
    sed -i 's/export QT_STYLE_OVERRIDE=adwaita/export QT_STYLE_OVERRIDE=adwaita-dark/' ~/.bashrc

    # confirmation
    echo -e "\nDark theme set\n"
fi

# light theme
if [ "$theme" == light ] && [ "$currentTheme" == dark ]
then
    # quit brave then set brave light theme
    #swaymsg [app_id="brave-browser"] kill > /dev/null 2>&1
    #sleep 1
    #sed -i 's/"enabled_labs_experiments":\["enable-force-dark@6",/"enabled_labs_experiments":\[/' ~/.config/BraveSoftware/Brave-Browser/'Local State'

    # set fuzzel light theme
    fuzzel-theme.sh light

    # set gtk light theme
    #gsettings reset-recursively org.gnome.desktop.interface
    #rm ~/.gtkrc-2.0
    #rm ~/.config/gtk-3.0/settings.ini
    gsettings set org.gnome.desktop.interface gtk-theme Adwaita
    gsettings set org.gnome.desktop.interface color-scheme prefer-light
    export GTK2_RC_FILES=/usr/share/themes/Adwait/gtk-2.0/gtkrc
    sed -i 's|export GTK2_RC_FILES=/usr/share/themes/Adwaita-dark/gtk-2.0/gtkrc|export GTK2_RC_FILES=/usr/share/themes/Adwaita/gtk-2.0/gtkrc|' ~/.bashrc

    # set qt light theme
    export QT_STYLE_OVERRIDE=adwaita
    sed -i 's/export QT_STYLE_OVERRIDE=adwaita-dark/export QT_STYLE_OVERRIDE=adwaita/' ~/.bashrc

    # confirmation
    echo -e "\nLight theme set\n"
fi  
