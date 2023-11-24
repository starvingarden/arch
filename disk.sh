#!/bin/bash


# get disks to use
while true
do
	echo -e "\n\n"
	#printf "\e[1;32m\nSelect disk(s) to use:\n\e[0m" && echo -e ""

	# create an empty array for available disk(s)
	available_disks=()

	# create an empty array for selected disk numbers
	selected_disk_numbers=()

	# create an empty array for selected disk(s) long
	selected_disks_long=()

	# create an empty array for selected disk path(s)
	selected_disks=()

	# add every available disk to the $available_disks array, using newline as the separator for elements in the array
	IFS=$'\n' read -d '' -ra available_disks < <(lsblk -o PATH,SIZE,MODEL,TYPE | grep -i disk)

	# display each element in the $available_disks array preceeded by its index in the array
	for element in "${!available_disks[@]}"
	do
		echo "$element. ${available_disks[$element]}"
	done

	# prompt the user to select desired disk(s) and add them to the selected_disk_numbers variable
	read -rp $'\n'"Enter the number(s) for the disk(s) you want to use (separated by spaces): " selected_disk_numbers

	# convert the space separated string to an array
	selected_disk_numbers=($selected_disk_numbers)

	# check that the same disk wasn't selected more than once by comparing each disk to other disks
	duplicateDisks=false
	for i in "${!selected_disk_numbers[@]}"
	do
		for j in "${!selected_disk_numbers[@]}"
		do
			# skip if comparing a disk with itself
			if [ "$i" -eq "$j" ]
			then
				continue
			fi

			# compare disks
			if [ "${selected_disk_numbers[i]}" = "${selected_disk_numbers[j]}" ]
			then
				# if there are duplicate disks, display an error and set a variable to start over when disks are checked for validation
				printf "\e[1;31m\n\n\nDisk $element was selected more than once, try again\n\e[0m"
				duplicateDisks=true
				break 2  # if duplicate disks are found, exit both for loops and start over selecting disks
			fi
		done
	done

	# loop through the $selected_disk_numbers array and add the disk(s) to the $selected_disks_long array if they are within the appropriate range
	disks_in_range=true
	for element in "${selected_disk_numbers[@]}"
	do
		if [[ $element -ge 0 && $element -lt ${#available_disks[@]} ]]
		then
			selected_disks_long+=("${available_disks[$element]}")
		else
			# if a selected disk number is out of range, display an error and set a variable to start over when disks are checked for validation
			printf "\e[1;31m\n\n\nInvalid disk number: $element, try again\n\e[0m"
			disks_in_range=false
		fi
	done

	# prompt user to validate selected disks
	# prompt user to confirm disks if selected_disks_long array contains appropriate elements, else start over
	if [[ ${#selected_disks_long[@]} -gt 0 && "$duplicateDisks" == false && "$disks_in_range" == true ]]
	then
		while true
		do
			# show selected disk(s)
			echo -e "\n\n\nSelected disk(s):\n"
			for element in "${!selected_disks_long[@]}"
			do
				echo "$element. ${selected_disks_long[$element]}"
			done

			# prompt user to confirm selected disk(s)
			read -rp $'\n'"Are the selected disk(s) correct? [Y/n] " diskConfirm
			diskConfirm=${diskConfirm:-Y}
			case $diskConfirm in
				[yY][eE][sS]|[yY])
					read -rp $'\n'"Are you sure the selected disk(s) are correct? [Y/n] " diskConfirm2
					diskConfirm2=${diskConfirm2:-Y}
					case $diskConfirm2 in
						[yY][eE][sS]|[yY])
							break 2;; # if disk(s) are confirmed, exit both while loops to continue
						[nN][oO]|[nN])
							break;; # if disk(s) are not confirmed, exit current while loop to start over selecting disk(s)
						*);;
					esac
					;;
				[nN][oO]|[nN])
					break;; # if disk(s) are not confirmed, exit current while loop and start over selecting disk(s)
				*);;
			esac   
		done
	fi
done

# loop through the selected_disks_long array and add only the disk paths to the selected_disks array
for element in "${!selected_disks_long[@]}"
do
	selected_disks+=("$(echo "${selected_disks_long[$element]}" | grep -Eo '^[[:graph:]]*')")
done
# elements in the $selected_disks array should be of the form "/dev/sda" or "/dev/nvme0n1"



# should raid be used for the operating system?
# if the user has selected multiple disks, should raid be used for the os?
if [ "${#selected_disks[@]}" -eq 1 ]
then
	osRaid=false
fi
if [ "${#selected_disks[@]}" -gt 1 ]
then
	while true
	do
		echo -e "\n"
		read -rp $'\n'"Would you like to use RAID for the operating system? [Y/n] " osRaid
		osRaid=${osRaid:-Y}
		case $osRaid in
			[yY][eE][sS]|[yY])
				read -rp $'\n'"Are you sure you want to use RAID for the operating system? [Y/n] " osraidConfirm
				osraidConfirm=${osraidConfirm:-Y}
				case $osraidConfirm in
					[yY][eE][sS]|[yY])
						osRaid=true
						break;; # exit current while loop to continue
					[nN][oO]|[nN])
						continue;; # start over deciding if RAID should be used for the operating system
					*);;
				esac
				;;
			[nN][oO]|[nN])
				read -rp $'\n'"Are you sure you do NOT want to use RAID for the operating system? [Y/n] " osraidConfirm
				osraidConfirm=${osraidConfirm:-Y}
				case $osraidConfirm in
					[yY][eE][sS]|[yY])
						osRaid=false
						break;; # exit current while loop to continue
					[nN][oO]|[nN])
						continue;; # start over deciding if RAID should be used for the operating system
					*);;
				esac
				;;
			*);;
		esac
	done
fi



# should raid be used for bulk storage?
# get bulkRaid only if numDisks>3, or if numDisks=3 and osRaid=false
if [ "${#selected_disks[@]}" -gt 3 ] || ([ "${#selected_disks[@]}" -eq 3 ] && [ "$osRaid" == false ]) 
then
	while true
	do
		echo -e "\n"
		read -rp $'\n'"Would you like to use RAID for bulk storage? [Y/n] " bulkRaid
		bulkRaid=${bulkRaid:-Y}
		case $bulkRaid in
			[yY][eE][sS]|[yY])
				read -rp $'\n'"Are you sure you want to use RAID for bulk storage? [Y/n] " bulkraidConfirm
				bulkraidConfirm=${bulkraidConfirm:-Y}
				case $bulkraidConfirm in
					[yY][eE][sS]|[yY])
						bulkRaid=true
						break;; # exit current while loop to continue
					[nN][oO]|[nN])
						continue;; # start over deciding if RAID should be used for bulk storage
					*);;
				esac
				;;
			[nN][oO]|[nN])
				read -rp $'\n'"Are you sure you do NOT want to use RAID for bulk storage? [Y/n] " bulkraidConfirm
				bulkraidConfirm=${bulkraidConfirm:-Y}
				case $bulkraidConfirm in
					[yY][eE][sS]|[yY])
						bulkRaid=false
						break;; # exit current while loop to continue
					[nN][oO]|[nN])
						continue;; # start over deciding if RAID should be used for bulk storage
					*);;
				esac
				;;
			*);;
		esac
	done
else
	bulkRaid=false
fi















# get disk(s) to be used for the operating system

##########################################################
# only set $os_disks array 1 time after everything is done
##########################################################

while true
do
	echo -e "\n\n"

	# create an empty array for os disk numbers
	os_disk_numbers=()

	# create an empty array for os disks long
	os_disks_long=()

	# create an empty array os disk path(s)
	os_disks=()







	# if using one disk, add the path for the only disk in the $selected_disks array to the $os_disks array
	if [ "${#selected_disks[@]}" -eq 1 ]
	then
		os_disks+=("${selected_disks[0]}")
	fi
	# elements in the $os_disks array should be of the form "/dev/sda" or "/dev/nvme0n1"
	



	# if using 2 disks with os raid, add the only 2 disks in the $selected_disks array to the $os_disks array
	if [ "${#selected_disks[@]}" -eq 2 ] && [ "$osRaid" == true ]
	then
		# loop through the $selected_disks array and add all elements to the $osdiskNames array
		for element in "${!selected_disks[@]}"; do
			os_disks+=("$(echo "${selected_disks[$element]}" | grep -Eo '^[[:graph:]]*')")
		done
	fi
	# elements in the $os_disks array should be in the form of "/dev/sda" or "/dev/nvme0n1"








# if using multiple disks without os raid, then set 1 element in $os_disks_long to a single user selected disk from the $selected_disks_long array
if [ "${#selected_disks[@]}" -gt 1 ] && [ "$osRaid" == false ]
then
	echo -e "\n\n"

	# display each element in the $selected_disks_long array preceeded by its index in the array
	for element in "${!selected_disks_long[@]}"
	do
		echo "$element. ${selected_disks_long[$element]}"
	done

	# prompt the user to select the desired disk to use for the operating system and add it to the os_disk_numbers variable
	read -rp $'\n'"Enter the number for the disk you want to use for the operating system: " os_disk_numbers

	# convert the $os_disk_numbers string to an array
	os_disk_numbers=($os_disk_numbers)

	# check that there is only 1 element in the $os_disk_numbers array
	if [ "${#os_disk_numbers[@]}" -eq 1 ]
	then
		continue
	else
		printf "\e[1;31m\n\n\nYou must select 1 disk, try again\n\e[0m"
		break # start over selecting disks
	fi

	# loop through the $os_disk_numbers array and add the disk to the $os_disks_long array if it is within the appropriate range
	disks_in_range=true
	for element in "${os_disk_numbers[@]}"
	do
		if [[ $element -ge 0 && $element -lt ${#available_disks[@]} ]]
		then
			os_disks_long+=("${selected_disks[$element]}")   ############### this may be problematic
		else
			# if a selected os disk number is out of range, display an error and set a variable to start over when os disks are checked for validation
			printf "\e[1;31m\n\n\nInvalid disk number: $element, try again\n\e[0m"
			disks_in_range=false
		fi
	done

	# prompt user to validate os disks
	# prompt user to confirm os disks if os_disks_long array contains appropriate elements, else start over
	if [[ ${#os_disks_long[@]} -gt 0 && "$disks_in_range" == true ]]
	then
		while true
		do
			# show selected disk(s)
			echo -e "\n\n\nSelected os disk(s):\n"
			for element in "${!os_disks_long[@]}"
			do
				echo "$element. ${os_disks_long[$element]}"
			done

			# prompt user to confirm selected disk(s)
			read -rp $'\n'"Is the selected os disk correct? [Y/n] " diskConfirm
			diskConfirm=${diskConfirm:-Y}
			case $diskConfirm in
				[yY][eE][sS]|[yY])
					read -rp $'\n'"Are you sure the selected os disk is correct? [Y/n] " diskConfirm2
					diskConfirm2=${diskConfirm2:-Y}
					case $diskConfirm2 in
						[yY][eE][sS]|[yY])
							break 2;; # if disk(s) are confirmed, exit both while loops to continue
						[nN][oO]|[nN])
							break;; # if disk(s) are not confirmed, exit current while loop to start over selecting os disk(s)
						*);;
					esac
					;;
				[nN][oO]|[nN])
					break;; # if the os disk is not confirmed, exit current while loop and start over selecting an os disk
				*);;
			esac   
		done
	fi

	# loop through the $os_disks_long array and add only the disk paths to the $os_disks array
	for element in "${!os_disks_long[@]}"
	do
		os_disks+=("$(echo "${os_disks_long[$element]}" | grep -Eo '^[[:graph:]]*')")
	done
	# elements in the $os_disks array should be of the form "/dev/sda" or "/dev/nvme0n1"
fi





# if using more than 2 disks with os raid, set elements in the $os_disks_long array to 2 user selected disks from the $selected_disks_long array
if [ "${#selected_disks[@]}" -gt 2 ] && [ "$osRaid" == true ]
then
	echo -e "\n\n"

	# display each element in the $selected_disks_long array preceeded by its index in the array
	for element in "${!selected_disks_long[@]}"
	do
		echo "$element. ${selected_disks_long[$element]}"
	done

	# prompt the user to select the desired disk to use for the operating system and add it to the os_disk_numbers variable
	read -rp $'\n'"Enter the number for the disk you want to use for the operating system: " os_disk_numbers

	# convert the $os_disk_numbers string to an array
	os_disk_numbers=($os_disk_numbers)

	# check that there are 2 elements in the $os_disk_numbers array
	if [ "${#os_disk_numbers[@]}" -eq 2 ]
	then
		continue
	else
		printf "\e[1;31m\n\n\nYou must select 2 disks, try again\n\e[0m"
		break # start over selecting disks
	fi



	# check that the same disk wasn't selected more than once by comparing each disk to other disks
	duplicateDisks=false
	for i in "${!os_disk_numbers[@]}"
	do
		for j in "${!os_disk_numbers[@]}"
		do
			# skip if comparing a disk with itself
			if [ "$i" -eq "$j" ]
			then
				continue
			fi

			# compare disks
			if [ "${os_disk_numbers[i]}" = "${os_disk_numbers[j]}" ]
			then
				# if there are duplicate disks, display an error and set a variable to start over when disks are checked for validation
				printf "\e[1;31m\n\n\nDisk $element was selected more than once, try again\n\e[0m"
				duplicateDisks=true
				break 2  # if duplicate os disks are found, exit both for loops and start over selecting os disks
			fi
		done
	done



	# loop through the $os_disk_numbers array and add the disk to the $os_disks_long array if it is within the appropriate range
	disks_in_range=true
	for element in "${os_disk_numbers[@]}"
	do
		if [[ $element -ge 0 && $element -lt ${#available_disks[@]} ]]
		then
			os_disks_long+=("${selected_disks[$element]}")   ############### this may be problematic
		else
			# if a selected os disk number is out of range, display an error and set a variable to start over when os disks are checked for validation
			printf "\e[1;31m\n\n\nInvalid disk number: $element, try again\n\e[0m"
			disks_in_range=false
		fi
	done

	# prompt user to validate os disks
	# prompt user to confirm os disks if os_disks_long array contains appropriate elements, else start over
	if [[ ${#os_disks_long[@]} -gt 0 && "$duplicateDisks" == false && "$disks_in_range" == true ]]
	then
		while true
		do
			# show selected disk(s)
			echo -e "\n\n\nSelected os disk(s):\n"
			for element in "${!os_disks_long[@]}"
			do
				echo "$element. ${os_disks_long[$element]}"
			done

			# prompt user to confirm selected disk(s)
			read -rp $'\n'"Is the selected os disk correct? [Y/n] " diskConfirm
			diskConfirm=${diskConfirm:-Y}
			case $diskConfirm in
				[yY][eE][sS]|[yY])
					read -rp $'\n'"Are you sure the selected os disk is correct? [Y/n] " diskConfirm2
					diskConfirm2=${diskConfirm2:-Y}
					case $diskConfirm2 in
						[yY][eE][sS]|[yY])
							break 2;; # if disk(s) are confirmed, exit both while loops to continue
						[nN][oO]|[nN])
							break;; # if disk(s) are not confirmed, exit current while loop to start over selecting os disk(s)
						*);;
					esac
					;;
				[nN][oO]|[nN])
					break;; # if the os disk is not confirmed, exit current while loop and start over selecting an os disk
				*);;
			esac   
		done
	fi

	# loop through the $os_disks_long array and add only the disk paths to the $os_disks array
	for element in "${!os_disks_long[@]}"
	do
		os_disks+=("$(echo "${os_disks_long[$element]}" | grep -Eo '^[[:graph:]]*')")
	done
	# elements in the $os_disks array should be of the form "/dev/sda" or "/dev/nvme0n1"
fi

done









# print os disks array
echo -e "os disks:"
for element in "${os_disks[@]}"
do
	echo -e "$element"
done
