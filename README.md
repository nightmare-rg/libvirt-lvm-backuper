libvirt-lvm-backuper
====================

lvm vm backup for libvirt


usage: ./lvm-backuper.sh -vm vmname -d /tmp/ [-ssh "-p 22 user@example.com:/path/to/dest"] [-ts +%F] [-ex "storage01,storage02"] [-bw 2500]

-vm, 		--vmname 	    	guestname

-ssh,   --ssh-location 	stream to extern server location

-d, 		--destimation 	path to backup location: /tmp

-ts,		--timestamp	    custom timestamp: +%F (use date --help for information)

-ex,    --exclude       exclude logical volume from backup

-bw,    --bandwidth     limit bandwidth for ssh upload (e.g. 2500 kb/s)


examples:

for i in `virsh list | grep running | awk '{print $2}'`; do ./lvm-backuper.sh -vm $i -d /srv/lvm_backups/ -ts +%w; done
