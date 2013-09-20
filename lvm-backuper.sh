#!/bin/bash
#
# lvm vm backup for libvirt
# author: Jörg Stewig <nightmare@rising-gods.de>

### functions
function usage
{
    echo -e "\nusage: $0 -vm vmname -d /tmp/ -ssh \"-p 22 user@example.com:/path/to/dest\" \n"
    echo -e "-vm, \t--vmname \tguestname"
    echo -e "-ssh, \t--ssh-location \tstream to extern server location"
    echo -e "-d, \t--destimation \tpath to backup location: /tmp\n"
}

function lvm-snap
{
	echo "[INFO] creating snapshot for ${1}.."
	snapname=`echo $1 | cut -d"/" -f4`
	lvcreate -s -L 2G -n ${snapname}_snap $1

}

function lvm-snap-remove
{
	echo "[INFO] removing snapshot for ${1}.."
	lvremove -f ${1}_snap
}

function backup-local
{
	echo "[INFO] starting backup to local destination: ${DEST}.."
	snapname=`echo $1 | cut -d"/" -f4`
	virsh dumpxml $VMNAME > $DEST/${VMNAME}-`date +%F`.xml
	dd if=${1}_snap bs=4M | lzop -c > $DEST/${snapname}_snap-`date +%F`.img.lzo
}

function backup-ssh
{
	echo "[INFO] starting backup to ssh destination: ${BACKUPSSH}.."
	snapname=`echo $1 | cut -d"/" -f4`
	sshCommand=`echo $BACKUPSSH | cut -d":" -f1`
	sshFolder=`echo $BACKUPSSH | cut -d":" -f2`
	virsh dumpxml $VMNAME | ssh $sshCommand "cat - > $sshFolder/${VMNAME}-`date +%F`.xml"
	dd if=${1}_snap bs=4M | lzop -c | ssh $sshCommand "cat - > $sshFolder/${snapname}_snap-`date +%F`.img.lzo"
}

function check-lzop
{
	command -v lzop >/dev/null 2>&1 || { echo >&2 "I require lzop but it's not installed. Use \"apt-get install lzop\"  to solve this problem. Aborting.."; exit 1; }
}

control_c()
{
  echo -en "\n*** Ouch! Exiting ***\n"
  echo "You must remove lvm snapshots manually!"
  exit $?
}

# check parameter count
if [ "$#" -lt 3 ]; then
usage
exit 1
fi

# some defaults
BACKUPSSH=''
DEST=''
VMNAME=''

# check if lzop is installed
check-lzop

# trap keyboard interrupt (control-c)
trap control_c SIGINT

# parameter while-loop
while [ "$1" != "" ];
do
    case $1 in
   -vm  | --vmname )     	  shift
                          VMNAME=$1
                	  ;;
   -d  | --destination )      shift
			  			  DEST=$1
                          ;;
   -ssh  | --ssh )        shift
			  			  BACKUPSSH=$1
                          ;;                             
   -h  | --help )         usage
                          exit
                	  ;;
   *)                     usage
                          echo "The parameter $1 is not allowed"
                          exit 1 # error
                	  ;;
    esac
    shift
done

# get devices
STRING=`virsh dumpxml $VMNAME | xmllint --xpath '/domain/devices/disk/source/@dev' - | sed s/dev=\"//g | sed s/\"//g`

IFS=', ' read -a DEVICES <<< "$STRING"

# iterate devices
for i in "${DEVICES[@]}"
do
   
   lvm-snap $i
   
   if [ -n "$DEST" ]; then # do local backup
   		backup-local $i
   fi
   
	if [ -n "$BACKUPSSH" ]; then # do ssh backup
   		backup-ssh $i
   fi
   
   lvm-snap-remove $i
   
done

echo -e "[INFO] LVM Backup done for $VMNAME \n"
