#!/bin/bash

# Script for managing control plane VMs

# Configuration, # you can change these parameters to match the cluster
cluster_name="test"
domain="local"
kvm_num=4 # number of KVMs in the cluster
vm_list=( ctl msg nal dbs log mon mtr ntw prx )	# vm list

# Do not touch these variables
option1=$1
option2=$2
option3=$3

function helper () {
	echo ""
	printf "Example: ./manage_cluster.shs vm destroy 1 "
	printf "issues a hard shutdown to all VMs on KVM1 "
	echo "except cfg01 "
	printf "You can use the following commands as an option one: "
	printf "vm, to manage virtual machines, you should pass standard "
	printf "virsh commands as a second option to it, "
	printf "backup, to manage images backups, you should pass "
	echo "create, list, restore, and delete commands as a second option"
	printf "You should use 1, 2, or 3 as a third options indicating "
	printf "a specific KVM node to run the command on, leaving "
	echo "the third option empty will perform the action on all KVMs"
	echo ""
}

function service_vm () {
	for vm in ${vm_list[@]}; do
		for kvm in {1..3}; do
			if ! `ping -c1 ${vm}0${kvm} > /dev/null 2>&1`; then \
				echo ${vm}0${kvm} is not responding
					if [[ $option2 == "destroy" ]]; then
						salt "kvm0*" \
						virt.destroy ${vm}0${kvm}.${cluster_name}.${domain} && sleep 10
					elif [[ $option2 == "purge" ]]; then
						salt "kvm0*" \
						virt.purge ${vm}0${kvm}.${cluster_name}.${domain} && sleep 10
					else
						exit
					fi
			fi
		done
	done
	salt "kvm*" virt.list_inactive_vms
}

function virt_module () {
	for vm in ${vm_list[@]}; do
		if [[ $vm == "prx" ]]; then
			salt "kvm0${option3}.${cluster_name}.${domain}" \
			virt.${option2} ${vm}0$(( option3-1 )).${cluster_name}.${domain} \
			$option4
		else
			salt "kvm0${option3}.${cluster_name}.${domain}" cmd.run \
			virt.${option2} ${vm}0${option3}.${cluster_name}.${domain} \
			$option4
		fi
	done
}

function manage_kvm () {
	if [[ $option2 == "list" ]]; then
		salt "kvm0${option3}.${cluster_name}.${domain}" cmd.run \
		"
			virsh list --all
		"
	else
		if [[ $option2 == "reboot" ]] || [[ $option2 == "destroy" ]] || \
				[[ $option2 == "undefine" ]] || [[ $option2 == "shutdown" ]]; then
			timeout=1;
		else
			timeout=150;
		fi
		for vm in ${vm_list[@]}; do
			if [[ $vm == "prx" ]]; then
				salt "kvm0${option3}.${cluster_name}.${domain}" cmd.run \
				"
					virsh ${option2} ${vm}0$(( option3-1 )).${cluster_name}.${domain} && \
					sleep ${timeout}
				"
			else
				salt "kvm0${option3}.${cluster_name}.${domain}" cmd.run \
				"
					virsh ${option2} ${vm}0${option3}.${cluster_name}.${domain} && \
					sleep ${timeout}
				"
			fi
		done
		salt "kvm0${option3}.${cluster_name}.${domain}" cmd.run \
		"
			virsh list --all
		"
	fi
}

function backup_kvm () {
	if [[ $option2 == "list" ]]; then
		salt "kvm*" cmd.run \
		"
			ls /root/libvirt/
		"
		exit
	fi

	if [[ $option2 == "create" ]]; then
		salt "kvm0${option3}.${cluster_name}.${domain}" cmd.run \
		"
			test ! -d /root/libvirt/backup_${backup_name} && \
			mkdir /root/libvirt/backup_${backup_name};
			cp -r /var/lib/libvirt/images/*${domain} \
			/root/libvirt/backup_${backup_name}/
		"
	elif [[ $option2 == "restore" ]]; then
		salt "kvm0${option3}.${cluster_name}.${domain}" cmd.run \
		"
			test /root/libvirt/backup_${backup_name} && \
			cp -r /root/libvirt/backup_${backup_name}/*.${domain} \
			/var/lib/libvirt/images/
		"
	elif [[ $option2 == "delete" ]]; then
		printf "Are you you sure you wanna delete ${backup_name} y/n: "
		read sure
			if [[ $sure == "y" ]]; then
				salt "kvm0${option3}" cmd.run \
				"
					rm -r /root/libvirt/backup_${backup_name}
				"
			elif [[ $sure == "n" ]];then
				exit
		fi
	fi
}



if [[ $option1 == "backup" ]]; then
	if [[ $option2 == "create" ]] || \
		[[ $option2 == "delete" ]] || [[ $option2 == "restore" ]]; then
		printf "Enter backup name: "
		read backup_name
		echo ""
	fi
	if [[ $option3 == "" ]]; then
			option3=1
		for kvm in {1..3}; do
			backup_kvm
			echo VM Images on KVM0${option3} have been ${option2}ed 
			let option3++
		done
	else
		backup_kvm
		echo VM Images on KVM0${option3} have been backed up
	fi
elif [[ $option1 == "vm" ]]; then
	if [[ $option3 == "" ]]; then
		option3=1
		for kvm in {1..3}; do
			manage_kvm &
			echo ${option2}ed Virtual Machines on KVM0${option3}
			let option3++
		done
	else
		manage_kvm
		echo ${option2}ed Virtual Machines on KVM0${option3}
	fi
elif [[ $option1 == "service" ]]; then
	service_vm
elif [[ $option1 == "help" ]] || [[ $option1 == "--help" ]]; then
	helper
elif [[ $option1 == "virt" ]]; then
	if [[ $option3 == "" ]]; then
			option4=$option3
			option3=1
		for kvm in {1..3}; do
			virt_module
			echo VM Images on KVM0${option3} have been ${option2}ed 
			let option3++
		done
else
	echo "'$option1' is a wrong command, use 'backup', 'vm' or 'help'"
fi

exit
