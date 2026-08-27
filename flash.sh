#!/bin/bash


echo "A FAIRE SUR ANDROID 11 , les fichiers doivent deja etre présent dans le repertoire "

echo "appuyez sur une touche"
read p
echo "brancher votre téléphone"
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


echo " unlocking bootloader "

fastboot oem unlock

echo " validate on phone "

echo " Reboot to STOCK and update to ANDROID 12 "
echo " press a key when fastboot ready " 

read p

echo " flash dtbo and vbmeta "

fastboot flash dtbo dtbo.img
fastboot flash vbmeta vbmeta.img

echo " flash  recovery " 

fastboot flash boot recovery.img

#echo " eteindre puis demarrer avec VOL_UP + POWER + HOME "
#echo "une fois dans le recovery - faire Wipe - format Data + system + cache "


echo " Lancez la recovery"
echo " Faites un Wipe DATA" 
echo " ensuite aller dans apply update - adb sideload "

echo " appuyer sur entrée quand sideload "
read p
adb sideload e.zip


echo " rebootez "



echo
echo "aurevoir"
exit 0
