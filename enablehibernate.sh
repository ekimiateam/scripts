#/bin/bash
# Ekimia.fr 2021 
# Enables Hibernation with swap file with menus on Ubuntu 20.04


echo " starting enabling hibernate "

#CHange this value to size the swapfile X times your ram
swapfilefactor=1.5

# install needed packages 

sudo apt -y install uswsusp pm-utils hibernate


# Compute ideal size of swap ( Memesize * 1.5 ) 
swapfilesize=$(echo "$(cat /proc/meminfo | grep MemTotal | grep -oh '[0-9]*') * $swapfilefactor" |bc -l | awk '{print int($1)}')
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


sudo tee /etc/polkit-1/localauthority/10-vendor.d/com.ubuntu.desktop.pkla <<EOF
[Enable hibernate in upower] 
Identity=unix-user:* 
Action=org.freedesktop.upower.hibernate 
ResultActive=yes 

[Enable hibernate in logind]
Identity=unix-user:* 
Action=org.freedesktop.login1.hibernate;org.freedesktop.login1.handle-hibernate-key;org.freedesktop.login1;org.freedesktop.login1.hibernate-multiple-sessions;org.freedesktop.login1.hibernate-ignore-inhibit
ResultActive=yes"
EOF > /dev/null

# 
