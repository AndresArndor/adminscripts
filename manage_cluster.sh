#!/bin/bash

#salt "kvm*" cmd.run "ip link add br0 type bridge"
#salt "kvm*" cmd.run "ip link add br1 type bridge"

option1=$1
option2=$2
option3=$3
backup_name=1

function manage_kvm () {
	if [[ $option3 == "list" ]]; then
		salt "kvm*" cmd.run \
		"
			virsh list --all
		"
		exit
	fi
	salt "kvm0${option3}.test.local" cmd.run \
	"
		virsh $option2 ctl0${option3}.test.local;
		virsh $option2 msg0${option3}.test.local;
		virsh $option2 nal0${option3}.test.local;
		virsh $option2 dbs0${option3}.test.local;
		virsh $option2 log0${option3}.test.local;
		virsh $option2 mon0${option3}.test.local;
		virsh $option2 mtr0${option3}.test.local;
		virsh $option2 ntw0${option3}.test.local;
		virsh $option2 prx0$(( option3-1 )).test.local;
		virsh list --all
	"
}

function backup_kvm () {
	if [[ $option2 == "list" ]]; then
		salt "kvm*" cmd.run \
		"
			ls /var/lib/libvirt/
		"
		exit
	elif [[ $option2 == "create" ]]; then
		if [[ $backup_name == 1 ]]; then
			printf "Enter backup name: "
			read backup_name
			echo ""
		fi
		salt "kvm0${option3}.test.local" cmd.run \
			"
				test ! -d /var/lib/libvirt/backup_${backup_name} && \
				mkdir /var/lib/libvirt/backup_${backup_name};
				cp -r /var/lib/libvirt/images/*local \
				/var/lib/libvirt/backup_${backup_name}/
			"
	elif [[ $option2 == "restore" ]]; then
		printf "Enter backup name: "
		read backup_name
		echo ""
		salt "kvm0${option3}.test.local" cmd.run \
			"
				test /var/lib/libvirt/backup_${backup_name} && \
				cp /var/lib/libvirt/backup_${backup_name}/*.local \
				/var/lib/libvirt/images/
			"
	fi
}

if [[ $option1 == "backup" ]]; then
	if [[ $option3 == "" ]]; then
		for kvm in {1..3}; do
			option3=1
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
		for kvm in {1..3}; do
			option3=1
			manage_kvm
			echo $option2 Virtual Machines on KVM0${option3}
			let option3++
		done
	else
		manage_kvm
		echo $option2 Virtual Machines on KVM0${option3}
	fi
fi

exit
