#!/bin/bash

# This script runs every day at 0500 from cron on A's machine.  It backs up
# all of her files from the internal drive and external firewire storage to
# a separate firewire disk.  The intent is that the root volume on the
# backup drive will be bootable in the event of hardware failure of the
# internal disk on A's computer.

source /private/var/root/crontab_backup_private_information

#
# First, define a bunch of functions.
#

initialise_variables()
{
	#
	# Login identifiers are hard-coded in the script, but authenticators
	# are not: all authentication is done by private/public key pairs
	# handled transparently (and invisibly) outside of the script.
	#

	backup_username=$private_A_username
	report_to_email_address=$private_email_address_to_send_report_to
	from_email_address=cron

	script_version=131

	#
	# Note that only alphanumeric characters and underscores are allowed
	# in identifier names in Bash. Note also that forward references are
	# not allowed in Bash; if variables like these are not set early in
	# the script, they might as well not exist.
	#

	applied_math_server=$private_applied_math_server
	applied_math_username=$private_applied_math_username

	hpwtdogmom_server=$private_hpwtdogmom_server
	hpwtdogmom_username=$private_hpwtdogmom_username

	#
	# rsync(1) options vary, so they are specified closer to where the
	# command is called. Note that rsync(1) is called with a full path so
	# the old version that Apple installs by default in the OS is not used.
	# Hint: if the output shows nothing apparently happening on a remote
	# rsync(1)---no return code, nothing---then try running it manually as
	# 'sudo rsync...' and look for 'the authenticity of this host cannot be
	# verified...' and the usual string of hex digits. Answer the question
	# manually and it should work after that.
	#
	rsync_command="/usr/local/bin/rsync"

	#
	# ConnectTimeout=40 makes ssh be more patient about slow remote hosts;
	# BatchMode=yes keeps SSH from hanging if host is unknown;
	# StrictHostKeyChecking=no adds the key fingerprint automatically.
	#
	ssh_command="/usr/bin/ssh -o ConnectTimeout=40 \
		-o BatchMode=yes -o StrictHostKeyChecking=no"

    #
    # ping -o -t 10 will test to see if the host is up, giving up after no
    # more than 10 seconds, returning 0 if the host is up, or a non-zero
    # value otherwise.
    #

    ping_command="/sbin/ping -o -t 10"

	#
	# -PHl tells `df` not to include inodes in the report (because it makes
	# the report too wide to read on the screen); the -P must occur first
	# in the list of options or it won't have any effect on the -H like we
	# want it to.
	#
	df_command="/bin/df -PHl"

	start_time=`date +%s`

	tempfile=/Users/$backup_username/crontab_backup_report
	lockfile=/Users/$backup_username/crontab_backup_lockfile
	killfile=/Users/$backup_username/crontab_backup_killfile
	summfile=/Users/$backup_username/crontab_backup_accumulator_file

	target_1=/
	target_2=/Volumes/firewire_disk/

	target_3=$hpwtdogmom_username@$hpwtdogmom_server:.webmail
	target_4=$hpwtdogmom_username@$hpwtdogmom_server:public_html
	target_5=$hpwtdogmom_username@$hpwtdogmom_server:secure_html

	target_6=$applied_math_username@$applied_math_server:.webmail
	target_7=$applied_math_username@$applied_math_server:public_html
	target_8=$applied_math_username@$applied_math_server:secure_html
	target_9=$applied_math_username@$applied_math_server:backups

	target_10=$hpwtdogmom_username@$hpwtdogmom_server:/var/mail/hpwtdogmom.org/$private_A_directory
	target_11=$hpwtdogmom_username@$hpwtdogmom_server:/var/mail/hpwtdogmom.org/$private_M_directory
	target_12=$applied_math_username@$applied_math_server:/var/mail/applied-math.org/$private_J_directory

	backup_1=/Volumes/Backup-A_new
	backup_2=/Volumes/Backup-B_new
	backup_3=/Volumes/Backup-C_new

	backup_1_ofs=/Volumes/Backup-A_offsite_new
	backup_2_ofs=/Volumes/Backup-B_offsite_new
	backup_3_ofs=/Volumes/Backup-C_offsite_new

	#
	# If the following file exists at the root of a volume, then Spotlight
	# will not waste CPU time indexing it.  This is a Mac OS X feature
	# only.
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
	echo "<p style=\"margin-top: 0; margin-bottom: 0;\">$1$2$3$4$5$6$7</p>" >> $tempfile
}

blank_line()
{
    echo "<br/>" >> $tempfile
}

separator()
{
	blank_line
    echo "<hr/>" >> $tempfile
}

function begin_preformatted
{
    echo "<pre>" >> $tempfile
}

#
# The following pair of functions bracket text in monospaced type.
#

function end_preformatted
{
    echo "</pre>" >> $tempfile
}

#
# This function verifies that external information necessary to the correct
# running of the script was found.
#
# Usage: $0
#

function did_we_get_the_secret_information_interrogative
{
    if [ -n $private_A_user_at_machine ]; then
        report "Non-public information repository successfully accessed."
    else
        blank_line
        report "Unable to continue; we are missing secret information."
        rm -f $lockfile $killfile
        short_success_code="A"
        #
        # No need to unmount backup volumes; they haven't been mounted yet.
        #
        send_report_and_exit
    fi
}

#
# This function checks to see if the script is running with root privs.
#
# Usage: $0
#

function are_we_running_as_root_interrogative
{
	if [[ $EUID -eq 0 ]]; then
		verb="is"
	else
		verb="is not"
	fi
	report "The script $verb running as root (UID=$UID, EUID=$EUID)."
}

#
# Note that we remove the lockfile ONLY upon discovering a killfile, but
# not if we discover a lockfile. The reason is because a lockfile usually
# indicates another instance of this script is already running, and we
# don't want to interfere with that instance's lockfile.
#

check_for_killfile_before_running()
{
	if [ -e $killfile ]; then
		blank_line
		report "ALERT: killfile seen...this instance is exiting " \
			"(removing lockfile and killfile)."
		rm -f $lockfile $killfile
		short_success_code="A"
		#
		# No need to unmount backup volumes; they haven't been mounted yet.
		#
		send_report_and_exit
	fi
}

check_for_killfile_while_running()
{
	if [ -e $killfile ]; then
		blank_line
		report "ALERT: killfile seen...this instance is exiting " \
			"(removing lockfile and killfile)."
		rm -f $lockfile $killfile
		short_success_code="A"
		#
		# Unmount the backup volumes before leaving.
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

    echo "<!DOCTYPE HTML>"                                   >> $tempfile
    echo "<html>"                                            >> $tempfile
    echo "    <head>"                                        >> $tempfile
    echo "        <meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\"/>" >> $tempfile
    echo "        <title>0500 Crontab Backup Report</title>" >> $tempfile
    echo "    </head>"                                       >> $tempfile
    echo "    <body>"                                        >> $tempfile
}

check_for_lockfile()
{
	if [ -e $lockfile ] ; then
		report "ALERT: another instance of $0 is apparently running " \
			"(or an old lockfile exists)...this instance is exiting."
		blank_line
		#
		# Don't unmount the backup volumes first; somebody else is using
		# them. Don't remove the lockfile; it belongs to somebody else.
		# Don't bother setting the alert code because this function exits
		# the script without sending an email report; then call exit to
		# guarantee that this instance of the script won't continue running
		# in parallel.
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
	report "Today's backup_devices are '$backup_device_1' (Backup-A, B)" \
		" and '$backup_device_2' (C)."
}

#
# This function checks to see if a remote machine is alive. If a MAC
# address and IP address are given, it sends the remote machine a
# Wake-On-LAN (WOL) packet first.
#
# Usage: $0 machine
#
# or
#
# $0 machine IP_address MAC_address
#

determine_state_of_remote_machine()
{
	m=$1

	if [[ $# -gt 1 ]]; then
		broadcast_address=$2
		mac_address=$3

		java -classpath /private/var/root WakeOnLan \
			$broadcast_address $mac_address >> $tempfile

		sleep 30
	fi

	$ping_command $m
	if [ $? -eq 0 ]; then
		report "The remote machine $m is up."
	else
		report "The remote machine $m is down."
	fi
}

#
# The following function is used to backup M's ~ to A's /
#
# rsync -i... | grep -v "^\." is supposed to show only files that changed.
#

function backup_remote_directory_to_local {
    remote_user=$1
    remote_dir=$2
    local_dir=$3

    remote_rsync_options="-iavz --no-human-readable \
        -e \"$ssh_command -i /Users/$backup_username/.ssh/id_rsa\""

    report "Backing up M's ~ to A's /"
    blank_line

    rsync_command_line="$rsync_command $remote_rsync_options \
        $remote_user:$remote_dir/\* $local_dir | grep -v '^\.' | tail -12 >> $tempfile 2>&1"

    report "The rsync_command_line was \"$rsync_command_line\"."
    blank_line

    eval $rsync_command_line
    RC_from_rsync=$?

    blank_line
    report "The return code from rsync(1) was \"$RC_from_rsync\"."
    blank_line
    report "Done backing up M's ~ to A's /"
}

#
# Mount the backup drive. It doesn't matter whether it's Backup-A
# or Backup-A_offsite; this refers to whatever physical device is
# plugged into the chain at that location.
#
# We can't use the report() function here because it compresses blank
# spaces out of the output for some reason, probably bash parsing the
# line.
#

mount_backup_volumes()
{
    begin_preformatted
	/usr/sbin/diskutil quiet mountDisk $backup_device_1 >> $tempfile
	/usr/sbin/diskutil mountDisk $backup_device_2       >> $tempfile
    end_preformatted
}

unmount_backup_volumes()
{
    begin_preformatted
	/usr/sbin/diskutil unmountDisk $backup_device_1     >> $tempfile
	/usr/sbin/diskutil unmountDisk $backup_device_2     >> $tempfile
    end_preformatted
}

backup_local_disk()
{
	check_for_killfile_while_running

	TARGET=$1
	BACKUP=$2
	bytes_backed_up=0

	blank_line
	report "++++ Backing up local disk $TARGET to $BACKUP"
	blank_line

	if [ -e $BACKUP ]; then
		if [ -e $TARGET ]; then
			rsync_command_line="$rsync_command $local_rsync_options $TARGET $BACKUP | tail -12 >> $tempfile 2>&1"
			RC="empty(1)"
			report "rsync(1) command line is \"$rsync_command_line\" and " \
				"RC was \"$RC\" before the rsync command was executed"
			blank_line
            begin_preformatted
			eval $rsync_command_line
			RC=$?
            end_preformatted

			first_marker=`tail -2 $tempfile | head -1`
			second_marker=`tail -1 $tempfile`
			if grep -q "sent.*bytes.*received.*bytes.*bytes\/sec" <<< "$first_marker" ; then
				if grep -q "total size is.*speedup is" <<< "$second_marker" ; then
					bytes_backed_up=`tail -1 $tempfile | cut -d ' ' -f 4`
					if [ ${#bytes_backed_up} -ne 0 ]; then
						size_accumulator=`echo $(($size_accumulator + $bytes_backed_up))`
					else
						blank_line
						report "FAILURE (A): not updating size_accumulator...bytes_backed_up" \
							" contains \"$bytes_backed_up\" and RC from rsync was \"$RC\""
						RC="A"
						global_failure_code="F"
					fi
				else
					blank_line
					report "FAILURE (A2): second marker not found (the " \
						"last log entry was \"`echo $second_marker " \
						| sed -e 's/^\(rsync command line is\)\( "[^"]*".*$\)/\1..."/g'`]"
					RC="A"
					global_failure_code="F"
				fi
			else
				blank_line
				report "FAILURE (A1): first marker not found (first " \
                    "marker contains \"$first_marker\") [the last " \
					"log entry was \"`echo $first_marker \
					| sed -e 's/^\(rsync command line is\)\( "[^"]*".*$\)/\1..."/g'`]"
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

	return $RC
}

backup_remote_disk()
{
	check_for_killfile_while_running

	TARGET=$1
	BACKUP=$2
	bytes_backed_up=0
	bytes_sent=0
	bytes_rcvd=0
	total_bytes_networked=0

	blank_line
	report "---- Backing up remote disk $TARGET to $BACKUP"
	blank_line

	remote_rsync_options="-iavz --no-human-readable --out-format='%l %n'"

	if [ -e $BACKUP ]; then
		rsync_command_line="$rsync_command $remote_rsync_options $TARGET $BACKUP | tail -12 >> $tempfile 2>&1"
		RC="empty(2)"
		report "rsync command line is \"$rsync_command_line\" and RC " \
			"was \"$RC\" before the rsync command was executed."
		blank_line
        begin_preformatted
		eval $rsync_command_line
		RC=$?
        end_preformatted
		first_marker=`tail -2 $tempfile | head -1`
		second_marker=`tail -1 $tempfile`
		if grep -q "sent.*bytes.*received.*bytes.*bytes\/sec" <<< "$first_marker" ; then
			if grep -q "total size is.*speedup is" <<< "$second_marker" ; then
				bytes_backed_up=`tail -1 $tempfile | cut -d ' ' -f 4`
				if [ ${#bytes_backed_up} -ne 0 ]; then
					size_accumulator=`echo $(($size_accumulator + $bytes_backed_up))`
				else
					blank_line
					report "FAILURE (C): not updating size_accumulator" \
						"...bytes_backed_up contains \"$bytes_backed_up\"" \
						" and RC from rsync was \"$RC\""
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
						report "FAILURE (B2): not updating bandwidth " \
							"accumulator (bytes_rcvd)"
						RC="E"
						global_failure_code="F"
					fi
				else
					blank_line
					report "FAILURE (B1): not updating bandwidth " \
						"accumulator (bytes_sent)"
					RC="D"
					global_failure_code="F"
				fi
			else
				blank_line
				report "FAILURE (C2): second marker not found [the last " \
					"thing in the log before it stopped was \"`echo \
					$second_marker | sed -e 's/^\(rsync command line is\)\( "[^"]*".*$\)/\1..."/g'`]."
				RC="A"
				global_failure_code="F"
			fi
		else
			blank_line
			report "FAILURE (C1): first marker not found (first " \
                "marker contains \"$first_marker\") [the last " \
				"thing in the log before it stopped was \"`echo \
				$first_marker | sed -e 's/^\(rsync command line is\)\( "[^"]*".*$\)/\1..."/g'`]."
			RC="A"
			global_failure_code="F"
		fi
	else
		report "Warning: $BACKUP does not exist"
		RC="F"
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
	check_for_killfile_while_running

	BACKUP=$1
	backup_directory=$BACKUP/daily_archive
	snapshot_file=hpwtdogmom.org.webmail_M_only_and_mail_spool.`date +%s`.tar

	blank_line
	report "---- snapshotting M's email to $BACKUP"
	blank_line

	if [ -e $BACKUP ]; then
		tar_command_line="tar cf $backup_directory/$snapshot_file \
$BACKUP/hpwtdogmom.org/.webmail/users/$private_M_directory/ $BACKUP/mail_spool/"
		RC="empty(3)"
		report "tar command line is \"$tar_command_line\" and RC was " \
			"\"$RC\" before the tar command was executed."
		blank_line

        begin_preformatted
		eval $tar_command_line
		RC=$?
        end_preformatted

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
# Usage: $0 user@machine
#

check_free_space_on_remote_machine()
{
	user_at_machine=$1
	machine=`echo $user_at_machine | cut -d @ -f 2`

	#
	# Only try SSH if ping works first.
	#

	$ping_command $machine
	if [ $? -eq 0 ]; then
		report "Disk space on $machine:"
		blank_line
        begin_preformatted
        $ssh_command -i /Users/$backup_username/.ssh/id_rsa \
			$user_at_machine "$df_command" >> $tempfile 2>&1
        end_preformatted
	fi
}

#
# Usage: $0 user@machine
#

put_remote_machine_back_to_sleep()
{
    user_at_machine=$1
	machine=`echo $user_at_machine | cut -d @ -f 2`

    $ping_command $machine
    if [ $? -eq 0 ]; then
        $ssh_command -i /Users/$backup_username/.ssh/id_rsa \
            $user_at_machine "pmset sleepnow" >> $tempfile 2>&1
    fi
    sleep 60
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
	# Try to backup local disks, not panicking just yet
	# if /Volumes/Backup-A/ doesn't exist.
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
		report "Checking if target directories exist " \
			"in the $backup_2 volume..."

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
	# Second backup of local disks (gets sent offsite), but only if the
	# offsite disk appears to be mounted.
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
		report "Checking if target directories exist " \
			"in the $backup_2_ofs volume..."

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
	# It formats a number with commas for display.
	#
	total_size_formatted=`echo $total_size \
		| perl -pe '1 while s/(.*)(\d)(\d\d\d)/$1$2,$3/'`

	total_bandwidth_used_formatted=`echo $total_bandwidth_used \
		| perl -pe '1 while s/(.*)(\d)(\d\d\d)/$1$2,$3/'`

	#
	# The following Perl code was adapted from the web site
	# http://www.perlmonks.org/?node_id=101511
	#

	formatted_elapsed_time=`echo $elapsed_time | perl -e 'my $sec = <>; \
		printf "%dd %dh %dm %ds", \
		int($sec/(24*60*60)), ($sec/(60*60))%24, ($sec/60)%60, $sec%60;'`
}

format_report()
{
	formatted_return_codes="$rc101,$rc102,$rc103,$rc104,$rc105,$rc106,\
$rc107,$rc108,$rc109,$rc110,$rc111,$rc112,$rc113;$rc201,$rc202,$rc203,\
$rc204,$rc205,$rc206,$rc207,$rc208,$rc209,$rc210,$rc211,$rc212,$rc213:\
$overall_success_code"

	report "Elapsed time $elapsed_time seconds ($formatted_elapsed_time)" \
		"; a total of $total_size_formatted bytes" \
        " were synchronised. Network usage was " \
		"$total_bandwidth_used_formatted bytes. Return codes from the" \
	    " rsync programme were $formatted_return_codes."
}

email_report()
{
	#
	# It is necessary to route the email through the web server
	# (Hurricane Electric) because this computer can't send email
	# to Oxford (this computer doesn't have a reverse DNS entry,
	# because it's on a BT DSL line).  The SSH command uses root's
	# id_rsa file for public key authentication to Hurricane Electric's
	# server because this script is run (via cron) by root.
	#
	# Remove non-printable characters (octal 023) from the report before
	# mailing out, because Hurricane Electric's server runs on Linux and
	# uses nail, which detects the ^S in the input and changes the MIME
	# content-type header automatically to octet-stream, which confuses
	# my mail reader on the receiving end.
	#

    echo "    </body>" >> $tempfile
    echo "</html>"     >> $tempfile

	tr -d \\023 < $tempfile \
		| $ssh_command $applied_math_username@$applied_math_server \
			"mail \
				-a \"From: Backup Server <$private_originating_email_address>\" \
                -a \"Content-type: text/html\" \
				-s \"backup report `date +%Y%m%d.%H%M` ($short_success_code) \
rc=$formatted_return_codes in $formatted_elapsed_time\" \
				$report_to_email_address"
}

#
# Draws a bar chart
#
# Usage: bar_chart "percentage label"
#
# (The arguments are together in one unit because of the way
# the function is called from within bash with "while read".)
#

function bar_chart
{
    percentage=`echo $1 | cut -d ' ' -f 1`
    label=`echo $1 | cut -d ' ' -f 2 | basename`

    bar_chart_width=40
    scale_factor=$(expr 100 / $bar_chart_width)

    if [[ $percentage -lt 0 ]]; then
        echo "Usage: $0 0 -le percentage -le 100"
        exit 1
    fi

    length_of_bar=$(expr $percentage / $scale_factor)
    remaining_length=$(expr 100 / $scale_factor - $length_of_bar)

    if [ $length_of_bar -ge 1 ]; then
        for i in `seq 1 $length_of_bar`; do
            /bin/echo -n "█"
        done
    fi

    if [ $remaining_length -ge 1 ]; then
        for i in `seq 1 $remaining_length`; do
            /bin/echo -n "░"
        done
    fi

    %
    % End the line.
    %

    echo
}

#
# Display a bar chart showing the percentage free on all mounted volumes.
#

function show_disk_space_graphically
{
    $df_command | tr -s ' ' | cut -d ' ' -f 5,6 \
        | tr -d '%' | sed '1d' \
        | while read -r line; do bar_chart "$line"; done
}

#
# Usage: $0 user@machine (TODO: refactor this fn to call previous one)
#

function show_disk_space_graphically_on_remote_machine
{
	user_at_machine=$1
	machine=`echo $user_at_machine | cut -d @ -f 2`

    $ssh_command -i /Users/$backup_username/.ssh/id_rsa \
        $user_at_machine "$df_command" | tr -s ' ' \
        | cut -d ' ' -f 5,6 | tr -d '%' | sed '1d' \
        | while read -r line; do bar_chart "$line"; done
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

    #
    # In bash, if the file does not exist, it is created.
    #
    echo "$formatted_return_codes: $formatted_elapsed_time on `date +\"%F at %R %Z\"`" >> $summfile

	blank_line

	report "Disk space on all local drives:"

	blank_line

	#
	# If we don't do this before unmounting the backup disks, then we
	# can't see how much space is left on them in the report.
	#
	# We can't use the report() function here because it compresses blank
	# spaces out of the output.
	#

    begin_preformatted
	$df_command >> $tempfile
    end_preformatted

    blank_line
    show_disk_space_graphically >> $tempfile

	blank_line

	unmount_backup_volumes

	send_report_and_exit
}

#==========================================================================
# Here is where the script really begins.
#==========================================================================

initialise_variables
check_for_lockfile
check_for_killfile_before_running
initialise_tempfile
report "This is the 0500 daily crontab backup report."
blank_line
did_we_get_the_secret_information_interrogative
are_we_running_as_root_interrogative

report "This is `basename $0` version $script_version."
report "The nodename of this machine is `uname -n`."
report "Starting time of this backup is `date`."
report "We are using `$rsync_command --version | head -1`."
determine_backup_devices
determine_state_of_remote_machine $applied_math_server
determine_state_of_remote_machine $hpwtdogmom_server
determine_state_of_remote_machine $private_M_machine 192.168.0.255 $private_M_machine_MAC_address
blank_line

#
# Show disk space at the beginning of the report, for convenience.
#
# We can't use the report() function here as it compresses blank spaces out
# of the output of df.
#

report "Disk space on local drives:"

blank_line
begin_preformatted
$df_command >> $tempfile
end_preformatted

blank_line
show_disk_space_graphically >> $tempfile

blank_line
check_free_space_on_remote_machine $private_M_user_at_machine

blank_line
show_disk_space_graphically_on_remote_machine $private_M_user_at_machine >> $tempfile

blank_line
backup_remote_directory_to_local \
    $private_M_user_at_machine /Users/$private_M_username $private_M_desktop_backup

blank_line
put_remote_machine_back_to_sleep $private_M_user_at_machine

determine_state_of_remote_machine $private_M_machine
blank_line

#
# We mount the backup drives after the `$df_command` so we can see in the
# report if they were already mounted; the report will already tell us,
# implicitly, that the volumes didn't get mounted for any reason, by
# failing.
#

mount_backup_volumes

check_for_existence_of_all_backup_volumes

backup_to_onsite_disk
backup_to_offsite_disk

#
# If we got to the end this way, then remove the lockfile (it is not
# removed by an exceptional condition exit, because those are usually due
# to another instanct of the same script running, and we don't want to
# interfere with the other script's lockfile).
#

rm -f $lockfile

graceful_exit

