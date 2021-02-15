#!/bin/bash

#=== Upgrade ubuntu to next distro  
#== M.memeteau / EKIMIA
#Run as root 



#--- Procedure d'upgrade de la distribution :
upgradedistro()
{
   SRC=/etc/update-manager/release-upgrades
   #-- Préalables à une maj distro :
   apt-get install apt -y
   #- Modifie le comportement de maj :
   #sudo cp $SRC ${SRC}.orig
   #sudo sed -i '/Prompt/ s/=lts/=normal/' $SRC
   #-- sudo apt-get install update-manager-core
   do-release-upgrade -f DistUpgradeViewNonInteractive
   #-- Remet le comportement de maj :
   #sudo sed -i '/Prompt/ s/=normal/=lts/' $SRC
   #$GSUDO sed -i '/Prompt/ s/=normal/=lts/' $SRC
}

#--- Procedure de test de la version avant maj :
isobsolete()
{
   #echo "A faire : test version"
   no_version=`lsb_release -rs`
   #-- Compare la chaine de caracteres decrivant le no de version :
   if [ $no_version != 20.04 || $no_version = 17.10] ; then
      echo "Votre version d'Ubuntu est obsolète , réparons ça"
      zenity --info --text "Votre version d'Ubuntu est obsolète , réparons ça"
      
   else 
      echo "Votre version d'Ubuntu n'est pas obsolète "
      zenity --info --text "Votre version d'Ubuntu n'est pas obsolète "
      
   fi
}


islts
{
    if [ $no_version != 20.04 || $no_version = 17.10] ; then



}
#---------------------------------------------#


#==== Procedure principale =====================================#

   #--- Mise a jour de la base :
  

   #--- Mise a jour de la distribution :

   echo "Démarrage de la mise à jour de la distribution : ne pas éteindre votre ordinateur durant l'opération"
   echo "Répondre yes aux rares questions posées , appuyez sur une touche pour démarrer"
   read any
   sudo apt-get update
   
   sudo apt upgrade -y
   upgradedistro

 
   echo "Mise à jour terminée. appuyez sur une touche et  redémarrer"
   read fin
   
#---------------------------------------------#
