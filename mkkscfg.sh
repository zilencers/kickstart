#!/bin/bash

echo "------------------------------------------------"
echo "          Make Kickstart Config"
echo "------------------------------------------------"
echo " "
echo "The following prompts will help you make a"
echo "kickstart configuration file"

inst_environment() {
   echo " "
   echo "What type of installation environment you like?"
   echo "Please type in your answer."
   echo "graphical"
   echo "text"
   echo "cmdline"
   printf "> "
   read INST_ENV
}

eula() {
   echo " "
   echo "Automatically accept EULA?"
   echo "Please type accept or press enter to continue"
   printf "> "
   local answer=""
   read answer

   [ $answer ] && EULA="eula --$answer"
}

kbd_layout() {
   echo " "
   echo "What keyboard layout would you like to use?"
   echo "Press enter to use default US keyboard layout or"
   echo "enter --vckeymap=[country] --xlayouts='country'"
   printf "> "
   local answer=""
   read answer

   [ ! $answer ] && KEYBOARD="keyboard --vckeymap=us --xlayouts='us'"
   [ $answer ] && KEYBOARD="keyboard $answer"
}

system_lang() {
   echo " "
   echo "What system language you like to use?"
   echo "Press enter to use default en_US or enter your"
   echo "preferred system language"
   printf "> "
   local answer
   read answer

   [ ! $answer ] && LANG="lang en_US.UTF-8"
   [ $answer] && LANG="lang $answer"
}

add_drivers() {
   echo " "
   echo "Do you need to install additional drivers?"
   echo "Search for the driver disk image on a local"
   echo "partition (ie: /dev/sdb1) or enter a source"
   echo "(ie: --source http://path/to/dd.img)"
   echo "Press enter to skip"
   printf "> "
   local answer
   read answer

   [ $answer ] && DRIVER="driverdisk $answer"
}

install_media() {
   echo " "
   echo "What installation method would you like to use?"
   echo "The default method is cdrom (usb drive). You may"
   echo "enter a URL for a remote install."
   echo 'ie: --mirrorlist="https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-38&arch=x86_64"'
   echo "Press enter to skip and use the default method."
   printf "> "
   local answer
   read answer

   [ ! $answer ] && MEDIA="cdrom"
   [ $answer ] && MEDIA="url $answer"
}

network_setup() {
   echo " "
   echo "The following prompts will help you setup your network." 
   echo "Please enter a hostname:"
   printf "> "
   read SYS_HOSTNAME
   echo " "
   echo "Please enter the device name, MAC address, or specify 'link'"
   echo "which specifies the first interface with its link in the up state."
   printf "> "
   read DEVICE
   echo " "
   echo "What boot protocol would you like to use?"
   echo "ie: dhcp,bootp,static,query,ibft"
   echo "If static is selected, ip and netmask will need to be defined."
   printf "> "
   read BOOTPROTO

   if [ $BOOTPROTO = "static" ]; then
      echo "Please enter an IP Address:"
      printf "> "
      read IP_ADDR
      echo "Please enter a subnet mask:"
      printf "> "
      read SUBNET_MASK
   fi 

   echo " "
   echo "Would you like to enable this device at boot?"
   echo "yes or no"
   printf "> "
   read ONBOOT
   echo " "
   echo "If the device is a wireless NIC, please enter the SSID:"
   printf "> "
   read SSID
   
   if [ $SSID ]; then
      echo " "
      echo "Please enter the WPA Key for the wireless network:"
      printf "> "
      read WPAKEY
   fi

   NETWORK="network --device $DEVICE --onboot $ONBOOT --hostname $SYS_HOSTNAME --bootproto $BOOTPROTO " 

   if [ $BOOTPROTO = "static" ]; then
      NETWORK+="--ip $IP_ADDR --netmask $SUBNET_MASK "
   fi
   
   if [ $SSID ]; then
      NETWORK+="--essid $SSID --wpakey $WPAKEY "
   fi
}

packages() {
   echo " "
   echo "Please enter a comma separated list, with no spaces,"
   echo "of packages you would like to install."
   printf "> "
   local answer
   read answer

   IFS=','
   read -ra PKGS <<< "$answer"
}

write_config() {
   printf "# Installation Environment\n" >> "$SYS_HOSTNAME.ks"
   printf "$INST_ENV\n\n" >> "$SYS_HOSTNAME.ks"

   printf "# EULA\n" >> "$SYS_HOSTNAME.ks"
   printf "$EULA\n\n" >> "$SYS_HOSTNAME.ks"
   
   printf "# Keyboard Layout\n" >> "$SYS_HOSTNAME.ks"
   printf "$KEYBOARD\n\n" >> "$SYS_HOSTNAME.ks"
  
   printf "# System Language\n" >> "$SYS_HOSTNAME.ks"
   printf "$LANG\n\n" >> "$SYS_HOSTNAME.ks"

   printf "# Installation Media\n" >> "$SYS_HOSTNAME.ks"
   printf "$MEDIA\n\n" >> "$SYS_HOSTNAME.ks"

   printf "# Network\n" >> "$SYS_HOSTNAME.ks"
   printf "$NETWORK\n\n" >> "$SYS_HOSTNAME.ks"

   printf "# Package\n" >> "$SYS_HOSTNAME.ks"
   printf "%s\n" '%packages' >> "$SYS_HOSTNAME.ks"

   for i in "${PKGS[@]}"; do
      echo "-$i" >> "$SYS_HOSTNAME.ks"
   done

   printf "%s\n\n" '%end' >> "$SYS_HOSTNAME.ks"
}

main() {
   inst_environment
   eula
   kbd_layout
   system_lang
   add_drivers
   install_media
   network_setup
   packages
   write_config
}

main
