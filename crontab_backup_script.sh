#!/bin/sh

# This script runs every day at 0500 from cron on A's machine.  It backs up
# all of her files from the internal drive and external firewire storage to a
# separate firewire disk.  The intent is that the root volume on the backup
# drive will be bootable in the event of hardware failure of the internal disk
# on A's computer.

#
# First, define a bunch of functions.
#

initialise_variables()
{
	backup_username=andrealoughry
	report_to_email_address=joe.loughry@stx.ox.ac.uk
	from_email_address=cron@hpwtdogmom.org

	script_version=35

	#
	# rsync(1) options vary, so they are specified closer to where the command is
	# called. Note that rsync(1) is called with a full path so the old version
	# that Apple installs by default in the OS is not used. Hint: if the output
	# shows nothing apparently happening on a remote rsync(1)---no return code,
	# nothing---then try running it manually as 'sudo rsync...' and look for 'the
	# authenticity of this host cannot be verified...' and the usual string of
	# hex digits. Answer the question manually and it should work after that.
	#
	rsync_command="/usr/local/bin/rsync"

	#
	# ConnectTimeout=40 makes ssh be more patient about slow remote hosts;
	# BatchMode=yes keeps SSH from hanging if host is unknown;
	# StrictHostKeyChecking=no adds the key fingerprint automatically.
	#
	ssh_command="/usr/bin/ssh -o ConnectTimeout=40 -o BatchMode=yes -o StrictHostKeyChecking=no"

	#
	# -o tells ping to quit after receiving one reply packet successfully
	#
	ping_command="/sbin/ping -o"

	#
	# -PHl tells `df` not to include inodes in the report (because it makes the report
	# too wide to read on the screen); the -P must occur first in the list of options
	# or it won't have any effect on the -H like we want it to.
	#
	df_command="/bin/df -PHl"

	start_time=`date +%s`

	tempfile=/Users/$backup_username/crontab_backup_report
	lockfile=/Users/$backup_username/crontab_backup_lockfile
	killfile=/Users/$backup_username/crontab_backup_killfile

	target_1=/
	target_2=/Volumes/firewire_disk/

	target_3=aloughry@hpwtdogmom.org:.webmail
	target_4=aloughry@hpwtdogmom.org:public_html
	target_5=aloughry@hpwtdogmom.org:secure_html

	#
	# The following variable is used for debugging remote access to the
	# web server at Hurricane Electric, which sometimes doesn't respond
	# to ssh as applied-math.org but always works as xray.he.net. This
	# lets me switch the name easily without rewriting many lines of code.
	#
	applied_math_server=xray.he.net
	# applied_math_server=applied-math.org

	target_6=loughry@$applied_math_server:.webmail
	target_7=loughry@$applied_math_server:public_html
	target_8=loughry@$applied_math_server:secure_html
	target_9=loughry@$applied_math_server:backups

	target_10=aloughry@hpwtdogmom.org:/var/mail/hpwtdogmom.org/andrea
	target_11=aloughry@hpwtdogmom.org:/var/mail/hpwtdogmom.org/miranda
	target_12=loughry@$applied_math_server:/var/mail/applied-math.org/joe

	backup_1=/Volumes/Backup-A_new
	backup_2=/Volumes/Backup-B_new
	backup_3=/Volumes/Backup-C_new

	backup_1_ofs=/Volumes/Backup-A_offsite_new
	backup_2_ofs=/Volumes/Backup-B_offsite_new
	backup_3_ofs=/Volumes/Backup-C_offsite_new

	#
	# If the following file exists at the root of a volume, then Spotlight
	# will not waste CPU time indexing it.  This is a Mac OS X feature only.
	#
	disable_spotlight=.metadata_never_index

	size_accumulator=0
	bandwidth_accumulator=0
	global_failure_code="S"
	onsite_backup_success_code="F"
	offsite_backup_success_code="F"
	overall_success_code="FAILURE"
	short_success_code="F"

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
}

#
# The construct $1$2$3$4$5$6$7 below is an attempt to work around a
# limitation in the usage of the report() function when the user wants
# to report very long lines.  Before, it was just $1 and if, for
# formatting, the argument was broken up into several strings which
# are normally concatenated automatically by the echo built-in,
# report() only saw the first of those strings and ignored the others.
#
# Seven arguments ($1$2$3$4$5$6$7) should be enough, right?  Increase
# the number later if needed (this has been done several times).
#

report()
{
	echo $1$2$3$4$5$6$7 >> $tempfile
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

#
# Note that we remove the lockfile ONLY upon discovering a killfile, but not
# if we discover a lockfile. The reason is because a lockfile usually indicates
# another instance of this script is already running, and we don't want to
# interfere with that instance's lockfile.
#

check_for_killfile_before_running()
{
	if [ -e $killfile ]; then
		blank_line
		report "ALERT: killfile seen...this instance is exiting (removing lockfile and killfile)."
		rm -f $lockfile $killfile
		short_success_code="A"
		#
		# no need to unmount backup volumes; they haven't been mounted yet.
		#
		send_report_and_exit
	fi
}

check_for_killfile_while_running()
{
	if [ -e $killfile ]; then
		blank_line
		report "ALERT: killfile seen...this instance is exiting (removing lockfile and killfile)."
		rm -f $lockfile $killfile
		short_success_code="A"
		#
		# unmount backup volumes before leaving.
		#
		graceful_exit
	fi
}

initialise_lockfile()
{
	rm -f $lockfile; touch $lockfile
}

initialise_tempfile()
{
	rm -f $tempfile; touch $tempfile
}


check_for_lockfile()
{
	if [ -e $lockfile ] ; then
		report "ALERT: another instance of $0 is apparently running (or an old lockfile exists)...this instance is exiting."
		blank_line
		#
		# Don't unmount the backup volumes first; somebody else is using them. Don't
		# remove the lockfile; it belongs to somebody else. Don't bother setting the
		# alert code because this function exits the script without sending an email
		# report; then call exit to guarantee that this instance of the script won't
		# continue running in parallel.
		#
		exit 0
	else
		initialise_lockfile
	fi
}

#
# The following function extracts a word like "disk10" from the output
# of diskutil. It tries not to mistake "disk10" for "disk1".
#
# Note that /usr/sbin/diskutil must be specified with a full path or
# the command will be silently ignored. This script runs as root when
# called from crontab, as verified by `whoami`.
#

determine_backup_devices()
{
	backup_device_1=/dev/`/usr/sbin/diskutil list | grep "Backup-[A-B]" \
		| head -1 | cut -c 69-99 | cut -d s -f 1-2`
	backup_device_2=/dev/`/usr/sbin/diskutil list | grep "Backup-C" \
		| head -1 | cut -c 69-99 | cut -d s -f 1-2`
	report "Today's backup_devices are " \"$backup_device_1\" " (Backup-A, B) and " \
		\"$backup_device_2\" " (C)."
	blank_line
}

#
# Mount the backup drive. It doesn't matter whether it's Backup-A or Backup-A_offsite;
# this refers to whatever physical device is plugged into the chain at that location.
#

mount_backup_volumes()
{
	blank_line
	report "Mounting backup volumes..."
	/usr/sbin/diskutil mountDisk $backup_device_1 >> $tempfile
	/usr/sbin/diskutil mountDisk $backup_device_2 >> $tempfile
}

unmount_backup_volumes()
{
	report "Unmounting backup volumes..."
	/usr/sbin/diskutil unmountDisk $backup_device_1 >> $tempfile
	/usr/sbin/diskutil unmountDisk $backup_device_2 >> $tempfile
}

backup_local_disk()
{
	check_for_killfile_while_running

	TARGET=$1
	BACKUP=$2
	BYTES_BACKED_UP=0

	blank_line
	report "++++ Backing up local disk $TARGET to $BACKUP"
	blank_line

	if [ -e $BACKUP ]; then
		if [ -e $TARGET ]; then
			rsync_command_line="$rsync_command $local_rsync_options $TARGET $BACKUP | tail -12 >> $tempfile 2>&1"
			RC="empty(1)"
			echo "rsync(1) command line is \"$rsync_command_line\" and RC = \"$RC\" before." >> $tempfile
			blank_line
			eval $rsync_command_line
			RC=$?

			first_marker=`tail -2 $tempfile | head -1`
			second_marker=`tail -1 $tempfile`
			if grep -q "^sent.*bytes.*received.*bytes.*bytes\/sec" <<< "$first_marker" ; then
				if grep -q "^total size is.*speedup is" <<< "$second_marker" ; then
					BYTES_BACKED_UP=`tail -1 $tempfile | cut -d ' ' -f 4`
					if [ ${#BYTES_BACKED_UP} -ne 0 ]; then
						size_accumulator=`echo $(($size_accumulator + $BYTES_BACKED_UP))`
					else
						blank_line
						report "FAILURE (A): not updating size_accumulator...BYTES_BACKED_UP" \
							" contains \"$BYTES_BACKED_UP\" and RC from rsync was \"$RC\""
						RC="A"
						global_failure_code="F"
					fi
				else
					blank_line
					report "FAILURE (A2): second marker not found (was \"$second_marker\")"
					RC="A"
					global_failure_code="F"
				fi
			else
				blank_line
				report "FAILURE (A1): first marker not found (was \"$first_marker\")"
				RC="A"
				global_failure_code="F"
			fi
			touch $BACKUP/$disable_spotlight
		else
			report "Warning: $TARGET does not exist"
			RC="B"
			global_failure_code="F"
		fi
	else
		report "Warning: $BACKUP does not exist"
		RC="C"
		global_failure_code="F"
	fi

	blank_line
	report "DEBUG: BYTES_BACKED_UP = \"$BYTES_BACKED_UP\""

	return $RC
}

backup_remote_disk()
{
	check_for_killfile_while_running

	TARGET=$1
	BACKUP=$2
	BYTES_BACKED_UP=0
	bytes_sent=0
	bytes_rcvd=0
	total_bytes_networked=0

	blank_line
	report "---- Backing up remote disk $TARGET to $BACKUP"
	blank_line

	if grep -q "xray.he.net" <<< "$TARGET" ; then
		report "(using $TARGET for connection)"
		blank_line
	fi

	remote_rsync_options="-iavz --no-human-readable"

	if [ -e $BACKUP ]; then
		rsync_command_line="$rsync_command $remote_rsync_options $TARGET $BACKUP | tail -12 >> $tempfile 2>&1"
		RC="empty(2)"
		echo "rsync command line is \"$rsync_command_line\" and RC = \"$RC\" before." >> $tempfile
		blank_line
		eval $rsync_command_line
		RC=$?
		first_marker=`tail -2 $tempfile | head -1`
		second_marker=`tail -1 $tempfile`
		if grep -q "^sent.*bytes.*received.*bytes.*bytes\/sec" <<< "$first_marker" ; then
			if grep -q "^total size is.*speedup is" <<< "$second_marker" ; then
				BYTES_BACKED_UP=`tail -1 $tempfile | cut -d ' ' -f 4`
				if [ ${#BYTES_BACKED_UP} -ne 0 ]; then
					size_accumulator=`echo $(($size_accumulator + $BYTES_BACKED_UP))`
				else
					blank_line
					report "FAILURE (C): not updating size_accumulator...BYTES_BACKED_UP" \
						" contains \"$BYTES_BACKED_UP\" and RC from rsync was \"$RC\""
					RC="E"
					global_failure_code="F"
				fi
				bytes_sent=`tail -2 $tempfile | head -1 | cut -d ' ' -f 2`
				bytes_rcvd=`tail -2 $tempfile | head -1 | cut -d ' ' -f 6`
				if [ ${#bytes_sent} -ne 0 ]; then
					if [ ${#bytes_rcvd} -ne 0 ]; then
						total_bytes_networked=$(($bytes_sent + $bytes_rcvd))
						bandwidth_accumulator=$(($bandwidth_accumulator \
							+ $total_bytes_networked))
					else
						blank_line
						report "FAILURE (B2): not updating bandwidth accumulator: bytes_rcvd"
						RC="E"
						global_failure_code="F"
					fi
				else
					blank_line
					report "FAILURE (B1): not updating bandwidth accumulator: bytes_sent"
					RC="D"
					global_failure_code="F"
				fi
			else
				blank_line
				report "FAILURE (C2): second marker not found (was \"$second_marker\")"
				RC="A"
				global_failure_code="F"
			fi
		else
			blank_line
			report "FAILURE (C1): first marker not found (was \"$first_marker\")"
			RC="A"
			global_failure_code="F"
		fi
	else
		report "Warning: $BACKUP does not exist"
		RC="F"
		global_failure_code="F"
	fi

	blank_line
	report "DEBUG: BYTES_BACKED_UP = \"$BYTES_BACKED_UP\", bytes_sent = \"$bytes_sent\", bytes_rcvd = \"$bytes_rcvd\""

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
	check_for_killfile_while_running

	BACKUP=$1
	backup_directory=$BACKUP/daily_archive
	snapshot_file=hpwtdogmom.org.webmail_M_only_and_mail_spool.`date +%s`.tar

	blank_line
	report "---- snapshotting M's email to $BACKUP"
	blank_line

	if [ -e $BACKUP ]; then
		tar_command_line="tar cf $backup_directory/$snapshot_file $BACKUP/hpwtdogmom.org/.webmail/users/miranda/ $BACKUP/mail_spool/"
		RC="empty(3)"
		echo "tar command line is \"$tar_command_line\" and RC = \"$RC\" before." >> $tempfile
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
		RC="G"
		global_failure_code="F"
	fi
	return $RC
}

#
# Usage: check_free_space_on_remote_machine mirandaloughry@MKL.local
#

check_free_space_on_remote_machine()
{
	user_at_machine=$1
	machine=`echo $user_at_machine | cut -d @ -f 2`
	#
	# wake up the remote machine first (sometimes ssh silently fails if remote is not awake)
	#
	$ping_command $machine

	report "Disk space on $machine:"
	blank_line
	$ssh_command -i /Users/$backup_username/.ssh/id_rsa $user_at_machine "$df_command" >> $tempfile
}

check_for_existence_of_all_backup_volumes()
{
	if [[ ! -e $backup_1 && ! -e $backup_1_ofs ]]
	then
		blank_line
		report "Neither backup set seems to be completely available."
	fi
}

backup_to_onsite_disk()
{
	#
	# Try to backup local disks, not panicking just yet if /Volumes/Backup-A/ doesn't exist.
	#

	if [ -e $backup_3 ]; then

		# root volume
		local_rsync_options="-iavzxAXE --exclude=/Volumes/"
		backup_local_disk $target_1 $backup_1
		rc101=$?

		# firewire_disk
		local_rsync_options="-iavzxAXE"
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
}

backup_to_offsite_disk()
{
	#
	# Second backup of local disks (gets sent offsite), but only if the offsite
	# disk appears to be mounted.
	#

	if [ -e $backup_3_ofs ]; then

		# root volume
		local_rsync_options="-iavzxAXE --exclude=/Volumes/"
		backup_local_disk $target_1 $backup_1_ofs
		rc201=$?

		# firewire_disk
		local_rsync_options="-iavzxAXE"
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
}

figure_overall_success_code()
{
	if [ "$onsite_backup_success_code" == "S" ]; then
		overall_success_code="SUCCESS"
	fi

	if [ "$offsite_backup_success_code" == "S" ]; then
		overall_success_code="SUCCESS"
	fi

	if [ "$overall_success_code" == "SUCCESS" ]; then
		short_success_code="S"
	fi
}

compute_statistics()
{
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
}

format_report()
{
	report "Elapsed time $elapsed_time seconds; a total of\
	 $total_size_formatted bytes were synchronised;"

	report "network usage was $total_bandwidth_used_formatted bytes;"

	report "return codes from rsync were $rc101,$rc102,$rc103,$rc104,$rc105,\
$rc106,$rc107,$rc108,$rc109,$rc110,$rc111,$rc112,$rc113;$rc201,$rc202,$rc203,$rc204,\
$rc205,$rc206,$rc207,$rc208,$rc209,$rc210,$rc211,$rc212,$rc213:$overall_success_code"
}

email_report()
{
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

	tr -d \\023 < $tempfile | $ssh_command aloughry@hpwtdogmom.org mail -r $from_email_address \
		-s "\"backup report `date +%Y%m%d.%H%M` ($short_success_code) rc=$rc101,$rc102,\
$rc103,$rc104,$rc105,$rc106,$rc107,$rc108,$rc109,$rc110,$rc111,$rc112,$rc113;$rc201,\
$rc202,$rc203,$rc204,$rc205,$rc206,$rc207,$rc208,$rc209,$rc210,$rc211,$rc212,$rc213:\
$overall_success_code\"" $report_to_email_address
}

#
# Since bash has no goto, the way to exit gracefully in exceptional
# situations (such as when the killfile is seen) without duplicating
# this code all over is to encapsulate all the desired ending actions
# in a function that can be called whenever the killfile is seen.
#

send_report_and_exit()
{
	blank_line

	report "Ending time of this backup: `date`."

	blank_line

	report "End of report ($short_success_code)"

	email_report

	#
	# If we didn't call exit now, then the script might continue after
	# we meant to quit.
	#

	exit 0
}

graceful_exit()
{
	figure_overall_success_code
	compute_statistics

	blank_line

	format_report

	blank_line

	report "Disk space on all local drives:"

	blank_line

	#
	# If we don't do this before unmounting the backup disks, then we can't see
	# how much space is left on them in the report.
	#

	$df_command >> $tempfile

	blank_line

	unmount_backup_volumes

	send_report_and_exit
}

#===========================================================================
# Here is where the script really begins.
#===========================================================================

initialise_variables
check_for_lockfile
check_for_killfile_before_running
initialise_tempfile

report "`basename $0` version $script_version"
report "Starting time of this backup: `date`."
report "`$rsync_command --version | head -1`"
determine_backup_devices

#
# Show disk space at the beginning of the report, for convenience.
#

report "Disk space on local drives:"
blank_line
$df_command >> $tempfile

blank_line

check_free_space_on_remote_machine mirandaloughry@MKL.local

#
# We mount the backup drives after the `$df_command` so we can see in the report
# if they were already mounted; the report will already tell us, implicitly,
# that the volumes didn't get mounted for any reason, by failing.
#

mount_backup_volumes

check_for_existence_of_all_backup_volumes

backup_to_onsite_disk
backup_to_offsite_disk

#
# If we got to the end this way, then remove the lockfile (it is not removed
# by an exceptional condition exit, because those are usually due to another
# instanct of the same script running, and we don't want to interfere with
# the other script's lockfile).
#

rm -f $lockfile

graceful_exit

