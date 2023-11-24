#!/bin/bash

# check if script is ready to be run
####################################

# check root status
currentUser=$(whoami)
if [ "$currentUser" == root ]
then
	printf "\e[1;31m\nYou should not run this script as the root user\n\e[0m"
	exit
fi

# get username
userName=$(whoami)

# exit if not inside the arch repo
currentDirectory=$(pwd)
if [ "$currentDirectory" != /home/"$userName"/arch ]
then
	printf "\e[1;31m\nYou must run this script from /home/"$userName"/arch\n\e[0m"
	exit
fi










# set git branch to main
########################

git config --global init.defaultbranch main










# get git credentials if needed
###############################

while true
do
git config --global --list
read -rp $'\n'"Is the git username and email correct? [Y/n] " gitCredentials
	gitCredentials=${gitCredentials:-Y}
	if [ "$gitCredentials" == Y ] || [ "$gitCredentials" == y ] || [ "$gitCredentials" == yes ] || [ "$gitCredentials" == YES ] || [ "$gitCredentials" == Yes ]
	then
		gitCredentials=true
		read -rp $'\n'"Are you sure the git credentials are correct? [Y/n] " gitcredentialsConfirm
		gitcredentialsConfirm=${gitcredentialsConfirm:-Y}
		case $gitcredentialsConfirm in
			[yY][eE][sS]|[yY]) break;;
			[nN][oO]|[nN]);;
			*);;
		esac
		REPLY=
	else
		gitCredentials=false
		read -rp $'\n'"Are you sure the git credentials are NOT correct? [Y/n] " gitcredentialsConfirm
		gitcredentialsConfirm=${gitcredentialsConfirm:-Y}
		case $gitcredentialsConfirm in
			[yY][eE][sS]|[yY]) break;;
			[nN][oO]|[nN]);;
			*);;
		esac
		REPLY=
	fi
done










# set git credentials if needed
###############################

if [ "$gitCredentials" == false ]
then
	# get username
	while true
	do
	read -rp $'\n'"Enter git username: " gituserName
		if [ -z "$gituserName" ]
		then
			echo -e "\nYou must enter a username\n"
		else
			read -rp $'\n'"Are you sure \"$gituserName\" is your git username? [Y/n] " gitusernameConfirm
			gitusernameConfirm=${gitusernameConfirm:-Y}
			case $gitusernameConfirm in
				[yY][eE][sS]|[yY]) break;;
				[nN][oO]|[nN]);;
				*);;
			esac
			REPLY=
		fi
	done

	# get user email
	while true
	do
	read -rp $'\n'"Enter git email for username \"$gituserName\": " gitEmail
		if [ -z "$gitEmail" ]
		then
			echo -e "\nYou must enter an email\n"
		else
			read -rp $'\n'"Are you sure \"$gitEmail\" is your git email? [Y/n] " gitemailConfirm
			gitemailConfirm=${gitemailConfirm:-Y}
			case $gitemailConfirm in
				[yY][eE][sS]|[yY]) break;;
				[nN][oO]|[nN]);;
				*);;
			esac
			REPLY=
		fi
	done
    
    
	# set git credentials
	git config --global user.name "$gituserName"
	git config --global user.email "$gitEmail"
    
fi










# automatically get git repo URL
################################

repoURL=$(grep -i 'url' /home/"$userName"/arch/.git/config | grep -Eo '[[:graph:]]*$')










# copy all needed dotfiles to the local repo
############################################

# alacritty
cp -r /home/"$userName"/.config/alacritty /home/"$userName"/arch/files/dotfiles


# albert
#cp /home/"$userName"/.config/albert.conf /home/"$userName"/arch/files/dotfiles/albert
#cp /home/"$userName"/.config/albert/websearch/engines.json /home/"$userName"/arch/files/dotfiles/albert
#cp -r /home/"$userName"/.config/albert/websearch/icons /home/"$userName"/arch/files/dotfiles/albert


# bash
cp /home/"$userName"/.bash_profile /home/"$userName"/arch/files/dotfiles/bash
cp /home/"$userName"/.bashrc /home/"$userName"/arch/files/dotfiles/bash


# cava
cp -r /home/"$userName"/.config/cava /home/"$userName"/arch/files/dotfiles


# dark-theme
cp -r /home/"$userName"/.config/dark-theme /home/"$userName"/arch/files/dotfiles


# default-apps
cp /home/"$userName"/.config/mimeapps.list /home/"$userName"/arch/files/dotfiles/default-apps


# electron
cp /home/"$userName"/.config/electron[0-9]* /home/"$userName"/arch/files/dotfiles/electron


# fuzzel
cp -r /home/"$userName"/.config/fuzzel /home/"$userName"/arch/files/dotfiles


# gammastep
cp -r /home/"$userName"/.config/gammastep /home/"$userName"/arch/files/dotfiles


# info
cp /home/"$userName"/.infokey /home/"$userName"/arch/files/dotfiles/infokey


# mako
cp -r /home/"$userName"/.config/mako /home/"$userName"/arch/files/dotfiles


# mpv
cp -r /home/"$userName"/.config/mpv /home/"$userName"/arch/files/dotfiles


# neofetch
cp -r /home/"$userName"/.config/neofetch /home/"$userName"/arch/files/dotfiles


# nvim
cp -r /home/"$userName"/.config/nvim /home/"$userName"/arch/files/dotfiles


# sway
cp -r /home/"$userName"/.config/sway /home/"$userName"/arch/files/dotfiles


# swaylock
cp -r /home/"$userName"/.config/swaylock /home/"$userName"/arch/files/dotfiles


# tealdeer
cp -r /home/"$userName"/.config/tealdeer /home/"$userName"/arch/files/dotfiles


# wallpapers
cp -r /home/"$userName"/.config/wallpapers /home/"$userName"/arch/files/dotfiles


# waybar
cp -r /home/"$userName"/.config/waybar /home/"$userName"/arch/files/dotfiles


# zathura
cp -r /home/"$userName"/.config/zathura /home/"$userName"/arch/files/dotfiles










# push to online git repo
#########################

# re-initialize the repo
git init
git remote add origin "$repoURL"
git remote -v


# add all files to online git repo and commit changes
git add --all
git commit -am "Initial commit"


# force update to master branch of online git repo
printf "\e[1;32m\nEnter PAT instead of password\n\e[0m"
git push -f origin main
