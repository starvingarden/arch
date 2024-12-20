# Description

- This is a bash script that installs Arch Linux in UEFI mode automatically.
- Read the "Details" section below for important information on how the system will be configured.
- Read the "Usage" section below for important information on how to run the script.

# Details

- The installation will remove all data on the disk(s) selected by the user. Installation includes a 1GB FAT32 efi boot partition, and a btrfs root partition that takes up the rest of the disk. This includes subvolumes @ mounted at /, @snapshots mounted at /.snapshots, @home mounted at /home, and @var_log mounted at /var/log
- The installation comes with some helpful scripts, more will be located at /usr/local/bin and ~/.bin after installation
    - rollback.sh
        - gets user input and rolls back to a previous snapshot
    - eject.sh
        - unmounts and powers off any removable storage
    - dotfiles.sh
        - saves necessary dotfiles and pushes them to the online git repo
        - must be run from inside the arch repo
- The installation includes printing capabilities, bluetooth, automatic recommended system maintenance, and automatic snapshots of / and /home directories.
- The "install.sh" script will ask if you want to include the repo owners custom configurations. For details on what this includes, see the "custom configurations" section in the "config.sh" script

# Usage

After booting into arch linux from a live medium in UEFI mode, run the install script with the following commands
1. `tmux`
    - tmux is a terminal multiplexer, meaning it enables multiple terminals to be created and controlled on the same screen
    - after running the `tmux` command, you can now do a few useful things with your screen by pressing `Ctrl+b` followed by pressing 1 of the following keys
        - `[`: to scroll with the arrow keys, press `q` to exit scrolling mode
        - `%`: to split the tmux terminal into 2 tmux terminals left and right
        - `"`: to split the tmux terminal into 2 tmux terminals top and bottom
        - `o`: to change to a different tmux terminal if there are multiple tmux terminals on screen
        - `x`: to close the current tmux terminal
        - `&`: to quit tmux altogether
        - `?`: to list all tmux keybindings
2. if you need to connect to wifi, run...
    - `iwctl`
    - `device list`
    - `station [device_name] scan`
    - `station [device_name] get-networks`
    - `station [device_name] connect [network_name]`
    - verify you are connected with...
        - `station [device_name] show`
    - `exit`
3. `pacman -Sy git` 
4. `git clone https://github.com/starvingarden/arch`
5. `cd arch`
6. edit the install.sh script with...
    - `nano install.sh` or `vim install.sh`
7. `chmod +x ./install.sh`
8. `./install.sh`
    - Read the input prompts carefully.
    - You can cancel the script at any time with `Ctrl+c`

# To Do

- [x] btrfs filesystem with automatic snapshots, cleanup, and rollback
- [x] full disk encryption
- [x] swap with hibernation capabilities
- [x] optional RAID1 capabilities
- [ ] easy replacing/upgrading of RAID disks
- [ ] will not interfere with operating systems installed on other disks
- [ ] get disk serial number with lsblk -o name,serial (user should use this to physically label cable/disks osdisk0, etc.)
- [ ] use persistent block device naming for initramfs and grub configuration
- [ ] run a script every so often to check battery level and charging status and hibernate if necessary
- [ ] make a "variables" file for user to manually enter variables into, instead of editing the install.sh file, edit the variables.txt file
- [ ] add scripts to PATH in /etc/profile
- [ ] change directory name /.snapshots/backups to /.snapshots/tmp??
- [ ] utilize nix package manager
