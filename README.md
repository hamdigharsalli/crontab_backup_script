`crontab` backup script
=======================

Inspired by [jwz](http://www.jwz.org/blog/2007/09/psa-backups/)'s method for on-line
backups and modified in light of the [CryptoLocker](http://en.wikipedia.org/wiki/CryptoLocker)
malware to use off-line storage, this script runs nightly to synchronise `rsync` backups.

The method used to mount and unmount off-line storage is Mac OS X-specific, but this
script backs up data residing on co-located servers, Windows machines, Macs, and web
servers.

The `line_to_put_in_crontab` should be put in **root**'s crontab.

The backup volumes are kept unmounted; they really should be kept physically unplugged
and powered off in case CryptoLocker gets smart enough in future to try mounting disks
before it goes hunting.

GUID Partition Table scheme
---------------------------

For a disk to be bootable on the Mac, it must be formatted with the *GUID Partition
Table scheme* option in Disk Utility (or `diskutil` from the command line).

Preventing Disk Volumes from Auto-Mounting in Mac OS X
------------------------------------------------------

In Mac OS X, to stop a disk volume auto-mounting when plugged in, make an entry like
this in the `etc/fstab` file:

```
LABEL=Backup-A none hfs rw,noauto 0 2
LABEL=Backup-B none hfs rw,noauto 0 2
LABEL=Backup-C none hfs rw,noauto 0 2
LABEL=Backup-A_offsite none hfs rw,noauto 0 2
LABEL=Backup-B_offsite none hfs rw,noauto 0 2
LABEL=Backup-C_offsite none hfs rw,noauto 0 2
```

Fields in `/etc/fstab` are space or comma separated; "none" tells the automounter to
mount this filesystem in `/Volumes/` which is where we want it anyway; `rw,noauto` is
appropriate for backup volumes; the 0 is irrelevant because I don't use `dump` but
it's needed as a placeholder for the 2 which tells `fsck` to treat this volume as a
data disk but not a root volume and do check it (we could omit both numbers at the
ends of lines and the fields would default to zero, but then those disk volumes would
be skipped by `fsck`).

Not specifying disk volumes by UUID has the advantage of not spilling potentially
sensitive information here, but the `UUID=` form didn't work when I tried it anyway.

Private `Makefile`
------------------

This repository uses a new method for protecting PII such as usernames and host names
in Makefiles; it includes a `private.mk` file stored in a different repository that is
private. Unless you have access to my \verb,notes.new` repository, `make install` remains
opaque to you.

Stopping a Running Backup
-------------------------

Because this script does lots of work, and hammers the computer whilst doing it, it is
sometimes advantageous to be able to stop a running backup. To do that, first kill the
`crontab_backup_script.sh` process (as root), then kill the first-listed `rsync` process;
the following child processes will exit normally.

Note that the above method will leave an unfinished `crontab_backup_report` and not send
an email; setting the killfile will exit the script gracefully, but not send the email;
repeatedly killing `rsync` processes until there are no more will let the script send an
email report indicating failure.

TODO
----

1. Need a script to kill a running backup.<sup>[*](#footnote-star)</sup>

<hr/>

<a name="footnote-star"/>
<sup>*</sup> There are two processes that need to be killed: *firstly*, the
`crontab_backup_script.sh` and *secondly*, whatever long running `rsync` or `tar` or
`gzip` process is currently running. It might be reasonable to use the lockfile to
indicate the PID of the currently running subprocess in order to implement this
cleanly and get the effect of a rapid shutdown when commanded to, but it's not easy
to get the PID of a process when you fork one off in bash; `$!` only works for processes
launched in the background, and the alternative recommended method of using `jobs` is
fragile. It's hard to do synchronously.

Some programmes have a `--pid` option to create a file containing their PID; `rsync`
can do that if run as a daemon.

The problem with the above mentioned solution, though, is that it interferes with the method
I already used to save the return code of the child process; using `$!` to get the PID of
the last-launched process works if we put an ampersand on the end of the `eval` call that
launches `rsync`, but when the process is launched in the background like that, I can't get
the exit code.

The script `kill_it_kill_it_kill_it.sh` &#x263A; (under development) will eventually be used
to do the job.

