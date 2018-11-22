#!/bin/bash

# Script for managing control plane VMs

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

function manage_kvm () {
	if [[ $option2 == "list" ]]; then
		salt "kvm0${option3}.test.local" cmd.run \
		"
			virsh list --all
		"
	else
		if [[ $option2 == "reboot" ]] || [[ $option2 == "destroy" ]] ||\
				[[ $option2 == "undefine" ]]; then
			timeout=1;
		else
			timeout=40;
		fi
		salt "kvm0${option3}.test.local" cmd.run \
		"
			virsh $option2 ctl0${option3}.test.local && sleep ${timeout};
			virsh $option2 msg0${option3}.test.local && sleep ${timeout};
			virsh $option2 nal0${option3}.test.local && sleep ${timeout};
			virsh $option2 dbs0${option3}.test.local && sleep ${timeout};
			virsh $option2 log0${option3}.test.local && sleep ${timeout};
			virsh $option2 mon0${option3}.test.local && sleep ${timeout};
			virsh $option2 mtr0${option3}.test.local && sleep ${timeout};
			virsh $option2 ntw0${option3}.test.local && sleep ${timeout};
			virsh $option2 prx0$(( option3-1 )).test.local;
			virsh list --all
		"
	fi
}

function backup_kvm () {
	if [[ $option2 == "list" ]]; then
		salt "kvm*" cmd.run \
		"
			ls /var/lib/libvirt/
		"
		exit
	fi

	if [[ $option2 == "create" ]]; then
		salt "kvm0${option3}.test.local" cmd.run \
		"
			test ! -d /var/lib/libvirt/backup_${backup_name} && \
			mkdir /var/lib/libvirt/backup_${backup_name};
			cp -r /var/lib/libvirt/images/*local \
			/var/lib/libvirt/backup_${backup_name}/
		"
	elif [[ $option2 == "restore" ]]; then
		salt "kvm0${option3}.test.local" cmd.run \
		"
			test /var/lib/libvirt/backup_${backup_name} && \
			cp /var/lib/libvirt/backup_${backup_name}/*.local \
			/var/lib/libvirt/images/
		"
	elif [[ $option2 == "delete" ]]; then
		printf "Are you you sure you wanna delete ${backup_name} y/n: "
		read sure
			if [[ $sure == "y" ]]; then
				salt "kvm0*" cmd.run \
				"
					rm -r /var/lib/libvirt/backup_${backup_name}
				"
			elif [[ $sure == "n" ]];then
				exit
		fi
	fi
}

if [[ $option1 == "backup" ]]; then
	if [[ $option2 == "create" ]] || [[ $option2 == "delete" ]]; then
		printf "Enter backup name: "
		read backup_name
		echo ""
	fi
	if [[ $option3 == "" ]]; then
			option3=1
		for kvm in {1..3}; do
			backup_kvm
			echo VM Images on KVM0${option3} have been backed up
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
			manage_kvm
			echo ${option2}ed Virtual Machines on KVM0${option3}
			let option3++
		done
	else
		manage_kvm
		echo ${option2}ed Virtual Machines on KVM0${option3}
	fi
elif [[ $option1 == "help" ]] || [[ $option1 == "--help" ]]; then
	helper
else
	echo "'$option1' is a wrong command, use 'backup', 'vm' or 'help'"
fi

exit
