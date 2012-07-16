#!/bin/sh -e
# Distributed under the terms of the BSD License.
# Copyright (c) 2011 Phil Cryer phil.cryer@gmail.com
# Source https://github.com/philcryer/lipsync

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

if [ -e $CONF_FILE ]; then
	. $CONF_FILE
fi

echo "lipsync uninstall script"
	rm -rf /usr/share/doc/lipsyncd
	rm -f /etc/init.d/lipsync*
	rm -f /etc/lipsync*
	rm -f /usr/local/bin/lipsync
	if [ -f /usr/local/bin/lipsyncd ]; then 
		unlink /usr/local/bin/lipsyncd
	fi
	rm -f /usr/local/bin/lipsync-notify
	crontab -u $USER -l | awk '$0!~/lipsync/ { print $0 }' > newcronjob
	crontab -u $USER newcronjob; rm newcronjob
exit 0


