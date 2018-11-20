#!/bin/bash

#salt "kvm*" cmd.run "ip link add br0 type bridge"
#salt "kvm*" cmd.run "ip link add br1 type bridge"

option1=$1
option2=$2
option3=$3

function manage_vm () {
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

function kvm01 () {
	salt "kvm01.test.local" cmd.run \
	"
		virsh $option2 ctl01.test.local;
		virsh $option2 msg01.test.local;
		virsh $option2 nal01.test.local;
		virsh $option2 dbs01.test.local;
		virsh $option2 log01.test.local;
		virsh $option2 mon01.test.local;
		virsh $option2 mtr01.test.local;
		virsh $option2 ntw01.test.local;
		virsh list --all
	"
}

function kvm02 () {
	salt "kvm02.test.local" cmd.run \
	"
		virsh $option2 dbs02.test.local;
		virsh $option2 ctl02.test.local;
		virsh $option2 nal02.test.local;
		virsh $option2 msg02.test.local;
		virsh $option2 log02.test.local;
		virsh $option2 ntw02.test.local;
		virsh $option2 mon02.test.local;
		virsh $option2 prx01.test.local;
		virsh $option2 mtr02.test.local;
		virsh list --all
	"
}

function kvm03 () {
	salt "kvm03.test.local" cmd.run \
	"
		virsh $option2 mon03.test.local;
		virsh $option2 msg03.test.local;
		virsh $option2 dbs03.test.local;
		virsh $option2 log03.test.local;
		virsh $option2 nal03.test.local;
		virsh $option2 mtr03.test.local;
		virsh $option2 ntw03.test.local;
		virsh $option2 ctl03.test.local;
		virsh $option2 prx02.test.local;
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
		printf "Enter backup name: "
		read backup_name
		echo ""
		salt "kvm*.test.local" cmd.run \
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
		salt "kvm*.test.local" cmd.run \
			"
				test /var/lib/libvirt/backup_${backup_name} && \
				cp /var/lib/libvirt/backup_${backup_name}/*.local \
				/var/lib/libvirt/images/
			"
	fi
}

if [[ $option1 == "backup" ]]; then
	backup_kvm
elif [[ $option1 == "vm" ]]; then
	if [[ $option3 == "" ]]; then
		kvm01
		kvm02
		kvm03
		echo $option1 Virtual Machines on all KVMs
	else
		if [[ $option3 == 1 ]]; then
			echo $option1 Virtual Machines on KVM01
			kvm01
		elif [[ $option3 == 2 ]]; then
			echo $option1 Virtual Machines on KVM02
			kvm02
		elif [[ $option3 == 3 ]]; then
			echo $option1 Virtual Machines on KVM02
			kvm03
		fi
	fi
fi

exit
