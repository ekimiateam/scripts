#!/bin/bash

wget https://raw.githubusercontent.com/tuxedocomputers/tuxedo.sh/master/keys/ubuntu.pub

sudo apt-key add ubuntu.pub


echo "deb http://deb.tuxedocomputers.com/ubuntu $(lsb_release -cs) main" |sudo tee -a /etc/apt/sources.list.d/tuxedo-computers.list

sudo apt update

sudo apt install -y tuxedo-control-center
