#!/usr/bin/env bash

# Accept listen_address
IP=${LISTEN_ADDRESS:-`hostname --ip-address`}

# Accept seeds via docker run -e SEEDS=seed1,seed2,...
SEEDS=${SEEDS:-$IP}

# Backwards compatibility with older scripts that just passed the seed in
if [ $# == 1 ]; then SEEDS="$1,$SEEDS"; fi

#if this container was linked to any other cassandra nodes, use them as seeds as well.
if [[ `env | grep _PORT_9042_TCP_ADDR` ]]; then
  SEEDS="$SEEDS,$(env | grep _PORT_9042_TCP_ADDR | sed 's/.*_PORT_9042_TCP_ADDR=//g' | sed -e :a -e N -e 's/\n/,/' -e ta)"
fi

echo Configuring Cassandra to listen at $IP with seeds $SEEDS

# Setup Cassandra
DEFAULT=${DEFAULT:-/etc/cassandra/default.conf}
CASSANDRADIR=/etc/cassandra
CONFIG=$CASSANDRADIR/conf

rm -rf $CONFIG && cp -r $DEFAULT $CONFIG
sed -i -e "s/^authenticator.*/authenticator: PasswordAuthenticator/" 			$CONFIG/cassandra.yaml
sed -i -e "s/^listen_address.*/listen_address: $IP/"            				$CONFIG/cassandra.yaml
sed -i -e "s/^rpc_address.*/rpc_address: 0.0.0.0/"              				$CONFIG/cassandra.yaml
sed -i -e "s/# broadcast_address.*/broadcast_address: $IP/"             		$CONFIG/cassandra.yaml
sed -i -e "s/# broadcast_rpc_address.*/broadcast_rpc_address: $IP/"     		$CONFIG/cassandra.yaml
sed -i -e "s/^commitlog_segment_size_in_mb.*/commitlog_segment_size_in_mb: 64/"              $CONFIG/cassandra.yaml
sed -i -e "s/- seeds: \"127.0.0.1\"/- seeds: \"$SEEDS\"/"       				$CONFIG/cassandra.yaml
sed -i -e "s/# JVM_OPTS=\"\$JVM_OPTS -Djava.rmi.server.hostname=<public name>\"/JVM_OPTS=\"\$JVM_OPTS -Djava.rmi.server.hostname=$IP\"/" $CONFIG/cassandra-env.sh
sed -i -e "s/LOCAL_JMX=yes/LOCAL_JMX=no/" 										$CONFIG/cassandra-env.sh
sed -i -e "s/JVM_OPTS=\"\$JVM_OPTS -Dcom.sun.management.jmxremote.authenticate=true\"/JVM_OPTS=\"\$JVM_OPTS -Dcom.sun.management.jmxremote.authenticate=false\"/" $CONFIG/cassandra-env.sh

if [[ $SNITCH ]]; then
  sed -i -e "s/endpoint_snitch: SimpleSnitch/endpoint_snitch: $SNITCH/" $CONFIG/cassandra.yaml
fi
if [[ $DC && $RACK ]]; then
  echo "dc=$DC" > $CONFIG/cassandra-rackdc.properties
  echo "rack=$RACK" >> $CONFIG/cassandra-rackdc.properties
fi

# Start process
echo Starting Cassandra on $IP...
/usr/bin/supervisord

passwordFile=$CASSANDRADIR/credentials.txt

if [ -f $passwordFile ]; then
	#wait for cassandra to startup
	sleep 20s

	configFile=$CASSANDRADIR/userConfig.cql
	adminPasswordFile=$CASSANDRADIR/cassandraPasswords.txt
	
	if [ ! -f $adminPasswordFile ]; then
		randomPassword=`cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 32`

		echo "ALTER USER cassandra WITH PASSWORD '$randomPassword' SUPERUSER;" > $CASSANDRADIR/alterDefaultUser.cql
		echo "cassandra:$randomPassword" > $adminPasswordFile

		adminPassword=`cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 32`
		echo "admin:$adminPassword" >> $adminPasswordFile
		echo "CREATE USER IF NOT EXISTS 'admin' WITH PASSWORD '$adminPassword' SUPERUSER;" > $configFile
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

	cqlsh -u admin -p $adminPassword -f $configFile
fi
