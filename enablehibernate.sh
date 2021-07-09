#/bin/bash
# Ekimia.fr 2021 
# Enables Hibernation with swap file with menus on Ubuntu 20.04


echo " starting enabling hibernate "



# install needed packages 

sudo apt -y install uswsusp


# Compute ideal size of swap ( Memesize * 1.5 ) 
swapfilesize=$(echo "$(cat /proc/meminfo | grep MemTotal | grep -oh '[0-9]*') * 1.5" |bc -l | awk '{print int($1)}')
echo "swapfilesize will be $swapfilesize bytes"
swapfileoffset=1


# Get UUID & swap_offset 

rootuuid=$((sudo findmnt -no SOURCE,UUID -T /swapfile) |cut -d\  -f 2) 

echo rootuuid = $rootuuid

# Modify initramfs 



# Update initramfs 

#sudo update-initramfs -k all -u


# update polkit 


# 
