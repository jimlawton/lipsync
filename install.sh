#!/bin/bash
# Distributed under the terms of the BSD License.
# Copyright (c) 2011 Phil Cryer phil.cryer@gmail.com
# Source https://github.com/philcryer/lipsync
 
#clear
stty erase '^?'
echo "lipsync install script"

########################################
# Check users's privileges
########################################
echo -n "* Checking user's privileges..."
if [ "$(id -u)" != "0" ]; then 
	sudo -v >/dev/null 2>&1 || { echo; echo "	ERROR: User $(whoami) is not root, and does not have sudo privileges" ; exit 1; }
else
	echo "ok"
fi

########################################
# Check Linux variant
########################################
echo -n "* Checking Linux variant..."
if [[ $(cat /etc/issue.net | cut -d' ' -f1) == "Debian" ]] || [[ $(cat /etc/issue.net | cut -d' ' -f1) == "Ubuntu" ]];then
	echo "ok"
else
	echo; echo "	ERROR: this installer was written to work with Debian/Ubuntu,"
	echo       "	it could work (tm) with your system - let us know if it does"
fi

########################################
# Check for required software
########################################
echo -n "* Checking for required software..."
type -P ssh &>/dev/null || { echo; echo "	ERROR: lipsync requires ssh-client but it's not installed" >&2; exit 1; }
#type -P ssh-copy-id &>/dev/null || { echo; echo "	ERROR: lipsync requires ssh-copy-id but it's not installed" >&2; exit 1; }
type -P rsync &>/dev/null || { echo; echo "	ERROR: lipsync requires rsync but it's not installed" >&2; exit 1; }
type -P lsyncd &>/dev/null || { echo; echo "	ERROR: lipsync requires lsyncd but it's not installed" >&2; exit 1; }
LSYNCD_VERSION=`lsyncd -version | cut -d' ' -f2 | cut -d'.' -f1`
if [ $LSYNCD_VERSION -lt '2' ]; then
	        echo; echo "    ERROR: lipsync requires lsyncd 2.x or greater, but it's not installed" >&2; exit 1
fi
echo "ok"

deploy() {
	echo "* Deploying lipsync..."
	echo -n "	> /usr/local/bin/lipsync..."
	cp bin/lipsync /usr/local/bin; chown root:root /usr/local/bin/lipsync; chmod 755 /usr/local/bin/lipsync
	cp bin/lipsync-notify /usr/local/bin; chown root:root /usr/local/bin/lipsync-notify; chmod 755 /usr/local/bin/lipsync-notify
	echo "done"

	echo -n "	> /usr/local/bin/lipsyncd..."
	if [ -x  /usr/local/bin/lsyncd ]; then
		ln -s /usr/local/bin/lsyncd /usr/local/bin/lipsyncd
	fi
	if [ -x  /usr/bin/lsyncd ]; then
		ln -s /usr/bin/lsyncd /usr/local/bin/lipsyncd
	fi
	echo "done"

	echo -n "	> /etc/init.d/lipsyncd..."
	install -m 755 etc/init.d/lipsyncd /etc/init.d/
	echo "done"

	echo -n "	> /usr/share/doc/lipsyncd..."
	if [ ! -d /usr/share/doc/lipsyncd ]; then
		mkdir /usr/share/doc/lipsyncd
	fi
	cp README* LICENSE uninstall.sh docs/* /usr/share/doc/lipsyncd
	echo "done"

	echo "lipsync installed `date`" > /home/$username/.lipsyncd/lipsyncd.log
}

start() {
	/etc/init.d/lipsyncd start; sleep 2
}

########################################
# Install lipsyncd 
########################################
if [ "${1}" = "uninstall" ]; then
	echo "	ALERT: Uninstall option chosen, all lipsync files and configuration will be purged!"
	echo -n "	ALERT: To continue press enter to continue, otherwise hit ctrl-c now to bail..."
	read continue
	eval LIPSYNCD_PROCESS=`ps aux | grep lipsyncd.pid | grep -cv grep`
	if [ $LIPSYNCD_PROCESS -eq 0 ]; then
		echo "  Stopping lipsync..."
		killall lipsyncd
	fi
	echo " Uninstalling lipsync..."
    if [ -f /usr/share/doc/lipsyncd/uninstall.sh ]; then 
		/usr/share/doc/lipsyncd/uninstall.sh
	else
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
	fi
	exit 0
else
	deploy
fi

########################################
# Start lipsyncd
########################################
echo "lipsync setup complete, starting lipsyncd..."
start

exit 0
