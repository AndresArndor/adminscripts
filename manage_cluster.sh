#!/bin/bash

#salt "kvm*" cmd.run "ip link add br0 type bridge"
#salt "kvm*" cmd.run "ip link add br1 type bridge"

command=$1
KVM=$2

function kvm01 () {
salt "kvm01.test.local" cmd.run \
  "
 virsh $command ctl01.test.local;
 virsh $command msg01.test.local;
 virsh $command nal01.test.local;
 virsh $command dbs01.test.local;
 virsh $command log01.test.local;
 virsh $command mon01.test.local;
 virsh $command mtr01.test.local;
 virsh $command ntw01.test.local;
 virsh list --all
	"
}
function kvm02 () {
salt "kvm02.test.local" cmd.run \
  "
 virsh $command dbs02.test.local;
 virsh $command ctl02.test.local;
 virsh $command nal02.test.local;
 virsh $command msg02.test.local;
 virsh $command log02.test.local;
 virsh $command ntw02.test.local;
 virsh $command mon02.test.local;
 virsh $command prx01.test.local;
 virsh $command mtr02.test.local;
 virsh list --all
	"
}

function kvm03 () {
salt "kvm03.test.local" cmd.run \
  " 
 virsh $command mon03.test.local;
 virsh $command msg03.test.local;
 virsh $command dbs03.test.local;
 virsh $command log03.test.local;
 virsh $command nal03.test.local;
 virsh $command mtr03.test.local;
 virsh $command ntw03.test.local;
 virsh $command ctl03.test.local;
 virsh $command prx02.test.local;
 virsh list --all
	"
}

function backup_kvm () {
salt "kvm0*.test.local" cmd.run \
  "
 echo Backup listing:
 ls /var/lib/libvirt/*.backup
 echo 
 echo Enter backup name:
 read backup_name
 test ! -d /var/lib/libvirt/images_${backup_name}.back && mkdir /var/lib/libvirt/images_${backup_name}.back;
 cp -r /var/lib/libvirt/images/*local /var/lib/libvirt/images_${backup_name}.back/
  "
}

function roll_back () {
salt "kvm0*.test.local" cmd.run \
  "
 echo Backup listing:
 ls /var/lib/libvirt/*.backup
 echo 
 echo Enter backup name:
 read backup_name
 test -d /var/lib/libvirt/images_${backup_name}.back && 
 cp -r /var/lib/libvirt/images_${backup_name}.back/* /var/lib/libvirt/images/
  "
}

if [[ $command == "backup" ]]; then
	echo STARTING BACKING UP VMs
	backup_kvm
	echo BACKUP is DONE
	exit
elif [[ $command == "rollback" ]]; then
	echo STARTING ROLLING VMs BACK
	roll_back
	echo ROLL BACK is FINISHED
	exit
fi

if [[ $2 == "" ]]; then
	kvm01
	kvm02
	kvm03
	echo $command Virtual Machines on all KVMs
else
	if [[ $2 == 1 ]]; then
		echo $command Virtual Machines on KVM01
		kvm01
	elif [[ $2 == 2 ]]; then
		echo $command Virtual Machines on KVM02
		kvm02
	elif [[ $2 == 3 ]]; then
		echo $command Virtual Machines on KVM02
		kvm03
	fi
fi
