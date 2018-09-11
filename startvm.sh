#!/bin/bash

salt "kvm*" cmd.run "ip link add br0 type bridge"
salt "kvm*" cmd.run "ip link add br1 type bridge"

command=$1

function kvm01 () {
salt "kvm01..local" cmd.run \
        "
        virsh $command ctl01..local;
        virsh $command dbs01..local;
        virsh $command gtw01..local;
        virsh $command msg01..local;
        virsh $command prx01..local"
}
function kvm02 () {
salt "kvm02..local" cmd.run \
        "
        virsh $command ctl02..local;
        virsh $command dbs02..local;
        virsh $command msg02..local;
        virsh $command prx02..local"
}

if [[ $2 == "" ]]; then
	kvm01
	kvm02
	echo $command Virtual Machines on all KVMs
else
	if [[ $2 == 1 ]]; then
		echo $command Virtual Machines on KVM01
		kvm01
	elif [[ $2 == 2 ]]; then
		echo $command Virtual Machines on KVM02
		kvm02
	fi
fi
