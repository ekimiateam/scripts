#!/bin/bash


echo "Bonjour , les fichiers doivent deja etre présent dans le repertoire "

FILE_ROM=e-0.19-r-20211129148871-dev-klte.zip
FILE_RECOVERY=twrp-3.6.0_9-0-klte.img


echo "appuyez sur une touche"
read p
echo "brancher votre téléphone"
echo "installer grâce à cette commande:"
sudo apt install adb fastboot heimdall-flash
echo "Ensuite dans la barre de recherche des paramètres taper numéro"
echo "Allez dans numéro de version" 
echo "Puis tapez 7 fois sur numéro de version"
echo "A nouveau dans les paramètres"
echo " action debogage USB "
echo " apuyez sur entrée quand fait "
read p 

adb devices 

echo " confirmez la connexion sur le telephone en appuyant sur entrée "

read p 

adb devices 

echo "redemarrage en bootloader "
adb reboot bootloader

echo " appuyer sur entrée quand ecran bootloader pret"
read p 

heimdall flash --RECOVERY $FILE_RECOVERY --no-reboot


echo " eteindre puis demarrer avec VOL_UP + POWER + HOME "
echo "une fois dans le recovery - faire Wipe - format Data + system + cache "

echo " ensuite aaler dans advances - adb sideload "

echo " appuyer sur entrée quand sideload "
read p
adb sideload $FILE_ROM


echo " rebootez "



echo
echo "aurevoir"
exit 0