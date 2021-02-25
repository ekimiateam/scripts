#!/bin/bash

wget https://raw.githubusercontent.com/tuxedocomputers/tuxedo.sh/master/keys/ubuntu.pub

sudo apt-key add ubuntu.pub


echo "deb http://deb.tuxedocomputers.com/ubuntu focal main" |sudo tee -a /etc/apt/sources.list.d/tuxedo-computers.list

sudo apt update

sudo apt install tuxedo-control-center