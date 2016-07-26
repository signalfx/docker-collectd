#!/bin/bash
set -x

COLLECTD_CONF=/etc/collectd/collectd.conf
WRITE_HTTP_CONF=/etc/collectd/managed_config/10-write_http-plugin.conf
PLUGIN_CONF=/etc/collectd/managed_config/20-signalfx-plugin.conf

if [ -z "$SF_API_TOKEN" ]; then
	echo "Please set SF_API_TOKEN env to the API token to use"
	exit 1
fi
if [ ! -d "/mnt/proc" ]; then
	echo "You're running this without loopback mounting /proc.  You can run with '-v /proc:/mnt/proc:ro' when to do this."
fi
if [ -n "$COLLECTD_CONFIGS" ]; then
	echo "Include \"$COLLECTD_CONFIGS/*.conf\"" >> $COLLECTD_CONF
fi
#If the user sets COLLECTD_HOSTNAME then assign to HOSTNAME
if [ -n "$COLLECTD_HOSTNAME" ]; then
	HOSTNAME="Hostname \"$COLLECTD_HOSTNAME\""
#If the host's hostname is mounted @ /mnt/etc/hostname, then assign to HOSTNAME
elif [ -e /mnt/hostname ]; then
    HOST_HOSTNAME=$(cat /mnt/hostname)
    if [ -n "$HOST_HOSTNAME" ]; then
        HOSTNAME="Hostname \"$HOST_HOSTNAME\""
    fi
#The user did not specify and the host's hostname is unavailable
#Exit with error code 1
else
    echo 1>&2 "ERROR: Unable to find the hostname for the Docker host. Please \
specify a hostname with the option -e \"COLLECTD_HOSTNAME=<hostname>\" or by \
mounting the Docker host's hostname \
-v <path to host's hostname file>:/mnt/hostname:ro"
    exit 1
fi
if [ -z "$COLLECTD_BUFFERSIZE" ]; then
	COLLECTD_BUFFERSIZE="16384"
fi
if [ -z "$SF_INGEST_HOST" ]; then
	SF_INGEST_HOST="https://ingest.signalfx.com"
fi
if [ -z "$COLLECTD_INTERVAL" ]; then
	COLLECTD_INTERVAL="10"
fi
if [ -z "$COLLECTD_FLUSHINTERVAL" ]; then
	COLLECTD_FLUSHINTERVAL=$COLLECTD_INTERVAL
fi
if [ ! -S /var/run/docker.sock ]; then
    echo "The Docker socket was not mounted into this container, the SignalFx Docker collectd plugin will be disabled"
    rm /etc/collectd/managed_config/dockerplugin.conf
fi
AWS_UNIQUE_ID=$(curl -s --connect-timeout 1 http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.instanceId + "_" + .accountId + "_" + .region')

[ -n "$AWS_UNIQUE_ID" ] && AWS_VALUE="?sfxdim_AWSUniqueId=$AWS_UNIQUE_ID"


sed -i -e "s#%%%INTERVAL%%%#$COLLECTD_INTERVAL#g" $COLLECTD_CONF
sed -i -e "s#%%%HOSTNAME%%%#$HOSTNAME#g" $COLLECTD_CONF

sed -i -e "s#%%%AWS_PATH%%%#$AWS_VALUE#g" $WRITE_HTTP_CONF
sed -i -e "s#%%%BUFFERSIZE%%%#$COLLECTD_BUFFERSIZE#g" $WRITE_HTTP_CONF
sed -i -e "s#%%%FLUSHINTERVAL%%%#$COLLECTD_FLUSHINTERVAL#g" $WRITE_HTTP_CONF
sed -i -e "s#%%%INGEST_HOST%%%#$SF_INGEST_HOST#g" $WRITE_HTTP_CONF
sed -i -e "s#%%%API_TOKEN%%%#$SF_API_TOKEN#g" $WRITE_HTTP_CONF

sed -i -e "s#%%%INGEST_HOST%%%#$SF_INGEST_HOST#g" $PLUGIN_CONF
sed -i -e "s#%%%API_TOKEN%%%#$SF_API_TOKEN#g" $PLUGIN_CONF
sed -i -e "s#%%%INTERVAL%%%#$COLLECTD_INTERVAL#g" $PLUGIN_CONF
sed -i -e "s#%%%AWS_PATH%%%#$AWS_VALUE#g" $PLUGIN_CONF

cat $COLLECTD_CONF
cat $PLUGIN_CONF
cat $WRITE_HTTP_CONF

if [ -d "/mnt/etc" ]; then
	cp -f /mnt/etc/*-release /etc
fi

if [ ! -d /mnt/oldproc ]; then
	if [ -d /mnt/proc ]; then
		umount /proc
		mount -o bind /mnt/proc /proc
		mkdir /mnt/oldproc
		mount -t proc none /mnt/oldproc
	fi
fi

if [ -z "$@" ]; then
  exec collectd -C $COLLECTD_CONF -f
else
  exec "$@"
fi
