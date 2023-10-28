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

printf "Checking for required packages ..." | tee $LOG
PKG=$(dnf list --installed podman | grep "Error:") 

if [ $PKG ]; then
   echo "Installing podman package ..." | tee $LOG
   dnf install -y podman
fi
printf "Done\n"

printf "Updating kickstart config file ..." | tee $LOG
sed -i "s/???/$DISK/g" ks.cfg
printf "Done\n"


# TODO: Check if br0 exists, if exists br + 1, check again

printf "Creating systemd bridge.netdev file ..."
cat << 'EOF' > "$SYSTEMD_NET_PATH/bridge.netdev"
[NetDev]
Name=br0
Kind=bridge
EOF
printf "Done\n"

printf "Creating systemd bridge.network file ..."
cat << 'EOF' > "$SYSTEMD_NET_PATH/bridge.network"
[Match]
Name=br0

[Network]
DHCP=both
EOF
printf "Done\n"

printf "Creating systemd bind file ..."
cat << 'EOF' > "$SYSTEMD_NET_PATH/bind.network"
[Match]
Name=enp0s25

[Network]
Bridge=br0
EOF
printf "Done\n"

printf "Restarting network ..."
systemctl restart systemd-networkd
printf "Done\n"

# TODO: Make sure kickstart network doesn't already exist
printf "Creating podman network "
sudo podman network create --subnet 192.168.50.0/24 --gateway 192.168.50.1 \
	--ip-range 192.168.50.2-192.168.50.254 --interface-name br0 --ipam-driver host-local kickstart

# Build podman image ...


# Create podman container
