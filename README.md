libvirt-lvm-backuper
====================

lvm vm backup for libvirt


usage: ./lvm-backuper.sh -vm vmname -d /tmp/ -ssh "-p 22 user@example.com:/path/to/dest" 

-vm, 	--vmname 	guestname
-ssh, --ssh-location 	stream to extern server location
-d, 	--destimation 	path to backup location: /tmp
