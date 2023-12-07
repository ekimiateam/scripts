#!/bin/bash
zenity --question \
--title "restorerefind" \
--text "Voulez vous mettre refind par défaut au démarrage?"
 
if [ $? = 0 ]
then
    echo "OUI "
    pkexec refind-mkdefault
    zenity --info --text "Terminé"
else
    echo "NON !"

fi