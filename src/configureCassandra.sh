#!/usr/bin/env bash

CASSANDRADIR=/etc/cassandra

passwordFile=$CASSANDRADIR/credentials.txt

if [ -f $passwordFile ]; then
	
	configFile=$CASSANDRADIR/userConfig.cql
	adminPasswordFile=$CASSANDRADIR/cassandraPasswords.txt
	
	if [ ! -f $adminPasswordFile ]; then
		randomPassword=`cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 32`

		echo "ALTER USER cassandra WITH PASSWORD '$randomPassword' SUPERUSER;" > $CASSANDRADIR/alterDefaultUser.cql
		echo "cassandra:$randomPassword" > $adminPasswordFile

		adminPassword=`cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 32`
		echo "admin:$adminPassword" >> $adminPasswordFile
		echo "CREATE USER IF NOT EXISTS 'admin' WITH PASSWORD '$adminPassword' SUPERUSER;" > $configFile
		
		while true; do
			cqlsh -u cassandra -p cassandra -e EXIT > /dev/null 2>&1
			if [ "$?" == "1" ]; then
					echo "Waiting for Cassandra..."
					sleep 2
			else
					break;
			fi
		done
		
		cqlsh -u cassandra -p cassandra -f $configFile
		cqlsh -u admin -p $adminPassword -f $CASSANDRADIR/alterDefaultUser.cql
		echo "" > $configFile #clear file
	else
		IFS=$'\n'
		while read line
		do
				actualCreds+=("$line")
		done < $adminPasswordFile

		IFS=$':'
		for ((i=0; i < ${#actualCreds[*]}; i++))
		do
				read -r user pass <<< "${actualCreds[i]}"
				if [ "$user" -eq "admin" ]; then
					adminPassword="$pass"
				fi
		done
	fi

	IFS=$'\n'
	while read line
	do
			array+=("$line")
	done < $passwordFile

	IFS=$':'
	for ((i=0; i < ${#array[*]}; i++))
	do
			read -r user pass <<< "${array[i]}"
			echo "CREATE USER IF NOT EXISTS '$user' WITH PASSWORD '$pass' SUPERUSER;" >> $configFile
	done

	while true; do
		cqlsh -u admin -p $adminPassword -e EXIT > /dev/null 2>&1
		if [ "$?" == "1" ]; then
				echo "Waiting for Cassandra..."
				sleep 2
		else
				break;
		fi
	done
	
	cqlsh -u admin -p $adminPassword -f $configFile
fi