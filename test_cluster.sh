#!/bin/bash

# check if arp-scan is installed

#dpkg -l | grep arp-scan
#if [ $? == 1 ]; then
#	sudo apt install arp-scan
#fi
#echo "This is a cluster testing script"



# get network interfaces names and delete lo

iface_list=$(ifconfig | cut -d ' ' -f1 | tr ':' '\n' | awk NF)

for iface in $iface_list; do
	echo $iface
	interfaces+=( $iface )
done
#echo ${interfaces[*]}
delete=(lo)
interfaces=( "${interfaces[@]/$delete}" )

# get local ip addresses and create an array

for iface_name in ${!interfaces[*]}; do
	
	ip_list=$(sudo arp-scan --interface ${interfaces[${iface_name}]} \
	--localnet --numeric --quiet --ignoredups | \
	grep -E '([a-f0-9]{2}:){5}[a-f0-9]{2}' | \
	awk '{print $1}')
	
	echo ${interfaces[iface_name]}
	for ip in $ip_list; do
		echo $ip
		ip_addresses+=( $ip )
	done
#	echo ${ip_addresses[*]}
	
done



#do something with addresses

#echo $ip_addresses
#
#for ip in ${ip_addresses[*]}; do
#	ping $ip -c2
#done
