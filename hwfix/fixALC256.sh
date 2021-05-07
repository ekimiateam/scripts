#!/bin/bash

#This should fix ALC256 alsa codec on Ubuntu 20.04.2 and similar

echo " Ekimia - Fix ALC256"

echo " creating a new modprobe file /etc/modprobe.d/fix-ALC256.conf"

echo "options snd-hda-intel model=dell-headset-multi" | sudo tee -a /etc/modprobe.d/fix-ALC256.conf

echo " file created - press a key "

read p 
