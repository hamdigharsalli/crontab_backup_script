#!/bin/sh

#
# This script runs every day at 0500 from cron on ATL's machine.  It backs up
# all of her files from the internal drive and external firewire storage to a
# separate firewire disk.  The intent is that the root volume on the backup
# drive will be bootable in the event of hardware failure of the internal disk
# on ATL's computer.
#
# 20080718.2240: added rsync to grab copy of everything on hpwtdogmom.org and
#	back it up to the local disk too.
#
# 20080726.2242 (rjl) extended script to backup a second copy to a second
#	physical disk.  Currently it just runs both jobs in series; the
#	script should be made smarter, to use whatever backup disk happens
#	to be available that day.  Also, the script should be simplified
#	with functions to avoid duplicated code.
#
# 20080727.1855 (rjl) When I attempted to run it with the Backup_offsite disk
#	unconnected, it started copying files into a new directory in the
#	/Volumes space.  That would have filled up / shortly.  Killed the
#	process.  Have to make it smarter.
#
# 20080727.1936 (rjl) The script now checks for the existence of every place
#	it tries to write to, and does something reasonable with return code
#	and size if it doesn't exist.
#
# 20080730.1122 (rjl) functionalising.
#
# 20080823.1600 (rjl) added applied-math.org backups.  This required setting
# 	up authorized_keys file so SSH would not ask for password, and then
#	simply adding the necessary targets.  Note: the way return codes are
#	handled is currently messy and inelegant.
#
# 20081016.1033 (rjl) There is a problem with the reporting of total number
#	of bytes synchronised.  Added debug statements.  Let it run tonight
#	and look at the results tomorrow.
#
# 20081018.1412 (rjl) The debug statements seem to have fixed the behavior
#	somehow, probably due to a side effect.  Reworked the debug statements
#	into a permanent part of the script now; testing overnight...
#
# 20081021.1257 (rjl) changed email address to joe.loughry@stx.ox.ac.uk to
#	mail the reports to.  I sure wish I had RCS instead of having to
#	save changes in comments.
#
# 20090208.1148 (rjl) add indication of 'succeeded' or 'failed' to the end
#	of the subject line based on whether or not we have a final size.
#
# 20090218.2338 (rjl) temporarily disabled backup of firewire_disk because
#	the device has failed and I don't want rsync to helpfully delete
#	all the data in the backup (not sure if it would or not, but I don't
#	want to take the chance) while Andrea is using the backup.
#
# 20090220.1838 (rjl) Changed to three backup volumes, not two.  The volumes
# 	are used as follows:
#		Backup_1 (60 GB) used for /
#		Backup_2 (40 GB) used for hpwtdogmom.org and applied-math.org
#		Backup_3 (365 GB) used for backup of firewire_disk (500 GB)
#
# 20090221.1417 (rjl) When the offsite backup disk comes back for
#	refresh, don't forget to repartition it as described above.
#
# 20090224.0013 (rjl) trying to minimize bandwidth; have turned off targets
#	6, 7, and 8 for now.
#
# 20090224.2331 (rjl) cleaned out the backups directory of
#	applied-math.org and I think the bandwidth usage problem
#	with BT is resolved now; I have turned targets 6, 7, and
#	8 back on.
#
# 20090226.1049 (rjl) procrastinating school work again.  Add a feature
#	to monitor network bandwidth usage; remove debugging statements.
#
# 20090312.1102 (rjl) The offsite backup disk has been repartitioned to the
#	new scheme now.
#
# 20090911.0912 (rjl) after getting a debug178 message, I added details to
#	the debug echo statements to get more information next time it happens.
#
# 20091118.0814 (rjl) rsync is hanging (sleep status in top) and I don't know
#	why; I am removing the tail -9 from the rsync pipeline to try to
#	monitor the problem.  Don't leave this in or it will swamp the email
#	report.
#
# 20091118.1318 (rjl) Upgraded rsync to version 3.0.6 and that seems to have
#	resolved the problem.  Run the command as /usr/local/bin/rsync now
#
# 20100107.1455 (rjl) add an automatic reboot at the end of the script
# 	because ATL wants to see if it makes her computer more responsive
#	interactively to be rebooted once a day.
#
# 20100831.1050 (rjl) The automatic reboot didn't do anything; taking it out.
#	After discovering that email in ATL's inbox does not get backed up
#	by this script, I am modifying the script to grab the mail spool file
#	that is stored in a different location in Hurricane Electric's file
#	system.
#
# 20100917.1240 (rjl) corrected a misplaced semicolon (English, not code).
#
# 20110104.0939 (rjl) changed the rsync options from -vaxE to -avzE because
# 	I think the -x option is leaving out some files I wanted to preserve.
#	Also removed the options --delete and --ignore-errors just to be
#	sure.
#
# 20110104.1428 (rjl) It appears that rsync is quitting half-way through
#	the root volume in the middle of /Users/.  This is causing ATL's
#	important files not to get backed up.  I am going to stop backing
#	up the entire / directory and change the target to /Users to see
#	if the situation improves.
#
# 20110104.1620 (rjl) Now I am not sure what's going on.  I am going to
#	remove everything on /Volumes/Backup_1_offsite/ and try rsync
#	again as root to see if it gets everything.
#
# 20110104.2230 (rjl) The problem, manifested by the following error
#	from rsync:
#
#	rsync: writefd_unbuffered failed to write 4 bytes to socket [sender]: Broken pipe (32)
#	rsync: connection unexpectedly closed (10269270 bytes received so far) [sender]
#	rsync error: error in rsync protocol data stream (code 12) at io.c(600) [sender=3.0.6]
#
#	appears to have resulted because /Volumes/Backup_1_offsite/ is
#	too small to contain the /Users/andrealoughry/Movies directory.
#
#	I cleaned that directory out of the /Volumes/Backup_1_offsite/
#	disk volume and edited the script to exclude the directory with
#	the following syntax: --exclude /Users/andrealoughry/Movies/
#
#	Re-running the backup now to test it.
#
# 20110105.0744 (rjl) Apparently we must --exclude /Volumes/ as well.
#
# 20110105.1320 (rjl) Lots of difficulty determining whether --exclude
#	actually works for more than one directory.  Currently I have
#	both --exclude= and --exclude-from= command line arguments, plus
#	an exclude file.  I think it is running now, properly excluding
#	/Users/andrealoughry/Movies/ and /Volumes/ but I am going to
#	trigger a crontab run just to check.  The real solution to this
#	problem is to upgrade the backup drives with a pair of new 1TB
#	disks and re-partition Backup_1, Backup_2 and Backup_3, plus
#	Backup_1_offsite, Backup_2_offsite and Backup_3_offsite to all
#	be large enough to hold all the files they need to hold now.
#
# 20110107.0909 (rjl) I have ordered a pair of new 1 TB disks; I will
#	install those today.  Add a feature to the script to detect
#	out-of-space-on-volume errors and remove the --exclude except
#	for --exclude /Volumes/
#
# 20110107.1909 (rjl) detecting out-of-space error on volume did not
#	work; rsync hangs in a non-useful and hard to tell way.  Instead,
#	always show a df -h report at the end of the backup report.
#
# 20110107.2001 (rjl) JWZ recommends to do the following two things to
#	make the backup disk bootable on a Mac:
#
# \begin{quote}
#   * When you first format the drive, set the partition type to "GUID",
#     not "Apple Partition Map";
#
#   * Before doing your first backup, Get Info on the drive and un-check
#     "Ignore ownership on this drive" under "Ownership and permissions." 
# \end{quote}
#	Source: http://www.jwz.org/doc/backups.html
#
# Note: it only necessary to uncheck 'Ignore ownership on this drive' on
# the first partition, used for / backup.
#
#	JWZ also recommends the following rsync options: -vaxAX
#		-v verbose
#		-a equals -rlptgoD (no -H, -A, -X)
#		-x don't cross filesystem boundaries
#		-A preserve ACLs (implies -p)
#		-X preserve extended attributes
#
#	Personally, I use /usr/local/bin/rsync -avvzxAXE --exclude=/Volumes/
#	for local disks and -avvz for remote files to be backed up locally.
#
# 20110107.2012 (rjl) added code to create required directories in Backup-B
#	if they do not already exist.
#
# 20110109.1410 (rjl) Fixed a stupid syntax error in script: backup_2
#	instead of backup2.
#
# 20110216.0803 (rjl) /Volumes/firewire_disk disappeared last night without
#	warning, so modify the script to check whether the local disk exists
#	before attempting to back it up.  Then test the script again.
#
# 20110411.1248 (rjl) changed the 'df -h' command to 'df -Hil' to report
# 	only real filesystems and include inode capacity.
#
# 20110524.1042 (rjl) in cases where the backup accumulator is not updated,
#	set the value of RC to a distinctive character and set the global
#	failure code to FAILURE.
#
# 20110902.1216 (rjl) Lately I have been using 'rsync -iavzx' options to see
#	better exactly what files are transferred by rsync.  Merge them here
#	in the local and remote rsync options and test it.
#
# 20110902.1306 (rjl) remove the '| tail -12' from after the rsync now.
#
# 20110902.1500 (rjl) all right, put the '| tail -12' back.  It's needed.
#	And re-test it.
#
# 20110902.1514 (rjl) Error 23 from rsync is 'partial transfer due to error'
#	and it's not setting the global error flag for some reason.
#
# 20111229.1732 (rjl) I got an unexpected zero return code on rc201 when that
#	disk shouldn't be there.  I am going to try initialising all the
#	return codes to 'x' before use to see if I can catch it happening.
#
#	UPDATE: I looked in /Volumes/ and could see that a directory existed
#		there called Backup_A_offsite that must have been created by
#		accident when a removable disk was unavailable.  I should
#		code around this situation, but it will be tricky to tell the
#		difference between a local directory (that ought not to be
#		there) and a removable disk that's mounted properly.  I have
#		to just ignore the problem for now and merely watch out for it.
#
# 20120112.2159 (rjl) Andrea ran out of space in her volumes today (all those
#	huge movie files from the iMovie DVDs she is always making of Irish
#	dances) and consequently I had to move things around to fit.  I added
#	a new volume called 'thesis' and symlinked it from /Volumes/firewire_disk/
#	to alleviate the space crunch on /Volumes/firewire_disk.  But now the
#	nightly backup backs up the symlink, not the files it points to, so
#	I end up with just a symlink on Backup-C pointing to the (un-backed-up)
#	volume /Volumes/thesis/ instead of getting a backup of the files.  Is
#	there an option to rsync to tell it to follow symlinks instead of just
#	noting the symlink?
#
#	I'm just going to ignore it for now.  The symlink options on rsync are
#	extremely confusing in the man page and I don't want to make a mistake
#	late at night.  It is not uncommon for rsync to delete stuff you don't
#	want deleted when its options are misunderstood.  I have a remote backup
#	of the thesis files at Hurricane Electric, and the local copy on Andrea's
#	disk is just a mirror of what I have on my CF-30 laptop.  Leave it for
#	now.  It improves the disk space crunch on Andrea's backup volumes not
#	to have duplicate copies of that data anyway.
#
# 20120113.1111 (rjl) Backup-A is special; it is supposed to be an exact mirror
#	of the root volume, for mirroring.  But without the --delete option to
#	rsync, it keeps getting bigger.  It's been running out of space lately.
#	So once in a while, manually, to clear it out, I run the rsync command
#	on it by hand with the --delete option added.  That restores the size of
#	the Backup-A to about the same size as the root volume without deleting
#	extraneous files every day, which might accidentally take something
#	that Andrea deleted but wanted back.  So I only do the --delete option
#	to rsync manually.
# 
# 20120127.1123 (rjl) added a daily snapshot of M's entire webmail box to a tar
#	file.  If she purges her mail, we'll know.
#
# 20120206.0008 (rjl) debug178 happened again, and I didn't get a FAILURE result.
#	I added another test (probably redundant, but it's very late and I'm tired)
#	to try to force it.  Waiting to see what happens tomorrow.
#
# 20121105.0822 (rjl) added a visual separator between off-site and on-site tries
#
# 20121127.1538 (rjl) while on travel, I noticed a bug: the script reports success
#	even when rsync(1L) runs out of space on the volume.  So when the
#	backup_accumulator does not get updated, change the global return code to
#	failure.  The failure also triggered another subtle bug: the report()
#	function only handled one string; fixed.
#
# 20130907.1245 (rjl) check for existence of /Volumes/Backup-A/ before displaying
# 	a bunch of panicky warning messages every time.
#
# 20130910.0814 (rjl) change "x1"-type default return codes to "-" to improve the
# 	format of the output report under normal conditions now. (Test it with one
# 	volume unmounted to see what it does in that case.)
#
# 20130910.0927 (rjl) improve failure detection code; whereas before we did not
#	change the global failure code if a disk volume was not found, because it
#	might be off-site today, now that logic is inside another test block, so
#	do change the global failure code if a disk is not mounted.
#
#	Also, add return code tracking for snapshot_M_email().
#
# 20140125.1505 (rjl) removed -i option from df call at the end of the report; it
#	makes the report too wide to read on my email client.
#
# 20140208.1313 (rjl) to defend against the CryptoLocker malware, in case it's
# 	ever ported to Mac OS X, mount the backup drives when needed and unmount
#	them when finished. CryptoLocker attacks every drive it can find, including
#	shares, but if I set these drives not to auto-mount, it shouldn't be able
#	to hurt them.
#
#	There are two potential issues with this solution: firstly, if a new disk
#	device is plugged in, this might change the mapping of /dev/disk3/ and
#	lead to mounting and unmounting the wrong volume until the name is corrected
#	in this shell script. It should be relatively harmless, however, as it is
#	unlikely that the root volume would ever be mapped to /dev/disk3/ and any
#	other random disk, if unmounted, would only cause problems with some files
#	not being available, or the screen saver or iTunes not working, or something
#	like that. This shell script, if it doesn't find the disk it's looking for,
#	by specific partition names, will gracefully fail and report. Secondly, if
#	the computer is rebooted, all physically attached disks will likely be
#	remounted automatically, and so the computer will be vulnerable to the
#	CryptoLocker malware for the next $n$ hours until this script runs again
#	and unmounts the backup drive. I think that's an acceptable risk, but I will
#	look for a way to tell the system not to mount the backup drive automatically.
#	It is harmless to do `diskutil mountDisk /dev/disk3` on a drive that is
#	already mounted; I tested it.
#
#	When starting to use this method for the first time, leave the Backup-?
#	volumes unmounted.
#
# 20140218.1938 (rjl) OK, this is interesting; /dev/disk$n$ numbers don't persist
#	across a reboot, at least not always. Today, unmounting /dev/disk3 led to
#	unmounting the Time Machine disk. Modifying the diskutil unmountDisk /dev/disk3
#	command to explicitly mount and unmount /Volumes/Backup-A/ et cetera, even
#	though I have to try mounting and unmounting volumes that might not be there
#	this particular day, and that's going to cause errors, but this is the only
#	way to do it reliably.
#
# 20140219.0857 (rjl) The preceding effort also did not work. Find the right /dev/disk$n$
#	number automatically and test it.
#
# 20140219.1051 (rjl) /usr/sbin/diskutil MUST be run with a full path to the executable
#	or the command will just silently not run.
#
# 20140221.1123 (rjl) Display the starting time at the beginning of the report so I can
#	tell the difference between reports when multiple ones get stuck in the queue.
#
#	Put this under revision control in GitHub; check for passwords in scripts first
#	(there oughtn't be any; all SSH connections are done via public key auth).
#

backup_username=andrealoughry
report_to_email_address=joe.loughry@stx.ox.ac.uk
from_email_address=cron@hpwtdogmom.org

start_time=`date +%s`

tempfile=/Users/$backup_username/.20080129.1442_crontab_backup_report

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

report_start_time=`date`
report "Start time of this backup: " $report_start_time "."

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

