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

```bash
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

Alternatively, `touch ~/crontab_backup_killfile` and then `kill -2` the first-listed
`rsync(1)` process.

Note that the first method will leave an unfinished `crontab_backup_report` and not send
an email; setting the killfile will exit the script gracefully, but not send the email;
repeatedly killing `rsync` processes until there are no more will let the script send an
email report indicating failure.

When the killfile method is used to stop a running script, it unmounts the backup
volumes as it exits. If the script starts and sees a `~/crontab_backup_lockfile`, it
exits gracefully but does *not* unmount the backup volumes, because somebody else
seems to be using them.

Modifying a Running Shell Script
--------------------------------

On MS-DOS, modifying a running batch file would cause weird errors. Evidently, Bash
works that way too. It is always safe to append to a running shell script, but it is
not safe to modify a running shell script in any other way (except possibly to delete
it). Stop a running shell script before attempting to do `make install` on the remote
machine.

Troubleshooting
---------------

`rsync(1)` is called with a full path so the old, out-of-date version that Apple
insists on installing with the OS is not used. Also, sometimes `cron` is a little
picky about running programmes not specified with an absolute path, and silently
does nothing.

Hint: if the output in the `crontab_backup_report` shows *nothing* apparently
happening on a remote `rsync(1)`&mdash;no return code, nothing&mdash;try running
the command manually as `sudo rsync`... and look for a message about *the authenticity
of host '...' can't be established* with the usual string of hex digits. Answer the
question manually and it should work after that.

I have no idea why that error message is not passed back to the caller, either via
the protocol or stdin.

Another problem occurred when running `rsync(1)` that at first I thought was caused
by a protocol incompatibility; version 2.6.9 (protocol version 29) is installed by
default on Mac OS X Mavericks, but version 3.0.7 (protocol version 30) was running
on the remote end. I compiled and installed version 3.1.0 (protocol version 31) on
the Mac&mdash;which required tweaking the `--human-readable` option to `rsync(1)`
because the default behaviour has changed; I had to read the source to find the name
of the `--no-human-readable` option&mdash;but then it started failing quietly with
the following error:

````
need to write 810560 bytes, iobuf.out.buf is only 65532 bytes.
rsync error: protocol incompatibility (code 2) at io.c(599) [sender=3.1.0]
rsync: [sender] write error: Broken pipe (32)
````

Interestingly, the error *only* shows up if `rsync(1)` is run manually as root like
this:

````
% sudo /usr/local/bin/rsync -iavzxAXE /Volumes/firewire_disk/ /Volumes/Backup-C_new
````

When the programme runs from cron, no error message is ever seen; it just quietly
fails and the shell script continues as if no error happened. To fix it, *downgrade*
to version 3.0.9 (protocol version 30) from source on the Mac; do not apply any
patches. The fix was recommended by ['jws'](https://alpha.app.net/jws/post/21775682).

I ran experiments on A's machine to determine whether stderr gets properly sent to
stdout when the idiom `... >> logfile 2>&1` is used in crontab. (See
[here](https://github.com/jloughry/experiments/tree/master/test_stdout_and_stderr#readme)
for more information.) It does seem to work as it should. Why doesn't `rsync(1)`
report errors when run in a shell script?

Not Using `rsync(1)` for Some Local Backups
-------------------------------------------

It appears that `rsync(1)` interacts unfavourably with A's main data drive. Because
it is (1) critical, (2) a locally mounted drive anyway, not especially in need of
care for permissions or bootability like the root drive, and (4) we don't really care
about `--delete` capability on this volume, I am going to use `cp -Rpv` instead on
this one drive, then compare `du -sh *` reports after.

Notes
-----

The 'local_rsync_options' are different for the / volume and /Volumes/firewire_disk.
The reason is because some kind of filesystem loop was causing the copy of
/Volumes/firewire_disk/ to become much greater in size than the actual volume. I
removed the `--exclude=/Volumes/` option when running rsync on /Volumes/firewire_disk/.

Also, note that command line options for `rsync(1)` are different for `/usr/local/bin/rsync`
than for the `/bin/rsync` that `man(1)` comes up with. Use `/usr/local/bin/rsync --help`
to see the real options.

TODO
----

1. Need a script to kill a running backup.<sup>[*](#footnote-star)</sup>

2. Load usernames, paths, and server names from a local file at the
beginning of the script, to avoid hard-coding private information in the
script. This has already been accomplished for the Makefile.

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

