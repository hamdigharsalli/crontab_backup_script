`crontab` backup script
=======================

Inspired by [jwz](http://www.jwz.org/blog/2007/09/psa-backups/)'s method for on-line
backups and modified in light of the [CryptoLocker](http://en.wikipedia.org/wiki/CryptoLocker)
malware to use off-line storage, this script runs nightly to synchronise `rsync` backups.

The method used to mount and unmount off-line storage is Mac OS X-specific, but this
script backs up data residing on colocated servers, Windows machines, Macs, and web
servers.

The `line_to_put_in_crontab` should be put in **root**'s crontab.

TODO
----

1. Need a script to kill a running backup.

2. Detect if another instance is already running.

