#!/bin/sh

RC="rsync command line is \"/usr/local/bin/rsync -iavz --no-human-readable applied_math_username@xray.he.net:.webmail /Volumes/Backup-B_offsite_new/applied-math.org/ | tail -12 >> /Users/andrealoughry/crontab_backup_report 2>&1\" and RC = \"empty(2)\" before."

echo $RC

echo

echo "FAILURE (C1): first marker not found (the last thing in the log was \"`echo $RC | sed -re 's/^(rsync command line is)( "[^"]*")/\1..."/g'`\")"

