#!/bin/bash
# Copyleft
# Make by ekimia.fr 

create_bash_file () {

    cat <<EOF> bash.sh
sudo apt install -y wget coreutils apt-transport-https 
sudo wget -P /etc/apt/keyrings/ https://deb.commown.coop/deb.commown.coop.asc 
echo "deb [signed-by=/etc/apt/keyrings/deb.commown.coop.asc] https://deb.commown.coop/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/commown.list 
sudo apt update -y
sudo apt install -y tuxedo-control-center
EOF

}

zenity --question \
--title "Linux CC" \
--text "Voulez vous installer Linux Control Center ?"
 
if [ $? = 0 ]
then
#    echo "OUI "
    create_bash_file
    pkexec bash $PWD/bash.sh
    zenity --info --text "software installed "
else
    echo "NON !"

fi
