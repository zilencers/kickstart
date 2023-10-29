#!/bin/bash

# TODO: Append timestamp
LOG="/var/log/kickstart.log"
SYSTEMD_NET_PATH="/etc/systemd/network/"

help() {
   echo "TODO: Add help"
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
         -i|--ip-range) 
            IP=$2
	    shift 2
	    ;;
         -if|--interface)
	    INTERFACE=$2
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

   printf "Done\n"
}

update_config() {
   printf "Updating kickstart config file ..." | tee $LOG
   
   sed -i "s/???/$DISK/g" ks.cfg
   
   printf "Done\n"
}

setup_bridge() {
# TODO: IF ksbr0 EXISTS, DON'T CREATE ANOTHER ONE...SKIP IT
   local bridge="ksbr0"

   printf "Setting up network bridge ..."

   # NetDev 
   echo "[NetDev]" > "$SYSTEMD_NET_PATH/bridge.netdev"
   echo "Name=$bridge" >> "$SYSTEMD_NET_PATH/bridge.netdev"
   echo "Kind=bridge" >> "$SYSTEMD_NET_PATH/bridge.netdev"
   
   # Network
   echo "[Match]" > "$SYSTEMD_NET_PATH/bridge.network"
   echo "Name=$bridge" >> "$SYSTEMD_NET_PATH/bridge.network"
   echo "[Network]" >> "$SYSTEMD_NET_PATH/bridge.network"
   echo "DHCP=both" >> "$SYSTEMD_NET_PATH/bridge.network"
   
   # Bind
   echo "[Match]" > "$SYSTEMD_NET_PATH/bind.network"
   echo "Name=$INTERFACE" >> "$SYSTEMD_NET_PATH/bind.network"
   echo "[Network]" >> "$SYSTEMD_NET_PATH/bind.network"
   echo "Bridge=$bridge" >> "$SYSTEMD_NET_PATH/bind.network"

   printf "Done\n"

   printf "Restarting network ..."
   
   #systemctl restart systemd-networkd
   
   printf "Done\n"
}

setup_container_net() {
   printf "Creating podman network ... "

   if [[ ! $(podman network ls | grep -i kickstart) ]]; then
     sudo podman network create --subnet 192.168.50.0/24 --gateway 192.168.50.1 \ 
	     --ip-range 192.168.50.2-192.168.50.254 --interface-name ksbr0 --ipam-driver host-local kickstart
   else
      printf "exists, skipping\n"
   fi
}

create_image() {
   printf "Creating podman image ..."

   if [[ ! $(podman images | grep -o kickstart) ]]; then
      podman build -q -t kickstart fedora:latest .
      printf "Done\n"
   else
      printf "exists, skipping\n"
   fi
}

create_container() {

#COPY ks.cfg /var/www/html/download/ks.cfg
#COPY index.html /var/www/html/index.html
}

main() {
   # Clean up on EXIT
   trap "pkill -P $$" EXIT

   privilege_check
   parse_args $@
   required_pkg_check
   update_config
   setup_bridge
   setup_container_net
   create_image
}

main $@
