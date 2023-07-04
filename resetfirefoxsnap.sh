#!/bin/bash
echo " merci de fermer Firefox et d'appuyer sur une touche"
read p
echo " remise a zero du profil firefox" 
mv ~/snap/firefox ~/snap/firefox.ekimia
echo "deplacement terminé, vous pouvez relancer firefox, appuyez sur une touche  " 
read p