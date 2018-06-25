libvirt-lvm-backuper
====================

lvm vm backup for libvirt


usage: ./lvm-backuper.sh -vm vmname -d /tmp/ [-pb] [-ssh "-p 22 user@example.com:/path/to/dest"] [-s3 "s3://BUCKET/PATH"] [-ts +%F] [-ex "storage01,storage02"] [-bw 2500]

-vm, 		--vmname 	    	guestname

-pb,	--progressbar	    show progressbar

-ssh,   --ssh-location 	stream to extern server location

-d, 		--destimation 	path to backup location: /tmp

-s3,    --s3            s3 bucket to upload: s3://BUCKET/PATH (you need to configure your aws key first > aws configure)

-ts,		--timestamp	    custom timestamp: +%F (use date --help for information)

-ex,    --exclude       exclude logical volume from backup

-bw,    --bandwidth     limit bandwidth for ssh upload (e.g. 2500 kb/s)


examples:

for i in $(virsh list | grep running | awk '{print $2}'); do ./lvm-backuper.sh -vm $i -pb -d /srv/lvm_backups/ -ts +%w; done
