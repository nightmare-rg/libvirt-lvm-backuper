#!/bin/bash - 
#===============================================================================
#
#          FILE: lvm-backuper.sh
# 
#         USAGE: ./lvm-backuper.sh vm vmname -d /tmp/ [-ssh "-p 22 user@example.com:/path/to/dest"] [-ts +%F] [-ex "storage01,storage02"] [-bw 2500]
#
#        AUTHOR: Jörg Stewig (nightmare@rising-gods.de), 
#===============================================================================

#===============================================================================
#  FUNCTION DEFINITIONS
#===============================================================================

function usage
{
    echo -e "\nusage: $0 -vm vmname -d /tmp/ [-ssh \"-p 22 user@example.com:/path/to/dest\"] [-ts +%F] [-ex \"storage01,storage02\"] [-bw 2500]\n"
    echo -e "-vm, \t--vmname \tguestname"
    echo -e "-ssh, \t--ssh-location \tstream to extern server location"
    echo -e "-d, \t--destimation \tpath to backup location: /tmp"
    echo -e "-ts, \t--timestamp \tcustom timestamp: +%F (use date --help for information)"
    echo -e "-ex, \t--exclude \texclude logical volume from backup"
    echo -e "-bw, \t--bandwidth \tlimit bandwidth for ssh upload (e.g. 2500 kb/s) \n"
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
	virsh dumpxml $VMNAME > $DEST/${VMNAME}-`date $TS`.xml
	dd if=${1}_snap bs=4M | lzop -c > $DEST/${snapname}_snap-`date $TS`.img.lzo
}

function backup-ssh
{
	echo "[INFO] starting backup to ssh destination: ${BACKUPSSH}.."
	snapname=`echo $1 | cut -d"/" -f4`
	sshCommand=`echo $BACKUPSSH | cut -d":" -f1`
	sshFolder=`echo $BACKUPSSH | cut -d":" -f2`
	virsh dumpxml $VMNAME | ssh $sshCommand "cat - > $sshFolder/${VMNAME}-`date $TS`.xml"

	if [ -n "$BW" ]; then # limit bandwidth
	    dd if=${1}_snap bs=4M | lzop -c | trickle -u $BW ssh $sshCommand "cat - > $sshFolder/${snapname}_snap-`date $TS`.img.lzo"
	else
	    dd if=${1}_snap bs=4M | lzop -c | ssh $sshCommand "cat - > $sshFolder/${snapname}_snap-`date $TS`.img.lzo"
	fi

}

function check-lzop
{
	command -v lzop >/dev/null 2>&1 || { echo >&2 "I require lzop but it's not installed. Use \"apt-get install lzop\"  to solve this problem. Aborting.."; exit 1; }
}

function check-trickle
{
    command -v trickle >/dev/null 2>&1 || { echo >&2 "I require trickle for traffic shaping but it's not installed. Use \"apt-get install trickle\"  to solve this problem. Aborting.."; exit 1; }
}

function findDeviceArray
{
    for a in "${EXCLUDE_DEVICES[@]}"
    do
        cur_dev=`echo $1 | cut -d"/" -f4`
        if [ "$a" == "$cur_dev" ]
        then
            return 0
        fi
    done

    return 1
}

control_c()
{
  echo -en "\n*** Ouch! Exiting ***\n"
  echo "You must remove lvm snapshots manually!"
  exit $?
}

#===============================================================================
#  MAIN SCRIPT
#===============================================================================

# check parameter count
if [ "$#" -lt 3 ]; then
usage
exit 1
fi

# some defaults
BACKUPSSH=''
DEST=''
VMNAME=''
TS='+%F'

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
   -ts  | --timestamp )   shift
			  			  TS=$1
                          ;;
   -ex  | --exclude )     shift
			  			  EX_DEVs=$1
                          ;;
   -bw  | --bandwidth )   shift
			  			  BW=$1
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

# check if trickle is installed if needed
if [ -n "$BW" ]; then # limit bandwidth
	    check-trickle
fi

# get devices
STRING=`virsh dumpxml $VMNAME | xmllint --xpath '/domain/devices/disk/source/@dev' - | sed s/dev=\"//g | sed s/\"//g`

IFS=', ' read -a DEVICES <<< "$STRING"

# set exclude devices
if [ -n "$EX_DEVs" ]; then
    IFS=',' read -a EXCLUDE_DEVICES <<< "$EX_DEVs"
fi

# iterate devices
for i in "${DEVICES[@]}"
do

   if findDeviceArray $i; then

    echo -e "[WARN] Skipping $i"
    continue

   else
       lvm-snap $i

       if [ -n "$DEST" ]; then # do local backup
           backup-local $i
       fi

       if [ -n "$BACKUPSSH" ]; then # do ssh backup
           backup-ssh $i
       fi

       lvm-snap-remove $i
    fi
   
done

echo -e "[INFO] LVM Backup done for $VMNAME \n"
