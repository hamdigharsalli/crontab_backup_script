#!/bin/sh

#
# kill_it_kill_it_kill_it.sh --- shut down a running backup launched from cron.d
#

rsync_PID=`ps ax | grep [r]sync | cut -d ' ' -f 2 | sort | head -1`
script_PID=`ps ax | grep [c]rontab_backup_script\.sh | cut -d ' ' -f 2 | sort | head -1`

#
# If we were to kill the rsync process first, the script might launch another.
#

# sudo kill $script_PID

#
# Give rsync a chance to exit gracefully.
#

# sudo kill -15 $rsync_PID
# sudo kill -2 $rsync_PID
# sudo kill -1 $rsync_PID

