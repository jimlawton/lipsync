#!/bin/bash
# Distributed under the terms of the BSD License.
# Copyright (c) 2011 Phil Cryer phil.cryer@gmail.com
# Source https://github.com/philcryer/lipsync

CFGDIR=${HOME}/.lipsyncd
LOGFILE=${CONF_DIR}/lipsyncd.log
EXCLUDES=${CONF_DIR}/excludes
CFGFILE=${CONF_DIR}/lipsync.conf
 
#clear
stty erase '^?'
echo "lipsync install script"

########################################
# Define functions
########################################
questions(){
	echo -n "> SERVER: IP or domainname: "
	read remote_server
	if [ -z $remote_server ]; then
		echo "Error: you must specify a remote server!"
		exit 1
	fi

	echo -n "> SERVER: SSH port [22]: "
	read port
	if [ -z $port ]; then
		port=22
	fi
	
	echo -n "> CLIENT: directory to be synced: "
	read lipsync_dir_local
	if [ -z $lipsync_dir_local ]; then
		echo "Error: you must specify a local directory!"
		exit 1
	fi

	echo -n "> SERVER: remote directory to be synced: "
	read lipsync_dir_remote
	if [ -z $lipsync_dir_remote ]; then
		echo "Error: you must specify a remote directory!"
		exit 1
	fi
}

ssh_keygen(){
  if ssh -i ${HOME}/.ssh/id_dsa -p ${port} -o "KbdInteractiveAuthentication=no" -o "PasswordAuthentication=no" ${USER}@${remote_server} echo "hello" > /dev/null
  then
    echo "	ssh key exists here and on server, skipping key generation and transfer steps"
    return
  else
  	if [ -f '${HOME}/.ssh/id_dsa' ]; then
  		echo "* Existing SSH key found for ${USER} backing up..."
  		mv ${HOME}/.ssh/id_dsa ${HOME}/.ssh/id_dsa-OLD
  		if [ $? -eq 0 ]; then
  			echo "done"
  		else
  			echo; echo "	ERROR: there was an error backing up the SSH key"; exit 1
  		fi
  	fi
  
  	echo "* Checking for an SSH key for ${USER}..."
  	if [ -f ${USER}/.ssh/id_dsa ]; then
  		echo "* Existing key found, not creating a new one..."
  	else
  		echo -n "* No existing key found, creating SSH key for ${USER}..."
  		ssh-keygen -q -N '' -f ${HOME}/.ssh/id_dsa
  		if [ $? -eq 0 ]; then
  		chown -R $USER:$USER ${HOME}/.ssh
  			echo "done"
  		else
  			echo; echo "	ERROR: there was an error generating the ssh key"; exit 1
  		fi
  	fi
  	
  	echo "* Transferring ssh key for ${USER} to ${remote_server} on port ${port} (login as $USER now)..."; 

	if which ssh-copy-id &> /dev/null; then
  		ssh-copy-id -i ${HOME}/.ssh/id_dsa.pub '-p ${port} ${USER}@${remote_server}' >> /dev/null
  		if [ $? -eq 0 ]; then
  			X=0	#echo "done"
  		else
  			echo
			echo "	ERROR: there was an error transferring the ssh key"; 
			exit 1 
		fi
	else
		cat ${HOME}/.ssh/id_dsa.pub | ssh $remote_server -p ${port} 'cat - >> ${HOME}/.ssh/authorized_keys' >> /dev/null
  		if [ $? -eq 0 ]; then
  			X=0	#echo "done"
  		else
  			echo
			echo "	ERROR: there was an error transferring the ssh key"; 
			exit 1 
		fi
	fi

  	echo -n "* Setting permissions on the ssh key for ${USER} on ${remote_server} on port ${port}..."; 
  	SSH_AUTH_SOCK=0 ssh ${remote_server} -p ${port} 'chmod 700 .ssh'
  	if [ $? -eq 0 ]; then
  		echo "done"
  	else
  		echo; echo "	ERROR: there was an error setting permissions on the ssh key for ${USER} on ${remote_server} on port ${port}..."; exit 1
  	fi
  fi
}

build_conf(){
	echo -n "* Creating lipsyncd config..."
	sed etc/lipsyncd_template > etc/lipsyncd \
		-e 's|LSLOCDIR|'$lipsync_dir_local/'|g' \
		-e 's|LSUSER|'$USER'|g' \
		-e 's|LSPORT|'$port'|g' \
		-e 's|LSREMSERV|'$remote_server'|g' \
		-e 's|LSREMDIR|'$lipsync_dir_remote'|g'
	mv etc/lipsyncd ${CFGFILE}
	echo "done"

	if [ ! -f ${EXCLUDES} ]; then
		echo -n "* Creating lipsync excludes config..."
		cat >${EXCLUDES} <<EOF
.snapshot
EOF
		echo "done"
	fi
}

setup(){
	echo -n "	> Installing cron..."
	# define entry for crontab	
	newcronjob="* * * * *  /usr/local/bin/lipsync >/dev/null 2>&1"
	# list crontab, read entry from crontab, add line from stdin to crontab	
	(crontab -l; echo "$newcronjob") | crontab - 
	echo "done"

	echo -n "	> ${CFGDIR}..."
 	if [ ! -d ${CFGDIR} ]; then
        	mkdir ${CFGDIR}
		chown ${USER}:${USER} ${CFGDIR}
        fi
	echo "done"

	echo -n "	> ${LOGFILE}..."
	touch ${LOGFILE}
	chown ${USER}:${USER} ${LOGFILE}
	chmod g+w ${LOGFILE}
	echo "done"

	echo -n "	> checking for $lipsync_dir_local..."
	if [ ! -d $lipsync_dir_local ]; then
		echo; echo -n "	> $lipsync_dir_local not found, creating..."
		mkdir $lipsync_dir_local
		chown ${USER}:${USER} $lipsync_dir_local
	fi
	echo "done"

	echo "lipsync setup `date`" > ${LOGFILE}
}

initial_sync() {
	echo -n "* Doing inital sync with server..."
	. ${CFGFILE}
	rsync -rav --stats --log-file=${LOGFILE} --exclude-from=${EXCLUDES} -e "ssh -p '$SSH_PORT'" '$REMOTE_HOST':'$REMOTE_DIR' '$LOCAL_DIR'
	echo "Initial sync `date` Completed" > ${LOGFILE}
}

########################################
# Setup lipsync 
########################################
questions
ssh_keygen
build_conf
setup
initial_sync

exit 0
