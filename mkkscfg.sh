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
   NETWORK=()
   NETWORK[0]+="network --hostname=$CMP_NAME"
   NETWORK[1]+="network --activate --device=$DEVICE --onboot=$ONBOOT --bootproto=$BOOTPROTO " 

   [ $BOOTPROTO = "static" ] && NETWORK[1]+="--ip=$IP_ADDR --netmask=$SUBNET_MASK "
   [ $SSID ] && NETWORK[1]+="--essid=$SSID --wpakey=$WPAKEY "
}

header_firewall() {
echo "---------------------------------------------------------------------"
echo "                           Firewall"
echo "---------------------------------------------------------------------"
}

firewall_config() {
   echo " "
   echo "Would you like to enable the firewall? yes/no"
   printf "> "
   local _answer
   read _answer

   FIREWALL="firewall --disabled"

   if [ $_answer = "yes" ]; then
      FIREWALL="firewall --enabled"

      while true
      do
         printf "\nConfigure additional firewall rules? yes/no\n"
         printf "> "
         read _answer

         if [ $_answer = "yes" ]; then
            printf "\nUse one of the following directives to specify\n"
	    printf "the firewall configuration\n"
	    printf " * --trust=[device] allows all traffic to and from\n"
	    printf " * --port=[1234:udp] allows ports through the firewall\n"
	    printf " * --service=[service name] allow services through firewall\n"
	    printf "> "
	    local _rule
	    read _rule

	    FIREWALL+=" $_rule"
         else
	    break
	 fi
      done
   fi
}

header_packages() {
   echo "---------------------------------------------------------------------"
   echo "                       Package Selection"
   echo "---------------------------------------------------------------------"
}

get_pkg_list() {
   local _file=$PWD"/config/pkg.list"
   local _pkgs

   while IFS= read -r line
   do
      _pkgs+=$line","
   done < "$_file"

   local _result=$1
   eval $_result="'$_pkgs'"
}

packages() {
   PKGS=()

   echo " "
   echo "---------------------- Packages ----------------------------"
   echo "Select one of the following options:"
   echo "1. Enter a list of packages here"
   echo "2. Get packages from config/pkg.list"
   printf "> "
   local _answer
   read _answer

   local _packages

   if [ $_answer -eq 2 ]; then
      get_pkg_list _packages
   else
      printf "\nEnter a comma separated list of packages (no spaces)\n"
      printf "> "
      read _packages
   fi

   IFS=','
   read -ra PKGS <<< "$_packages"
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
	  
	  USERS+=("user --groups=$_groups --name=$_username --password=$_password --iscrypted")
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
   echo "----------------- Partitioning Method -----------------"
   echo "How do you want to partition the disk? automatic/manual" 
   printf "> "
   local _answer
   read _answer

   [ $_answer = "automatic" ] && auto_partition || manual_partition
}

auto_part_selection() {
   local _answer

   echo " "
   echo "----------------- Auto Partitioning -----------------"
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
   echo "----------------- Partitioning Scheme -----------------"
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

mount_point() {
   echo " " 
   echo "------------------------ Mount Point ------------------------"
   echo "Enter the mount point for the partition or btrfs (sub)volume."
   echo "  * Boot Partition: biosboot or /boot/efi"
   echo "  * Btrfs partition mount point should be btrfs.1xx" 
   printf "> "
   local _answer
   read _answer

   local _result=$1
   eval $_result="'$_answer'"
}

fstype() {
   echo " "
   echo "----------------- Filesystem Type -----------------"
   echo "Enter the filesystem type, valid values are:"
   echo "btrfs, ext[2,3,4], xfs, swap, vfat, efi, biosboot"
   printf "> "
   local _answer
   read _answer

   local _result=$1
   eval $_result="'$_answer'"
}

part_size() {
   echo " "
   echo "------------------------- Partition Size -------------------------"
   echo "Enter the partition size in megabytes (without the unit)"
   echo "NOTE: biosboot requires a size of 2 megabytes or install will fail"
   printf "> "
   local _answer
   read _answer

   local _result=$1
   eval $_result="'$_answer'"
}

part_label() {
   echo " "
   echo "----------------- Partition Label -----------------"
   echo "Enter a label for the partition or volume."
   printf "> "
   local _answer
   read _answer

   local _result=$1
   eval $_result="'$_answer'" 
}

btrfs_raid_level() {
   echo " "
   echo "----------------- Raid Level -----------------"
   echo "Enter the raid $2 level (0,1,10):"
   echo "Press ENTER to skip"
   local _answer
   read _answer

   local _result=$1
   eval $_result="'$_answer'"
}

create_btrfs_subvol() {
   echo " "
   echo "---------------------------------------------------------------------"
   echo "                          Btrfs Subvolume"
   echo "---------------------------------------------------------------------"
   
   SUBVOLUME=()
   local _i=0

   while true
   do
      local _mntpoint
      mount_point _mntpoint

      echo " "
      echo "Enter a name for the subvolume"
      printf "> "
      local _name
      read _name

      echo " "
      echo "Enter the parent volume for this subvolume"
      printf "> "
      local _parent
      read _parent

      SUBVOLUME[$_i]="btrfs $_mntpoint --subvol --name=$_name LABEL=$_parent|"
      ((_i++))

      echo " "
      echo "Add another btrfs subvolume? yes/no"
      printf "> "
      local _answer
      read _answer

      [ "$_answer" = "no" ] && break
   done
}

create_btrfs_volume() {
   echo " " 
   echo "---------------------------------------------------------------------"
   echo "                          Btrfs Volume"
   echo "---------------------------------------------------------------------"
   local _mntpoint
   mount_point _mntpoint

   local _datalevel
   btrfs_raid_level _datalevel "data"

   local _metalevel
   btrfs_raid_level _metalevel "metadata"

   local _label
   part_label _label

   echo " "
   echo "-------------------- Partition ---------------------"
   echo "Enter the partition to be used for this btrfs volume"
   printf "> "
   local _part
   read _part

   BTRFS_VOLUME="btrfs $_mntpoint "
   [ -n "$_datalevel" ] && BTRFS_VOLUME+="--data=$_datalevel "
   [ -n "$_metalevel" ] && BTRFS_VOLUME+="--metadata=$_metalevel "
   [ -n "$_label" ] && BTRFS_VOLUME+="--label=$_label "
   BTRFS_VOLUME+="$_part"

   create_btrfs_subvol
}

create_partition() {
   PARTITIONS=()
   PART_SIZE=()
   local _mntpoint
   local _fstype
   local _ondisk
   local _size
   local _label
   local _i=0

   while true
   do
      mount_point _mntpoint
      fstype _fstype
      select_device _ondisk
      part_size _size
      part_label _label
      # TODO: ADD FSOPTIONS
      
      PART_SIZE[$_i]+=$_size
      PARTITIONS[$_i]+="part $_mntpoint --fstype=\"$_fstype\" --ondisk=$_ondisk --size=$_size --label=$_label"

      if [ $_mntpoint = "/boot/efi" ]; then
         local length=${#PARTITIONS[$_i]}
         local substr=${PARTITIONS[$_i]:0:$length}
	 PARTITIONS[$_i]=$substr' --fsoptions="umask=0077,shortname=winnt"'
      fi

      ((_i++))

      printf "\nCreate another partition? yes/no\n"
      printf "> "
      local _answer
      read _answer

      [ $_answer = "no" ] && break
   done
}

manual_partition() {
   create_partition

   [[ -n $(echo ${PARTITIONS[@]} | grep -o "btrfs") ]] && create_btrfs_volume
}

header_post_inst() {
   echo "---------------------------------------------------------------------"
   echo "                   Post Installation Script"
   echo "---------------------------------------------------------------------"
}

post_inst() {
   printf "\nInclude post-install script? yes/no\n"
   printf "> "
   local _answer
   read _answer

   if [ $_answer = "yes" ]; then
      script=$(ls "$PWD/scripts/")  
      POSTINST_SCRIPT_PATH="$PWD/scripts/$script"

      #printf "\nEnter the path to the script you would like to include:\n"
      #printf "> "
      #read POSTINST_SCRIPT_PATH

      printf "\nEnter the path to the interpreter to use:\n"
      printf "> "
      local _interpreter
      read _interpreter

      printf "\nIf you would like to log the scripts output, enter a path\n"
      printf "for the log file. Press ENTER to skip.\n"
      printf "> "
      local _log
      read _log
      
      printf "\nHalt installation if the script fails? yes/no\n"
      printf "> "
      local _error
      read _error

      POST_INST="%post --interpreter=$_interpreter "
      [ $_log ] && POST_INST+="--log=$_log "
      [ $_error = "yes" ] && POST_INST+="--erroronfail"
   fi
}

write_config() {
   local cfg="config/$CMP_NAME.ks"

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

   for ((i=0; i <= ${#NETWORK[@]}; i++)); do
      echo ${NETWORK[$i]} >> "$cfg"
   done
  
   printf "# Firewall\n" >> "$cfg"
   printf "$FIREWALL\n\n" >> "$cfg"

   printf "# Package\n" >> "$cfg"
   printf "%s\n" '%packages' >> "$cfg"

   for i in "${PKGS[@]}"; do
      #echo "$i" | tr -d '\n' >> "$cfg"
      echo "$i" >> "$cfg"
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
   [ -n "$CLEARPART" ] && printf "%s\n\n" $CLEARPART >> "$cfg" 

   printf "# Partitioning\n" >> "$cfg"
   [ -n "$AUTOPART" ] && echo "$AUTOPART" >> "$cfg"

   if [[ -n "${PARTITIONS[@]}" ]]; then
      for ((i=0; i <= ${#PART_SIZE[@]}; i++)); do
	 [[ ${PART_SIZE[$i]} -ge 1024 ]] && echo ${PARTITIONS[$i]} >> "$cfg"
      done

      for ((j=0; j <= ${#PART_SIZE[@]}; j++)); do
         [[ ${PART_SIZE[$j]} -le 1024 ]] && echo ${PARTITIONS[$j]} >> "$cfg"
      done
   fi

   [ -n "$BTRFS_VOLUME" ] && echo "$BTRFS_VOLUME" >> "$cfg"

   IFS='|'
   read -ra SUBVOL <<< "${SUBVOLUME[@]}"
   for i in "${SUBVOL[@]}"; do
      echo "$i" | xargs >> "$cfg"
   done

   printf "\n# Post Installation Script\n" >> "$cfg"
   echo "$POST_INST" >> "$cfg"

   while IFS= read -r line
   do
      echo "$line" >> "$cfg"
   done < "$POSTINST_SCRIPT_PATH"

   echo '%end' >> "$cfg"
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

   header_firewall
   firewall_config

   header_packages
   packages

   header_users_groups
   root_account
   user_accounts
   
   header_partitioning
   ignore_disk
   clear_part
   partition_method

   header_post_inst
   post_inst

   write_config
}

main
