#!/bin/bash

workfolder=$(cd `dirname $0`; pwd)

while [ 1 ]; do
	date
	${workfolder}/ftp-watcher.pl
	sleep 60
done
