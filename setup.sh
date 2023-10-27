#!/bin/bash

# TODO: Append timestamp
LOG="/var/log/kickstart.log"

help() {
   echo "TODO: Add help"
   exit 1
}

abnormal_exit() {
   echo "ERROR: $1"
   help
}

# Make sure we clean up before exit
trap "pkill -P $$" EXIT

# Check for root privileges 
if [ $(whoami) != "root" ]; then
   abnormal_exit "root privileges required"
fi

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

echo "Checking for required packages ..." | tee $LOG
PKG=$(dnf list --installed podman | grep "Error:") 

if [ $PKG ]; then
   echo "Installing podman package ..." | tee $LOG
   dnf install -y podman
fi

echo "Updating kickstart config file ..." | tee $LOG









