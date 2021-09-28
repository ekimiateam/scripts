echo  " salut script d'installl mode kiosk " 

# Create the guest user with /tmp/guest as home directory 
sudo useradd -d /tmp/guestx -p guest guest
# Copy the Postlogin file "Default" 

sudo mv /etc/gdm3/PostLogin/Default /etc/gdm3/PostLogin/Default.back
sudo cp -f Default /etc/gdm3/PostLogin/Default
# change the rights of the default file to 755

sudo chmod 755 /etc/gdm3/PostLogin/Default
# Change the timed  autologin  of the guest user ( /etc/gdm3/custom.conf ) 


echo " installation is finished , please press a key  "

read p


exit 0


