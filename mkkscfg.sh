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
   local _answer
   read _answer

   [ $_answer ] && EULA="eula --$_answer"
}

kbd_layout() {
   echo " "
   echo "---------------- Keyboard Layout ----------------"
   echo "Press ENTER to use the default US keyboard layout"
   echo "or enter --vckeymap=[country] --xlayouts='country'"
   printf "> "
   local _answer
   read _answer

   [ ! $_answer ] && KEYBOARD="keyboard --vckeymap=us --xlayouts='us'"
   [ $_answer ] && KEYBOARD="keyboard $_answer"
}

system_lang() {
   echo " "
   echo "--------------- System Language --------------"
   echo "Press ENTER to use default en_US.UTF-8 or type"
   echo "in your preferred system language."
   printf "> "
   local _answer
   read _answer

   [ ! $_answer ] && LANG="lang en_US.UTF-8"
   [ $_answer] && LANG="lang $_answer"
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
   local _answer
   read _answer

   [ $_answer ] && DRIVER="driverdisk $_answer"
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
   local _answer
   read _answer

   [ ! $_answer ] && MEDIA="cdrom"
   [ $_answer ] && MEDIA="url $_answer"
}

header_network() {
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
   echo "Enable this device at boot? yes/no"
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

header_packages() {
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
   local _answer
   read _answer

   IFS=','
   read -ra PKGS <<< "$_answer"
}

header_users_groups() {
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
   local _answer
   read _answer

   if [ $_answer = 'yes' ]; then

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

header_partitioning() {
   echo "---------------------------------------------------------------------"
   echo "                     Storage and Partitioning"
   echo "---------------------------------------------------------------------"
}

ignore_disk() {
   echo " "
   echo "-------------------- Disk Selection --------------------" 
   echo "Specify disks to ignore with the --drives=[drives] or" 
   echo "only use a specific disk with the --only-use= directive."
   printf "> "
   local _answer
   read _answer

   IGNOREDISK="ignoredisk $_answer"
}

clear_part() {
   echo " "
   echo "---------------------- Clear Partition ----------------------"
   echo "You can clear partitions with the following directives:"
   echo "--all --drives=sda,sdb (all partitions on drives sda and sdb)"
   echo "--list=sda2,sda3,sdb1 (only the specified partitions)"
   echo "--linux (all linux partitions)"
   echo "Press ENTER to skip with step"
   printf "> "
   local _answer
   read _answer

   [ $_answer ] && CLEARPART="clearpart $_answer"
}

partition_method() {
   echo " "
   echo "How do you want to partition the disk? automatic/manual" 
   printf "> "
   local _answer
   read _answer

   [ $_answer = "automatic" ] && auto_partition || manual_partition
}

auto_part_selection() {
   local _answer

   echo " "
   echo "Choose a filesystem type: ext[2,3,4],reiserfs,jfs,xfs:"
   printf "> "
   read _answer

   FSTYPE="--fstype=$_answer"

   printf "\nUse LVM? yes/no\n"
   printf "> "
   read _answer

   [ $_answer = "no" ] && LVM="--nolvm" || LVM=""

   printf "\nEncrypt all partitions? yes/no\n"
   printf "> "
   read _answer

   [ $_answer = "yes" ] && ENCRYPTED="--encrypted" || ENCRYPTED=""

   if [ $_answer = "yes" ]; then
      printf "\nEnter a passphrase for encrypted partitions:\n"
      printf "> "
      read _answer

      PASSPHRASE="--passphrase=$_answer"
   fi

   AUTOPART="autopart $FSTYPE "
   [ -n $LVM ] && AUTOPART+="$LVM "
   [ -n $ENCRYPTED ] && AUTOPART+="$ENCRYPTED $PASSPHRASE"
}

auto_partition() {
   echo " "
   echo "Use one of the predefined auto partitioning schemes,"
   echo "lvm, btrfs, plain or thinp? yes/no"
   printf "> "
   local _answer_scheme
   read _answer_scheme

   [ $_answer = "yes" ] && AUTOPART="autopart --type=$_answer" || auto_part_selection
}

select_device() {
   printf "\nEnter the device for this partition:\n"
   printf "> "
   local _disk
   read _disk

   local _result=$1
   eval $_result="'$_disk'"
}

create_bootpart() {
   echo " "
   echo "------------------ Boot Partition -----------------"
   echo "Enter a mount point of either biosboot or /boot/efi"
   printf "> "
   local _answer
   read _answer
   
   local _disk
   select_device _disk

   local _result=$1
   local _mntpoint="part $_answer "
   [ $_answer == "/boot/efi" ] && \
       _mntpoint+="fstype=\"efi\" --ondisk=$_disk --size=500 --fsoptions=\"umask=0077,shortname=winnt\" --label=boot"
   eval $_result="'$_mntpoint'"
}

mount_point() {
   echo "Enter the mount point for the partition:"
   printf "> "
   local _mntpoint
   read _mntpoint

   local _result=$1
   eval $_result="'$_mntpoint'"
}

fstype() {
   printf "\nEnter the filesystem type, valid values are:\n"
   printf "ext[2,3,4], xfs, swap, vfat, efi, biosboot\n"
   printf "> "
   local _fstype
   read _fstype

   local _result=$1
   eval $_result="'$_fstype'"
}

part_size() {
   printf "\nEnter the partition size in megabytes (without the unit)\n"
   printf "> "
   local _size
   read _size

   local _result=$1
   eval $_result="'$_size'"
}

part_label() {
   printf "\nEnter a label for the partition.\n"
   printf "> "
   local _label
   read _label

   local _result=$1
   eval $_result="'$_label'" 
}

create_partition() {
   echo " "
   echo "------------------ Create Partition -----------------"
   echo " "

   local _partition=()
   local _mntpoint
   local _fstype
   local _ondisk
   local _size
   local _label

   while true
   do
      mount_point _mntpoint
      fstype _fstype
      select_device _ondisk
      part_size _size
      part_label _label
      # TODO: ADD FSOPTIONS
      _partition+=("part $_mntpoint --fstype=$_fstype --ondisk=$_ondisk --size=$_size --label=$_label")

      printf "\nCreate another partition? yes/no\n"
      printf "> "
      local _answer
      read _answer

      [ $_answer = "no" ] && break
   done

   local _result=$1
   eval $_result="'${_partition[@]}'"
   # part btrfs.107 --fstype="btrfs" --ondisk=sdb --size=9214
   # part mntpoint --name=name --device=device --rule=rule [options]
}

manual_partition() {
   create_bootpart BOOTPART
   create_partition PARTITION

   echo $BOOTPART
   for i in ${PARTITION[@]}; do
      echo $i
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

   printf "\n" >> "$cfg"

   printf "# Ignore Disks\n" >> "$cfg"
   printf "$IGNOREDISK\n\n" >> "$cfg"

   printf "# Clear Partitions\n" >> "$cfg"
   [ $CLEARPART ] && printf "%s\n\n" $CLEARPART >> "$cfg" 

   printf "# Partitioning\n" >> "$cfg"
   [ -n "$AUTOPART" ] && echo "$AUTOPART" >> "$cfg"
   [ -n "$BOOTPART" ] && echo "$BOOTPART" >> "$cfg"
   [ -n "$PARTITION" ] && echo "$PARTITION" >> "$cfg"
}

main() {
   inst_environment
   eula
   kbd_layout
   system_lang
   set_time
   add_drivers
   install_media

   header_network
   hostname
   device
   ip_allocation
   on_boot
   wifi
   net_final

   header_packages
   packages

   header_users_groups
   root_account
   user_accounts
   
   header_partitioning
   ignore_disk
   clear_part
   partition_method
   
   write_config
}

main
