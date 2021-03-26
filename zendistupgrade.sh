#!/bin/bash

#=== Upgrade de 15.10 à 16.04 :
#== B. Mauclaire - 2017/11


#--------------------------------------------#
#- Mets a jour le source list pour pointer sur le serveur old-releases
# ( voir  https://doc.ubuntu-fr.org/old-releases )
#- Lance l'upgrade vers 16.04 si tout va bien
#- do-release-upgrade
#--------------------------------------------#

#--- TODO :
#-- Transformer le script en binaire : shc -f script.sh
#-- Puis faire un tarball


#--- Varaibles globales :
#-- Graphical sudo :
#GSUDO=sudo
GSUDO=gksudo

#--- Procedure de modification du fichier sources.list :
modifsourcelist()
{
   SRC=/etc/apt/sources.list
   echo "Modifications du fichier sources.list..."
   sudo cp $SRC ${SRC}.1510

   #-- Pour les partner, changer wily en xenial !! --
   #- Doit devenir : deb http://archive.canonical.com/ubuntu xenial partner
   #sudo sed -i '/partner/ s/wily/xenial/' $SRC
   ##sudo sed -i '/partner/ s/trusty/xenial/' $SRC
   #- Enelve le '#' devant les lignes partner :
   sudo sed -i '/wily\spartner/ s/^#*\s//' $SRC
   #- Retirez toutes les lignes faisant référence au dépôt partner ;  NON !
   # meth : contient "partner", ne démarre pas par #, alors ecrire # en debut
   #sudo sed -i '/partner/ s/^#*/#/' $SRC
   #- Retirez toutes les lignes faisant référence au serveur http://extras.ubuntu.com/ubuntu : OUI
   sudo sed -i '/extras/ s/^#*/#/' $SRC

   #-- Remplacez toutes les instances http://xx.archive.ubuntu.com/ubuntu, où xx est un code de pays (fr, ca, ch, be…), par http://old-releases.ubuntu.com/ubuntu ;
   # meth : commence par "deb", contient *.archive, remplacer par old-release
   #sudo sed -i '/^deb/ s/http:\/\/.*archive./http:\/\/old-releases./g' $SRC
   #- Ne modifie que les lignes ubuntu.com :
   sudo sed -i '/^deb/ s/http:\/\/.*archive.ubuntu.com/http:\/\/old-releases.ubuntu.com/g' $SRC

   # Remplacez toutes les instances http://security.ubuntu.com/ubuntu par http://old-releases.ubuntu.com/ubuntu
   sudo sed -i '/^deb/ s/http:\/\/security.ubuntu.com/http:\/\/old-releases.ubuntu.com/g' $SRC
}
#---------------------------------------------#

#--- Procedure d'upgrade de la distribution :
upgradedistro()
{
   SRC=/etc/update-manager/release-upgrades
   #-- Préalables à une maj distro :
   sudo apt-get install apt -y
   #- Modifie le comportement de maj :
   sudo cp $SRC ${SRC}.orig
   sudo sed -i '/Prompt/ s/=lts/=normal/' $SRC
   #-- sudo apt-get install update-manager-core
   sudo do-release-upgrade -f DistUpgradeViewNonInteractive
   #-- Remet le comportement de maj :
   #sudo sed -i '/Prompt/ s/=normal/=lts/' $SRC
   $GSUDO sed -i '/Prompt/ s/=normal/=lts/' $SRC
}
#---------------------------------------------#

#--- Procedure d'upgrade de la distribution :
manualactions()
{
   echo "A faire : actions TBD manual du TODO"
   # - Update GRUB_RECORDFAIL_TIMEOUT=1 so oem-config does not show grub
   # - enable canonical partner repo
   # - TOP ICI : enable better defaults for updates ( Check every 2 days,download  security auto, show others every 2 weeks )
   #-- /etc/apt/apt.conf.d/50unattended-upgrades ou 10periodic
   #-- Maj secu : uniquement telecharger auto
   SRC=/etc/apt/apt.conf.d/10periodic
   #- (1->0) APT::Periodic::Unattended-Upgrade "0";
   sudo sed -i '/Unattended-Upgrade/ s/1/0/' $SRC
   # - Enable sleep on lid close
   # - Enable Windows menu in the window title bar
   # - Put size of launcher to 24
   # - Show the % and time of battery as a default
   # - Ajust Sleep timeout to 30 min
   # - First run : Set wallpaper to ekimia one

}
#---------------------------------------------#

#--- Procedure d'upgrade de la distribution :
ekimiaupdates16()
{
   echo "A faire : executer notre script pour 16.04"
}
#---------------------------------------------#

#--- Procedure de test de la version avant maj :
testversiondistro()
{
   #echo "A faire : test version"
   no_version=`lsb_release -rs`
   #-- Compare la chaine de caracteres decrivant le no de version :
   if [ $no_version != 15.10 ] ; then
      echo "Votre version d'Ubuntu ne nécessite pas de mise à jour."
      zenity --info --text "Votre version d'Ubuntu ne nécessite pas de mise à jour."
      exit
   fi
}
#---------------------------------------------#


#==== Procedure principale =====================================#
#--- Affichage de la boîte de dialogue pour confirmation :
zenity --question \
--title "Ekimia - Mise à jour vers Ubuntu 16.04" \
--text "Voulez-vous faire la mise à jour vers Ubuntu 16.04 ?"

if [ $? = 0 ] ; then
   #--- Vérifie si la version est inférieure ou egale à 15.10 :
   testversiondistro

   #--- Modifications du fichier sources.list :
   modifsourcelist

   #--- Mise a jour de la base :
   sudo apt-get update

   #--- Mise a jour de la distribution :
   zenity --info --text "Démarrage de la mise à jour de la distribution : ne pas éteindre votre ordinateur durant l'opération"
   echo "Démarrage de la mise à jour de la distribution : ne pas éteindre votre ordinateur durant l'opération"
   upgradedistro

   #-- Execute les actions TBD manual du TODO :
   manualactions

   #-- Execute ensuite notre script pour 16.04 :
   ekimiaupdates16

   #--- Fin de la maj :
   #zenity --info --text "Mise à jour terminée. Choisir OK pour redémarrer"
   #echo "Mise à jour terminée. Veuillez redémarrer"
   zenity --question --text "Mise à jour terminée. Voulez-vous redémarrer maintenant ?"
   #sleep 1
   if [ $? = 0 ] ; then
      $GSUDO reboot
   else
      echo "Veuillez redémarrer ultérieurement."
   fi
else
   zenity --info --text "Aucune opération effectuée"
   echo "Aucune opération effectuée"
   sleep 1
fi
#---------------------------------------------#
