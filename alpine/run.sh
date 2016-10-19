#!/bin/sh
set -x

AGGREGATION_CONF=/etc/collectd/managed_config/10-aggregation-cpu.conf
COLLECTD_CONF=/etc/collectd/collectd.conf
DOCKER_CONF=/etc/collectd/managed_config/10-docker.conf
WRITE_HTTP_CONF=/etc/collectd/managed_config/10-write_http-plugin.conf
PLUGIN_CONF=/etc/collectd/managed_config/20-signalfx-plugin.conf
ADD_DIMENSIONS=""

if [ ! -z "$DIMENSIONS" ]; then
    first=true
    for i in $DIMENSIONS; do
        sanatized=$(echo $i | tr '=' ' ')
        key=$(echo $sanatized | cut -d " " -f 1)
        value=$(echo $sanatized | cut -d " " -f 2)
        if [ ! -z $key ] && [ ! -z $value ] ; then
            if $first ; then
                first=false
            else
                ADD_DIMENSIONS="$ADD_DIMENSIONS\&"
            fi
            ADD_DIMENSIONS="$ADD_DIMENSIONS""sfxdim_$key=$value"
        fi
    done
fi

if [ ! -z "$DISABLE_HOST_MONITORING" ]; then
    DISABLE_AGGREGATION=True
    DISABLE_CPU=True
    DISABLE_CPUFREQ=True
    DISABLE_DF=True
    DISABLE_DISK=True
    DISABLE_DOCKER=True
    DISABLE_INTERFACE=True
    DISABLE_LOAD=True
    DISABLE_MEMORY=True
    DISABLE_PROTOCOLS=True
    DISABLE_VMEM=True
    DISABLE_UPTIME=True
    DISABLE_SFX_PLUGIN=True
fi

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
specify a hostname with the option -e \"HOSTNAME=<hostname>\" or by \
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
if [ -z "$DISABLE_DISK" ]; then
    DISK=$'LoadPlugin disk \
\
<Plugin "disk"> \
  Disk "/^loop\d+$/" \
  Disk "/^dm-\d+$/" \
  IgnoreSelected "true" \
</Plugin>'
else
    DISK=$''
fi
if [ -z "$DISABLE_CPU" ]; then
    CPU=$'LoadPlugin cpu'
else
    CPU=$''
fi
if [ -z "$DISABLE_CPUFREQ" ]; then
    CPUFREQ=$'LoadPlugin cpufreq'
else
    CPUFREQ=$''
fi
if [ -z "$DISABLE_DF" ]; then
    DF=$'LoadPlugin df'
else
    DF=$''
fi
if [ -z "$DISABLE_INTERFACE" ]; then
    INTERFACE=$'LoadPlugin interface \
\
<Plugin "interface"> \
  Interface "/^lo\d*$/" \
  Interface "/^docker.*/" \
  Interface "/^t(un|ap)\d*$/" \
  Interface "/^veth.*$/" \
  IgnoreSelected "true" \
 </Plugin>'
else
     INTERFACE=$''
fi
if [ -z "$DISABLE_LOAD" ]; then
    LOAD=$'LoadPlugin load'
else
    LOAD=$''
fi
if [ -z "$DISABLE_MEMORY" ]; then
    MEMORY=$'LoadPlugin memory'
else
    MEMORY=$''
fi
if [ -z "$DISABLE_PROTOCOLS" ]; then
    PROTOCOLS=$'LoadPlugin protocols\
\
<Plugin "protocols"> \
  Value "Icmp:InDestUnreachs" \
  Value "Tcp:CurrEstab" \
  Value "Tcp:OutSegs" \
  Value "Tcp:RetransSegs" \
  Value "TcpExt:DelayedACKs" \
  Value "TcpExt:DelayedACKs" \
\
  Value "/Tcp:.*Opens/" \
  Value "/^TcpExt:.*Octets/" \
  IgnoreSelected false \
</Plugin>'
else
    PROTOCOLS=$''
fi
if [ -z "$DISABLE_VMEM" ]; then
    VMEM=$'LoadPlugin vmem \
\
<Plugin vmem> \
  Verbose false \
</Plugin>'
else
    VMEM=$''
fi
if [ -z "$DISABLE_UPTIME" ]; then
    UPTIME=$'LoadPlugin uptime'
else
    UPTIME=$''
fi

AWS_UNIQUE_ID=$(curl -s --connect-timeout 1 http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.instanceId + "_" + .accountId + "_" + .region')

[ -n "$AWS_UNIQUE_ID" ] && AWS_VALUE="?sfxdim_AWSUniqueId=$AWS_UNIQUE_ID"


sed -i -e "s#%%%INTERVAL%%%#$COLLECTD_INTERVAL#g" $COLLECTD_CONF
sed -i -e "s#%%%HOSTNAME%%%#$HOSTNAME#g" $COLLECTD_CONF
sed -i -e "s#%%%DISK%%%#$DISK#g" $COLLECTD_CONF
sed -i -e "s#%%%CPU%%%#$CPU#g" $COLLECTD_CONF
sed -i -e "s#%%%CPUFREQ%%%#$CPUFREQ#g" $COLLECTD_CONF
sed -i -e "s#%%%DF%%%#$DF#g" $COLLECTD_CONF
sed -i -e "s#%%%INTERFACE%%%#$INTERFACE#g" $COLLECTD_CONF
sed -i -e "s#%%%LOAD%%%#$LOAD#g" $COLLECTD_CONF
sed -i -e "s#%%%MEMORY%%%#$MEMORY#g" $COLLECTD_CONF
sed -i -e "s#%%%PROTOCOLS%%%#$PROTOCOLS#g" $COLLECTD_CONF
sed -i -e "s#%%%VMEM%%%#$VMEM#g" $COLLECTD_CONF
sed -i -e "s#%%%UPTIME%%%#$UPTIME#g" $COLLECTD_CONF
sed -i -e "s#%%%INTERNAL_STATS%%%#$INTERNAL_STATS#g" $COLLECTD_CONF


# Proces option to disable aggregation plugin
if [ ! -z "$DISABLE_AGGREGATION" ]; then
    if [ -f "$AGGREGATION_CONF" ]; then
        rm $AGGREGATION_CONF
    fi
fi

# Process timeout for Docker
if [ -n "$DOCKER_TIMEOUT" ]; then
    sed -i -e '/\bTimeout\b/I c\' $DOCKER_CONF
    sed -i -e '/<Module dockerplugin>/a \'"    Timeout ${DOCKER_TIMEOUT}" $DOCKER_CONF
    cat $DOCKER_CONF
fi

# Process Interval for Docker
if [ -n "$DOCKER_INTERVAL" ]; then
    sed -i -e '/\bInterval\b/I c\' $DOCKER_CONF
    sed -i -e '/<Module dockerplugin>/a \'"    Interval ${DOCKER_INTERVAL}" $DOCKER_CONF
    cat $DOCKER_CONF
fi

# Process option to disable docker plugin
if [ ! -z "$DISABLE_DOCKER" ]; then
    if [ -f "$DOCKER_CONF" ]; then
        rm $DOCKER_CONF
    fi
fi

# Disable the SFX Plugin or write out configurations
if [ ! -z "$DISABLE_SFX_PLUGIN" ]; then
    if [ -f "$PLUGIN_CONF" ]; then
        rm $PLUGIN_CONF
    fi
else
    sed -i -e "s#%%%INGEST_HOST%%%#$SF_INGEST_HOST#g" $PLUGIN_CONF
    sed -i -e "s#%%%API_TOKEN%%%#$SF_API_TOKEN#g" $PLUGIN_CONF
    sed -i -e "s#%%%INTERVAL%%%#$COLLECTD_INTERVAL#g" $PLUGIN_CONF
    sed -i -e "s#%%%AWS_PATH%%%#$AWS_VALUE#g" $PLUGIN_CONF
    cat $PLUGIN_CONF
fi

# Disable the Write_HTTP plugin or write out configurations
if [ ! -z "$DISABLE_WRITE_HTTP" ]; then
    if [ -f "$WRITE_HTTP_CONF" ]; then
        rm $WRITE_HTTP_CONF
    fi
else
    sed -i -e "s#%%%AWS_PATH%%%#$AWS_VALUE#g" $WRITE_HTTP_CONF
    if [ -n "$ADD_DIMENSIONS" ]; then
        if [ -z "$AWS_VALUE" ] ; then
            ADD_DIMENSIONS="?$ADD_DIMENSIONS"
        else
            ADD_DIMENSIONS="&$ADD_DIMENSIONS"
        fi
        sed -i -e "s#%%%DIMENSIONS%%%#$ADD_DIMENSIONS#g" $WRITE_HTTP_CONF
    fi
    sed -i -e "s#%%%BUFFERSIZE%%%#$COLLECTD_BUFFERSIZE#g" $WRITE_HTTP_CONF
    sed -i -e "s#%%%FLUSHINTERVAL%%%#$COLLECTD_FLUSHINTERVAL#g" $WRITE_HTTP_CONF
    sed -i -e "s#%%%INGEST_HOST%%%#$SF_INGEST_HOST#g" $WRITE_HTTP_CONF
    sed -i -e "s#%%%API_TOKEN%%%#$SF_API_TOKEN#g" $WRITE_HTTP_CONF
    cat $WRITE_HTTP_CONF
fi

cat $COLLECTD_CONF

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
