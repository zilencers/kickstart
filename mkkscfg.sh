#!/bin/bash

echo "------------------------------------------------------------------------"
echo "                           System Setup"
echo "------------------------------------------------------------------------"
echo " "
echo "The following prompts will help you make a kickstart configuration file."
echo "Please type in your answer at the '>' prompt and press enter"

inst_environment() {
   echo " "
   echo "---- Installation Environment ----"
   echo "Please select one of the following:"
   echo "graphical | text | cmdline"
   printf "> "
   read INST_ENV
}

eula() {
   echo " "
   echo "--------------- EULA -------------"
   echo "Automatically accept EULA?"
   echo "Type 'accept' or press ENTER to continue"
   printf "> "
   local answer=""
   read answer

   [ $answer ] && EULA="eula --$answer"
}

kbd_layout() {
   echo " "
   echo "---------------- Keyboard Layout ----------------"
   echo "Press ENTER to use the default US keyboard layout"
   echo "or enter --vckeymap=[country] --xlayouts='country'"
   printf "> "
   local answer=""
   read answer

   [ ! $answer ] && KEYBOARD="keyboard --vckeymap=us --xlayouts='us'"
   [ $answer ] && KEYBOARD="keyboard $answer"
}

system_lang() {
   echo " "
   echo "--------------- System Language --------------"
   echo "Press ENTER to use default en_US.UTF-8 or type"
   echo "in your preferred system language."
   printf "> "
   local answer
   read answer

   [ ! $answer ] && LANG="lang en_US.UTF-8"
   [ $answer] && LANG="lang $answer"
}

set_time() {
   echo " "
   echo "-------------------------- Timezone -------------------------"
   echo "Enter a timezone for the system. To view a list of available"
   echo "timezones run: timedatectl list-timezones"
   printf "> "
   local _answer
   read _answer

   TIMEZONE="timezone $_answer --utc"
}

add_drivers() {
   echo " "
   echo "----------- Additional Drivers ------------"
   echo "Search for the driver disk image on a local"
   echo "partition (ie: /dev/sdb1) or enter a source"
   echo "(ie: --source http://path/to/dd.img)"
   echo "Press ENTER to skip"
   printf "> "
   local answer
   read answer

   [ $answer ] && DRIVER="driverdisk $answer"
}

install_media() {
   echo " "
   echo "-------------- Installation Method --------------"
   echo "The default method is cdrom (usb drive). You may"
   echo "enter a URL for a remote install."
   echo 'ie: --mirrorlist="https://mirrors.fedoraproject.org'
   echo '/mirrorlist?repo=fedora-38&arch=x86_64"'
   echo "Press ENTER to skip and use the default method."
   printf "> "
   local answer
   read answer

   [ ! $answer ] && MEDIA="cdrom"
   [ $answer ] && MEDIA="url $answer"
}

network_setup() {
echo "-----------------------------------------------------------------------"
echo "                           Network Setup"
echo "-----------------------------------------------------------------------"
}

hostname() {
   echo " "
   echo "--------- Hostname ----------"
   echo "Please enter a hostname:"
   printf "> "
   read CMP_NAME
}

device() {
   echo " "
   echo "----------------------- Network Device ---------------------------"
   echo "Please type in the device name, MAC address, or specify 'link'"
   echo "which specifies the first interface with its link in the up state."
   printf "> "
   read DEVICE
}

ip_allocation() {
   echo " "
   echo "------------------------ IP Allocation --------------------------"
   echo "Please type in one of the following: dhcp,bootp,static,query,ibft"
   echo "If static is selected, ip and netmask will need to be defined."
   printf "> "
   read BOOTPROTO

   if [ $BOOTPROTO = "static" ]; then
      echo " "
      echo "Please enter an IP Address:"
      printf "> "
      read IP_ADDR

      echo " "
      echo "Please enter a subnet mask:"
      printf "> "
      read SUBNET_MASK
   fi 
}

on_boot() {
   echo " "
   echo "---------- On Boot ----------"
   echo "Enable this device at boot?"
   echo "yes or no"
   printf "> "
   read ONBOOT
}

wifi() {
   echo " "
   echo "-------------------- WiFi Setup -----------------------"
   echo "If the device specified above is a Wireless NIC, please"
   echo "type in the SSID or press ENTER to skip."
   printf "> "
   read SSID
   
   if [ $SSID ]; then
      echo " "
      echo "Enter the WPA Key for the wireless network:"
      printf "> "
      read WPAKEY
   fi
}

net_final() {
   NETWORK="network --device $DEVICE --onboot $ONBOOT --hostname $CMP_NAME --bootproto $BOOTPROTO " 

   if [ $BOOTPROTO = "static" ]; then
      NETWORK+="--ip $IP_ADDR --netmask $SUBNET_MASK "
   fi
   
   if [ $SSID ]; then
      NETWORK+="--essid $SSID --wpakey $WPAKEY "
   fi
}

pkg_selection() {
   echo "---------------------------------------------------------------------"
   echo "                       Package Selection"
   echo "---------------------------------------------------------------------"
}

packages() {
   echo " "
   echo "--------------------- Packages --------------------------"
   echo "Enter a comma separated list, with no spaces, of packages"
   echo "to install during setup."
   printf "> "
   local answer
   read answer

   IFS=','
   read -ra PKGS <<< "$answer"
}

user_accounts() {
   echo "---------------------------------------------------------------------"
   echo "                       Users and Groups"
   echo "---------------------------------------------------------------------"
}

get_pass() {

    local _result=$1
    local password=$(python -Wignore -c 'import crypt,getpass; \
      print(crypt.crypt(getpass.getpass(), crypt.mksalt(crypt.METHOD_SHA512)))')
    eval $_result="'$password'"
}

root_account() {
   echo " "
   echo "----------------- Root Account ----------------"
   echo "Enable root account? yes/no"
   printf "> "
   local answer
   read answer

   if [ $answer = 'yes' ]; then

       local _root_passwd
       get_pass _root_passwd
       ROOTPW="rootpw --iscrypted $_root_passwd"
   else
      ROOTPW="rootpw --lock"
   fi
}

user_accounts() {
   echo " "
   echo "----------------- User Accounts ----------------"
   
   local _answer
   local _username
   local _groups
   local _password
   USERS=()

   echo "Setup a user account? yes/no"
   printf "> "
   read _answer

   while true
   do
      [ $_answer = "no" ] && break
           
      if [ $_answer = "yes" ]; then
          
	  printf "Username: "
	  read _username
	  
	  printf "Groups (comma separated): "
	  read _groups

	  get_pass _password
	  
	  USERS+=("--user --groups=$_groups --name=$_username --password=$_password --iscrypted")
      fi

      printf "\nSetup another user? yes/no\n"
      printf "> "
      read _answer
      
   done
}

write_config() {
   local cfg="$CMP_NAME.ks"

   printf "# Installation Environment\n" >> "$cfg"
   printf "$INST_ENV\n\n" >> "$cfg"

   printf "# EULA\n" >> "$cfg"
   printf "$EULA\n\n" >> "$cfg"
   
   printf "# Keyboard Layout\n" >> "$cfg"
   printf "$KEYBOARD\n\n" >> "$cfg"
  
   printf "# System Language\n" >> "$cfg"
   printf "$LANG\n\n" >> "$cfg"

   printf "# Timezone\n" >> "$cfg"
   printf "$TIMEZONE\n\n" >> "$cfg"

   printf "# Installation Media\n" >> "$cfg"
   printf "$MEDIA\n\n" >> "$cfg"

   printf "# Network\n" >> "$cfg"
   printf "$NETWORK\n\n" >> "$cfg"

   printf "# Package\n" >> "$cfg"
   printf "%s\n" '%packages' >> "$cfg"

   for i in "${PKGS[@]}"; do
      echo "-$i" >> "$cfg"
   done

   printf "%s\n\n" '%end' >> "$cfg"

   printf "# Root Account\n" >> "$cfg"
   printf "$ROOTPW\n\n" >> "$cfg"

   printf "# User Accounts\n" >> "$cfg"

   for i in "${USERS[@]}"; do
      echo "$i" >> "$cfg"
   done

   printf "\n"
}

main() {
   inst_environment
   eula
   kbd_layout
   system_lang
   set_time
   add_drivers
   install_media
   network_setup
   hostname
   device
   ip_allocation
   on_boot
   wifi
   net_final
   pkg_selection
   packages
   root_account
   user_accounts
   write_config
}

main
