#/bin/bash

#Copyright Ekimia 2020 

#List of USB ID of disk to receive data 

# SYnc ALL 

#disk1=0FF6-072F
disk2=7E90-3EC9
disk3=1CE3-3215

disk1=85B4-3D98

#Detect what disk is connected
blkline=$(blkid |grep $disk1)
echo $blkline
#Testing if blkline is empty 
if test -z "$blkline"
then
    echo "Disque 1 is not connected"
else 
   echo "Disque 1 is connected ,finding device ..."
   device=$(echo $blkline | cut -c 1-9)
   echo "Disque 1 is connected on $device"
   mountline=$(mount |grep $device)
   echo $mountline
   if test -z "$mountline"
   then 
    echo " Disque 1 is not mounted "
   else 
    echo " Disque 1 is  mounted  on ...."
   fi 
fi


#Start Rsync on disque 1

#rsync -rt --stats /home/. /media/sdd/ > /root/syncusb.txt
