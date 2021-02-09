#/bin/bash

#Copyright Ekimia 2020 

#List of USB ID of disk to receive data 

# SYnc ALL 

disk1=0FF6-072F
disk2=7E90-3EC9
disk3=1CE3-3215

#Detect what disk is connected




#Start Rsync

rsync -rt --stats /home/. /media/sdd/ > /root/syncusb.txt
