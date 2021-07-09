#/bin/bash
# Ekimia.fr 2021 
# Enables Hibernation with swap file with menus on Ubuntu 20.04


echo " starting enabling hibernate "



# install needed packages 

sudo apt -y install uswsusp


# Compute ideal size of swap ( Memesize * 1.5 ) 
swapfilesize=$(echo "$(cat /proc/meminfo | grep MemTotal | grep -oh '[0-9]*') * 1.5" |bc -l | awk '{print int($1)}')
echo "swapfilesize will be $swapfilesize bytes"
echo " creating new swapfile"
sudo swapoff /swapfile
sudo dd if=/dev/zero of=/swapfile bs=$swapfilesize count=1024 conv=notrunc
sudo mkswap /swapfile
sudo swapon /swapfile


swapfileoffset=1


# Get UUID & swap_offset 

rootuuid=$((sudo findmnt -no SOURCE,UUID -T /swapfile) |cut -d\  -f 2) 

echo rootuuid = $rootuuid


swapfileoffset=$((sudo swap-offset /swapfile)  |cut -d\  -f 4) 

echo swapfileoffset = $swapfileoffset


# Modify initramfs 

 echo "RESUME=UUID=$rootuuid resume_offset=$swapfileoffset" |sudo tee /etc/initramfs-tools/conf.d/resume

# Update initramfs 

sudo update-initramfs -k all -u


# update polkit 


# 
