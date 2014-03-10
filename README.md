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

TODO
----

1. Need a script to kill a running backup.<sup>[*](#footnote-star)</sup>

2. Define new functions for onsite_backup() and offsite_backup() and use
them. Define new functions for interpreting success codes.<sup>[&dagger;](#footnote-dagger)</sup>

<hr/>

<a name="footnote-star"/>
<sup>*</sup> There are two processes that need to be killed: the `crontab_backup_script.sh`
and whatever long running `rsync` or `tar` or `gzip` process is currently running. It might
be reasonable to use the lockfile to indicate the PID of the currently running subprocess
in order to implement this cleanly and get the effect of a rapid shutdown when commanded to.

The problem with the above mentioned solution, though, is that it interferes with the method
I already used to save the return code of the child process; using `$!` to get the PID of
the last-launched process works if we put an ampersand on the end of the `eval` call that
launches `rsync`, but when the process is launched in the background like that, I can't get
the exit code.

The script `kill_it_kill_it_kill_it.sh` &#x263A; (under development) will eventually be used
to do the job.

<a name="footnote-dagger"/>
<sup>&dagger;</sup> There are at least two long sections of the script that could be
functionalised, in addition to all the `if` statements that interpret return codes and
report overall success or failure.

