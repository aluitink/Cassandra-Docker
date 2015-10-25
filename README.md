# Cassandra-Docker

Single node docker container hosting Apache Cassandra 2.2.

This container is authentication enabled, takes a credentials files, and will create and 'admin' user with a random password, and randomize the default 'cassandra' users password.

Use the volume argument to mount a file at /etc/cassandra/credentials.txt

	docker run -v /root/credentials.txt:/etc/cassandra/credentials.txt xyz

Cassandra will start up and as soon as it is ready the users will be created.

More documentation soon...