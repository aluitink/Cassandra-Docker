# Cassandra
#
# VERSION               1.0

FROM centos:centos7

# Add source repositories
ADD src/epel7.repo /etc/yum.repos.d/epel7.repo
ADD src/datastax.repo /etc/yum.repos.d/datastax.repo

# Install Java, Install packages (sshd + supervisord + monitoring tools + cassandra)
RUN yum install -y wget tar openssh-server openssh-clients supervisor sysstat sudo which openssl hostname
RUN yum install -y java-1.8.0-openjdk-headless
RUN yum install -y dsc22
RUN yum install -y vim
RUN yum clean all

# Configure supervisord
ADD src/supervisord.conf /etc/supervisord.conf
RUN mkdir -p /var/log/supervisor

# Deploy startup script
ADD src/start.sh /usr/local/bin/start
ADD src/configureCassandra.sh /usr/local/bin/configureCassandra

RUN chmod 755 /usr/local/bin/start
RUN chmod 755 /usr/local/bin/configureCassandra

# Necessary since cassandra is trying to override the system limitations
# See https://groups.google.com/forum/#!msg/docker-dev/8TM_jLGpRKU/dewIQhcs7oAJ
RUN rm -f /etc/security/limits.d/cassandra.conf

EXPOSE 7199 7000 7001 9160 9042
EXPOSE 22 8012 61621
USER root
CMD start