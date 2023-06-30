#!/bin/bash



case $# in
   1) nom_disque=$1 ;;
   *) #df -h | grep /dev/sd ; Faut extraire de syslog
      echo "Usage: formatdd2.sh /dev/sdx" ;
      exit;;
esac

rep_disk=$nom_disque
chemin_disk=/media/$rep_disk

#--- Affiche les disks : faut extraire de syslog
#df -h | grep /dev/sd

#--- Cree la partition sur un disk vide ? :
echo " -------------------   Création de la partition 1 sur le disque ${nom_disque}1..."
echo -e "g\nn\np\n1\n\n\nw" | sudo fdisk $nom_disque

sleep 2s

#--- Formatage :
echo " -------------------- Formatage de la partition 1 du disque ${nom_disque}..."
sudo mkfs.ext4 ${nom_disque}1

sleep 2s

#--- Nomage du disque et attribution des droits :
echo "-------------------- Nomage du disque "
sudo e2label ${nom_disque}1 "DISQUEDUR"

echo " ----------------- montage "

sudo mkdir -p $chemin_disk

#Todo : works only on SATA/USB disk
sudo mount ${nom_disque}1 $chemin_disk
sleep 2 

echo " -------------- attribution des droits..."

#For some reason this does not work
sudo chmod -R 777 $chemin_disk
sudo sync

echo "---------------------   démontage "
sleep 4s
sudo umount $chemin_disk
sudo rmdir $chemin_disk

#-- Fin :
echo "Le disque $nom_disque a été formaté correctement."
