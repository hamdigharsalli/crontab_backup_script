#!/bin/sh

# This script runs every day at 0500 from cron on A's machine.  It backs up
# all of her files from the internal drive and external firewire storage to a
# separate firewire disk.  The intent is that the root volume on the backup
# drive will be bootable in the event of hardware failure of the internal disk
# on A's computer.

backup_username=andrealoughry
report_to_email_address=joe.loughry@stx.ox.ac.uk
from_email_address=cron@hpwtdogmom.org

start_time=`date +%s`

tempfile=/Users/$backup_username/crontab_backup_report

target_1=/
target_2=/Volumes/firewire_disk/

target_3=aloughry@hpwtdogmom.org:.webmail
target_4=aloughry@hpwtdogmom.org:public_html
target_5=aloughry@hpwtdogmom.org:secure_html

target_6=loughry@applied-math.org:.webmail
target_7=loughry@applied-math.org:public_html
target_8=loughry@applied-math.org:secure_html
target_9=loughry@applied-math.org:backups

target_10=aloughry@hpwtdogmom.org:/var/mail/hpwtdogmom.org/andrea
target_11=aloughry@hpwtdogmom.org:/var/mail/hpwtdogmom.org/miranda
target_12=loughry@applied-math.org:/var/mail/applied-math.org/joe

backup_1=/Volumes/Backup-A
backup_2=/Volumes/Backup-B
backup_3=/Volumes/Backup-C

backup_1_ofs=/Volumes/Backup-A_offsite
backup_2_ofs=/Volumes/Backup-B_offsite
backup_3_ofs=/Volumes/Backup-C_offsite

#
# If the following file exists at the root of a volume, then Spotlight
# will not waste CPU time indexing it.  This is a Mac OS X feature only.
#
disable_spotlight=.metadata_never_index

rm -f $tempfile; touch $tempfile

size_accumulator=0
bandwidth_accumulator=0
global_failure_code="S"
onsite_backup_success_code="F"
offsite_backup_success_code="F"
overall_success_code="FAILURE"

rc101="-"
rc102="-"
rc103="-"
rc104="-"
rc105="-"
rc106="-"
rc107="-"
rc108="-"
rc109="-"
rc110="-"
rc111="-"
rc112="-"
rc113="-"

rc201="-"
rc202="-"
rc203="-"
rc204="-"
rc205="-"
rc206="-"
rc207="-"
rc208="-"
rc209="-"
rc210="-"
rc211="-"
rc212="-"
rc213="-"

#
# The construct $1$2$3 is an attempt to work around a limitation in
# the usage of the report() function when the user wants to report
# very long lines.  Before, it was just $1 and if, for formatting, the
# argument was broken up into several strings which are normally
# concatenated automatically by the echo built-in, report() only saw
# the first of those strings and ignored the others.
#
# Three arguments ($1$2$3) should be enough, right?  Increase later
# if needed.
#

report()
{
	echo $1$2$3 >> $tempfile
}

blank_line()
{
	report ""
}

separator()
{
	blank_line
	report "===================================================================="
}

rsync_command="/usr/local/bin/rsync"

backup_local_disk()
{
	TARGET=$1
	BACKUP=$2
	BYTES_BACKED_UP=0

	blank_line
	report "++++ Backing up local disk $TARGET to $BACKUP"
	blank_line

	local_rsync_options="-iavzxAXE --exclude=/Volumes/"

	if [ -e $BACKUP ]; then
		if [ -e $TARGET ]; then
			rsync_command_line="$rsync_command $local_rsync_options $TARGET $BACKUP | tail -12 >> $tempfile"
			echo "\"$rsync_command_line\"" >> $tempfile
			blank_line
			eval $rsync_command_line
			RC=$?
			BYTES_BACKED_UP=`tail -1 $tempfile | cut -d ' ' -f 4`
			if [ ${#BYTES_BACKED_UP} -ne 0 ]; then
				size_accumulator=`echo $(($size_accumulator + $BYTES_BACKED_UP))`
			else
				# This inelegant line break is required by the report() function.
				report "debug129: not updating size_accumulator...BYTES_BACKED_UP" \
					" contains \"$BYTES_BACKED_UP\" and RC from rsync was $RC"
				RC=z
				global_failure_code="F"
			fi

			touch $BACKUP/$disable_spotlight
		else
			report "Warning: $TARGET does not exist"
			RC=13
			global_failure_code="F"
		fi
	else
		report "Warning: $BACKUP does not exist"
		RC=9
		global_failure_code="F"
	fi
	return $RC
}

backup_remote_disk()
{
	TARGET=$1
	BACKUP=$2
	BYTES_BACKED_UP=0
	bytes_sent=0
	bytes_rcvd=0
	total_bytes_networked=0

	blank_line
	report "---- Backing up remote disk $TARGET to $BACKUP"
	blank_line

	remote_rsync_options="-iavz"

	if [ -e $BACKUP ]; then
		rsync_command_line="$rsync_command $remote_rsync_options $TARGET $BACKUP | tail -12 >> $tempfile"
		echo "\"$rsync_command_line\"" >> $tempfile
		blank_line
		eval $rsync_command_line
		RC=$?
		BYTES_BACKED_UP=`tail -1 $tempfile | cut -d ' ' -f 4`
		bytes_sent=`tail -2 $tempfile | head -1 | cut -d ' ' -f 2`
		bytes_rcvd=`tail -2 $tempfile | head -1 | cut -d ' ' -f 6`
		if [ ${#bytes_sent} -ne  0 ]; then
			if [ ${#bytes_rcvd} -ne 0 ]; then
				total_bytes_networked=$(($bytes_sent + $bytes_rcvd))
				bandwidth_accumulator=$(($bandwidth_accumulator \
					+ $total_bytes_networked))
			fi
		else
			# The following inelegant line break is required by the report() function.
			report "debug173: not updating bandwidth_accumulator...BYTES_BACKED_UP \
contains \"$BYTES_BACKED_UP\" and RC from rsync was $RC"
			global_failure_code="F"
			RC="X"
		fi
		if [ ${#BYTES_BACKED_UP} -ne 0 ]; then
			size_accumulator=`echo $(($size_accumulator + $BYTES_BACKED_UP))`
		else
			# The following inelegant line break is required by the report() function.
			report "debug178: not updating size_accumulator...BYTES_BACKED_UP \
contains \"$BYTES_BACKED_UP\" and RC from rsync was $RC"
			RC="Y"
			global_failure_code="F"
		fi

	else
		report "Warning: $BACKUP does not exist"
		RC=9
		global_failure_code="F"
	fi
	return $RC
}

create_directory_if_it_does_not_exist()
{
	VOLUME=$1
	DIRECTORY=$2
	CREATED=0

	if [ -e $VOLUME ]; then
		if [ -d $VOLUME/$DIRECTORY ]; then
			report "...verified the existence of $VOLUME/$DIRECTORY"
		else
			report "...creating $VOLUME/$DIRECTORY"
			mkdir $VOLUME/$DIRECTORY
			chown $backup_username:$backup_username $VOLUME/$DIRECTORY
			chmod 755 $VOLUME/DIRECTORY
			CREATED=1
		fi
	fi
	return $CREATED
}

snapshot_M_email()
{
	BACKUP=$1
	backup_directory=$BACKUP/daily_archive
	snapshot_file=hpwtdogmom.org.webmail_M_only_and_mail_spool.`date +%s`.tar

	blank_line
	report "---- snapshotting M's email to $BACKUP"
	blank_line

	if [ -e $BACKUP ]; then
		tar_command_line="tar cf $backup_directory/$snapshot_file $BACKUP/hpwtdogmom.org/.webmail/users/miranda/ $BACKUP/mail_spool/"
		echo "\"$tar_command_line\"" >> $tempfile
		blank_line
		eval $tar_command_line
		RC=$?
		if [ $RC -ne 0 ]; then
			global_failure_code="F"
		else
			gzip $backup_directory/$snapshot_file
			RC=$?
			if [ $RC -ne 0 ]; then
				global_failure_code="F"
			fi
			ls -l $backup_directory | tail -n 6 | colrm 1 45 >> $tempfile
		fi
	else
		report "Warning: $BACKUP does not exist"
		RC="W"
		global_failure_code="F"
	fi
	return $RC
}

report "Starting time of this backup: `date`."

backup_device=/dev/`/usr/sbin/diskutil list | grep "Backup-[A-C]" | head -1 | cut -c 69-73`
report "Today's backup_device is " \"$backup_device\"

blank_line

#
# Show disk space at the beginning of the report, for convenience.
#

report "Disk space on local drives:"

blank_line

df -Hl >> $tempfile

#
# Mount the backup drive. It doesn't matter whether it's Backup-A or Backup-A_offsite;
# this refers to whatever physical device is plugged into the chain at that location.
#
# We do this after the `df -Hl` so we can see in the report it it was already mounted;
# the report will already tell us, implicitly, if the disk doesn't get mounted for any
# reason, by failing.
#
# Note that the command must be preceded by /usr/sbin/ or it gets silently ignored;
# this script runs as root, as verified by `whoami`.
#
# Since we don't know whether Backup-A or Backup-A_offsite is mounted today, we must
# try both; expect to get an error on at least one of the groups of three.
#

blank_line

report "Mounting backup volumes..."

/usr/sbin/diskutil mountDisk $backup_device >>$tempfile

#
# Try to backup local disks, not panicking just yet if /Volumes/Backup-A/ doesn't exist.
#

if [ -e $backup_1 ]; then

	# root volume
	backup_local_disk $target_1 $backup_1
	rc101=$?

	# firewire_disk
	backup_local_disk $target_2 $backup_3
	rc102=$?

	#
	# Backup remote files
	#

	blank_line
	report "Checking if target directories exist in the $backup_2 volume..."

	create_directory_if_it_does_not_exist $backup_2 hpwtdogmom.org
	create_directory_if_it_does_not_exist $backup_2 applied-math.org
	create_directory_if_it_does_not_exist $backup_2 mail_spool
	create_directory_if_it_does_not_exist $backup_2 daily_archive

	backup_remote_disk $target_3 $backup_2/hpwtdogmom.org/
	rc103=$?

	backup_remote_disk $target_4 $backup_2/hpwtdogmom.org/
	rc104=$?

	backup_remote_disk $target_5 $backup_2/hpwtdogmom.org/
	rc105=$?

	backup_remote_disk $target_6 $backup_2/applied-math.org/
	rc106=$?

	backup_remote_disk $target_7 $backup_2/applied-math.org/
	rc107=$?

	backup_remote_disk $target_8 $backup_2/applied-math.org/
	rc108=$?

	backup_remote_disk $target_9 $backup_2/applied-math.org/
	rc109=$?

	backup_remote_disk $target_10 $backup_2/mail_spool/
	rc110=$?

	backup_remote_disk $target_11 $backup_2/mail_spool/
	rc111=$?

	backup_remote_disk $target_12 $backup_2/mail_spool/
	rc112=$?

	#
	# snapshot M's webmail and the mail spool just in case...
	#

	snapshot_M_email $backup_2
	rc113=$?

	if [ $global_failure_code != "F" ] ; then
		onsite_backup_success_code="S"
	fi

	if [ "$global_failure_code" == "F" ] ; then
		onsite_backup_success_code="F"
	fi
fi

#
# Second backup of local disks (gets sent offsite), but only if the offsite
# disk appears to be mounted.
#

if [ -e $backup_1_ofs ]; then

	# root volume
	backup_local_disk $target_1 $backup_1_ofs
	rc201=$?

	# firewire_disk
	backup_local_disk $target_2 $backup_3_ofs
	rc202=$?

	#
	# Second backup of remote files (gets sent offsite)
	#

	blank_line
	report "Checking if target directories exist in the $backup_2_ofs volume..."

	create_directory_if_it_does_not_exist $backup_2_ofs hpwtdogmom.org
	create_directory_if_it_does_not_exist $backup_2_ofs applied-math.org
	create_directory_if_it_does_not_exist $backup_2_ofs mail_spool
	create_directory_if_it_does_not_exist $backup_2_ofs daily_archive

	backup_remote_disk $target_3 $backup_2_ofs/hpwtdogmom.org/
	rc203=$?

	backup_remote_disk $target_4 $backup_2_ofs/hpwtdogmom.org/
	rc204=$?

	backup_remote_disk $target_5 $backup_2_ofs/hpwtdogmom.org/
	rc205=$?

	backup_remote_disk $target_6 $backup_2_ofs/applied-math.org/
	rc206=$?

	backup_remote_disk $target_7 $backup_2_ofs/applied-math.org/
	rc207=$?

	backup_remote_disk $target_8 $backup_2_ofs/applied-math.org/
	rc208=$?

	backup_remote_disk $target_9 $backup_2_ofs/applied-math.org/
	rc209=$?

	backup_remote_disk $target_10 $backup_2_ofs/mail_spool/
	rc210=$?

	backup_remote_disk $target_11 $backup_2_ofs/mail_spool/
	rc211=$?

	backup_remote_disk $target_12 $backup_2_ofs/mail_spool/
	rc212=$?

	#
	# snapshot M's webmail and the mail spool just in case...
	#

	snapshot_M_email $backup_2_ofs
	rc213=$?


	if [ "$global_failure_code" != "F" ] ; then
		offsite_backup_success_code="S"
	fi

	if [ "$global_failure_code" == "F" ] ; then
		offsite_backup_success_code="F"
	fi
fi

if [ "$onsite_backup_success_code" == "S" ]; then
	overall_success_code="SUCCESS"
fi

if [ "$offsite_backup_success_code" == "S" ]; then
	overall_success_code="SUCCESS"
fi

end_time=`date +%s`
elapsed_time=$(($end_time - $start_time))

total_size=$size_accumulator
total_bandwidth_used=$bandwidth_accumulator

#
# The following bit of perl code is from
# http://www.sunmanagers.org/pipermail/summaries/2002-December/002817.html
# It formats a number with commas for display.  Retrieved on 20080202.1105
# from Google.
#
total_size_formatted=`echo $total_size | perl -pe '1 while s/(.*)(\d)(\d\d\d)/$1$2,$3/'`

total_bandwidth_used_formatted=`echo $total_bandwidth_used \
 | perl -pe '1 while s/(.*)(\d)(\d\d\d)/$1$2,$3/'`

blank_line

report "Elapsed time $elapsed_time seconds; a total of\
 $total_size_formatted bytes were synchronised;"

report "network usage was $total_bandwidth_used_formatted bytes;"

report "return codes from rsync were $rc101,$rc102,$rc103,$rc104,$rc105,\
$rc106,$rc107,$rc108,$rc109,$rc110,$rc111,$rc112,$rc113;$rc201,$rc202,$rc203,$rc204,\
$rc205,$rc206,$rc207,$rc208,$rc209,$rc210,$rc211,$rc212,$rc213:$overall_success_code"

#
# If we don't do this before unmounting the backup disks, we can't see how much
# space is left on them in the report.
#

blank_line

report "Disk space on all drives:"

blank_line

df -Hl >> $tempfile

blank_line

#
# Unmount the backup disk. We do this before the `df -Hl` so we can see if it happened.
#

report "Unmounting backup volumes..."

/usr/sbin/diskutil unmountDisk $backup_device >> $tempfile

report "Ending time of this backup: `date`."

blank_line

report "End of report."

#
# It is necessary to route the email through hpwtdogmom.org
# (Hurricane Electric) because this computer can't send email
# to Oxford (this computer doesn't have a reverse DNS entry,
# because it's on a BT DSL line).  The SSH command uses root's
# id_rsa file for public key authentication to hpwtdogmom.org
# because this script is run (via cron) by root.
#
# Remove non-printable characters from the report before mailing
# out, because hpwtdogmom.org runs on Linux and uses nail, which
# detects the ^S in the input and changes the MIME content-type
# header automatically to octet-stream, which confuses my mail
# reader on the receiving end.
#

tr -d \\023 < $tempfile | ssh aloughry@hpwtdogmom.org \
                            mail -r $from_email_address \
	-s "\"backup report `date +%Y%m%d.%H%M` rc=$rc101,$rc102,$rc103,$rc104,$rc105,$rc106,$rc107,$rc108,$rc109,$rc110,$rc111,$rc112,$rc113;$rc201,$rc202,$rc203,$rc204,$rc205,$rc206,$rc207,$rc208,$rc209,$rc210,$rc211,$rc212,$rc213:$overall_success_code\"" \
	$report_to_email_address

