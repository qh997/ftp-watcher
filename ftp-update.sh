#!/bin/bash

work_root=`cat "/etc/ftp-watcher/ftp-watcher.conf" \
	| grep 'ftp-work-root' | awk -F= '{print $2}' | sed -e 's/^ *//' -e 's/ *$//'`
status_file=`cat "/etc/ftp-watcher/ftp-watcher.conf" \
	| grep 'ftp-st-file' | awk -F= '{print $2}' | sed -e 's/^ *//' -e 's/ *$//'`

"/usr/local/lib/ftp-watcher/ftp-update.pl"

inotifywait -mq -e close_write "${work_root}/${status_file}" | \
	while read event; do "/usr/local/lib/ftp-watcher/ftp-update.pl"; done
