#!/bin/bash

LOG="/var/log/kickstart.log"
SYSTEMD_NET_PATH="/etc/systemd/network/"

help() {
   echo "Usage: setup.sh [OPTIONS]"
   echo ""
   echo "-d |--disk	   disk the OS will be installed on"
   echo "    --dns         IP Address of the DNS to use"
   echo "-i |--ip-range    pool of IP addresses to use for container network."
   echo "-if|--interface   interface that will be used for macvlan or ipvlan"
   echo "-ip|--ip-address  static IP address to assign to a container"
   echo "-g |--gateway     gateway IP to use for container network"
   echo "-p |--packages    comma separated list of packages to be installed"
   echo "-s |--subnet      subnet for the container network"
   echo "-h |--help        print help"
   exit 1
}

abnormal_exit() {
   echo "ERROR: $1"
   help
}

privilege_check() { 
   if [ $(whoami) != "root" ]; then
      abnormal_exit "root privileges required"
   fi
}

parse_args() {
   while (( "$#" )); do
      case "$1" in
         -d|--disk)
	    DISK=$2
	    shift 2
	    ;;
	 --dns)
	    DNS=$2
	    shift 2
	    ;;
         -i|--ip-range) 
            IP=$2
	    shift 2
	    ;;
         -if|--interface)
	    INTERFACE=$2
	    shift 2
	    ;;
	 -ip|--ip-address)
	    IP_ADDR=$2
	    shift 2
	    ;;
         -g|--gateway)
	    GATEWAY=$2
	    shift 2 
	    ;;
         -p|--packages)
	    PACKAGES=$1
	    shift
	    ;;
         -s|--subnet)
            SUBNET=$2
	    shift 2
	    ;;
         -h|--help)
	    help
	    ;;
         -*|--*=) # unsupported flags
	   abnormal_exit "Unsupported flag $1"
	   ;;
      esac
   done
   
   # Check for required arguments
   if [ ! $DISK ] || [ ! $IP ] || [ ! $SUBNET ] || [ ! $GATEWAY ]; then
      abnormal_exit "Missing required argument(s)"
   fi
}

required_pkg_check() {
   printf "Checking for required packages ..." | tee $LOG

   PKG=$(dnf list --installed podman | grep "Error:") 

   if [ $PKG ]; then
      echo "Installing podman package ..." | tee $LOG
      dnf install -y -q podman
   fi

   printf "Done\n" | tee $LOG
}

update_config() {
   printf "Updating kickstart config file ..." | tee $LOG
   
   sed -i "s/???/$DISK/g" config/ks.cfg
   
   printf "Done\n" | tee $LOG
}

setup_container_net() {
   printf "Creating podman network ... " | tee $LOG

   if [[ ! $(podman network ls | grep -i kickstart) ]]; then
      podman network create \
	      -d ipvlan \
	      --subnet $SUBNET \
	      --gateway $GATEWAY \
              --ip-range $IP \
	      -o parent=$INTERFACE \
	      kickstart
   else
      printf "exists, skipping\n" | tee $LOG
   fi
}

create_image() {
   printf "Creating podman image ...\n" | tee $LOG

   if [[ ! $(podman images | grep -o kickstart) ]]; then

      podman build -q -t kickstart -f config/Dockerfile

      printf "Done\n" | tee $LOG
   else
      printf "exists, skipping\n" | tee $LOG
   fi
}

create_container() {
   printf "Creating podman container ...\n" | tee $LOG

   if [[ ! $(podman ps -a | grep -o kickstart) ]]; then  
   
      podman run -d -q \
	      --ip $IP_ADDR\
	      --name kickstart \
	      --network kickstart \
	      localhost/kickstart

      printf "Done\n" | tee $LOG
   elif [[ ! $(podman ps | grep -i kickstart) ]]; then
      podman start kickstart
      printf "exists, starting\n" | tee $LOG
   fi

   printf "Copying files to kickstart container ..." | tee $LOG
   
   local uuid=$(uuidgen -r)
   FILENAME="ks-"${uuid:0:8}".cfg"

   podman cp config/ks.cfg kickstart:/var/www/html/download/$FILENAME
   podman cp www/index.html kickstart:/var/www/html/index.html

   printf "Done\n" | tee $LOG
   printf "\n" | tee $LOG
   printf "Serving kickstart file on :\n" | tee $LOG
   printf "http://$IP_ADDR/download/$FILENAME\n" | tee $LOG
}

main() {
   # Clean up on EXIT
   trap "pkill -P $$" EXIT

   parse_args $@
   privilege_check
   required_pkg_check
   update_config
   setup_container_net
   create_image
   create_container
}

main $@
