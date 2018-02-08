#!/bin/sh
set -x

AGGREGATION_CONF=/etc/collectd/managed_config/10-aggregation-cpu.conf
COLLECTD_CONF=/etc/collectd/collectd.conf
DOCKER_CONF=/etc/collectd/managed_config/10-docker.conf
WRITE_HTTP_CONF=/etc/collectd/managed_config/10-write_http-plugin.conf
PLUGIN_CONF=/etc/collectd/managed_config/20-signalfx-plugin.conf
FILTERING_CONF=/etc/collectd/filtering_config/filtering.conf
ADD_DIMENSIONS=""

is_true()
{
    echo "$0"
    if [ -n "$1" ] && { [ "$1" == "true" ] || [ "$1" == "True" ] || [ "$1" == "TRUE" ]; }; then
        return 0
    else
        return 1
    fi
};

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

if is_true $DISABLE_HOST_MONITORING ; then
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
    DISABLE_AGENT_PROCESS_STATS=True
fi

if [ -n "$DOG_STATSD_PORT" ]; then
    DOG_STATSD_PORT="DogStatsDPort $DOG_STATSD_PORT"
else
    DOG_STATSD_PORT=""
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

AWS_UNIQUE_ID=$(curl -s --connect-timeout 1 http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.instanceId + "_" + .accountId + "_" + .region')

# if FQDN_LOOKUP is set, use that instead of the other host options
if is_true $FQDN_LOOKUP ; then
    HOSTNAME="FQDNLookup true"
#If the user sets COLLECTD_HOSTNAME then assign to HOSTNAME
elif [ -n "$COLLECTD_HOSTNAME" ]; then
	HOSTNAME="Hostname \"$COLLECTD_HOSTNAME\""
elif [ -n "$USE_AWS_UNIQUE_ID_AS_HOSTNAME" ]; then
    # When ran inside an ECS cluster, the system hostname can be the same for
    # every docker container instance, which makes the hostname fairly useless
    # as a dimension.
    HOSTNAME="Hostname \"${AWS_UNIQUE_ID}\""
#If the host's hostname is mounted @ /mnt/hostname, then assign to HOSTNAME
elif [ -e /mnt/hostname ]; then
    HOST_HOSTNAME=$(cat /mnt/hostname)
    if [ -n "$HOST_HOSTNAME" ]; then
        HOSTNAME="Hostname \"$HOST_HOSTNAME\""
    fi
#If the host's hostname is mounted @ /hostfs/etc/hostname, then assign to HOSTNAME
elif [ -e /hostfs/etc/hostname ]; then
    HOST_HOSTNAME=$(cat /hostfs/etc/hostname)
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
if [ -z "$WRITE_HTTP_TIMEOUT" ]; then
    WRITE_HTTP_TIMEOUT="9000"
fi
if [ -z "$LOG_HTTP_ERROR" ]; then
    LOG_HTTP_ERROR="false"
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
    rm /etc/collectd/managed_config/10-docker.conf
fi
if is_true $DISABLE_DISK ; then
    DISK=$''
else
    DISK=$'LoadPlugin disk \
\
<Plugin "disk"> \
  Disk "/^loop\d+$/" \
  Disk "/^dm-\d+$/" \
  IgnoreSelected "true" \
</Plugin>'
fi
if is_true $DISABLE_CPU ; then
    CPU=$''
else
    CPU=$'LoadPlugin cpu'
fi
if is_true $DISABLE_CPUFREQ ; then
    CPUFREQ=$''
else
    CPUFREQ=$'LoadPlugin cpufreq'
fi
if is_true $DISABLE_DF ; then
    DF=$''
elif [ -d "/hostfs" ] ; then
    DF=$'LoadPlugin df \
\
<Plugin "df"> \
  ChangeRoot "/hostfs" \
</Plugin>'
else
    echo "WARNING: The host's filesystem has not been mounted, but the df \
plugin is still enabled.  Information from the df plugin may be inaccurate \
for the host."

    DF=$'LoadPlugin df'
fi
if is_true $DISABLE_INTERFACE ; then
     INTERFACE=$''
else
    INTERFACE=$'LoadPlugin interface \
\
<Plugin "interface"> \
  Interface "/^lo\d*$/" \
  Interface "/^docker.*/" \
  Interface "/^t(un|ap)\d*$/" \
  Interface "/^veth.*$/" \
  IgnoreSelected "true" \
 </Plugin>'
fi
if is_true $DISABLE_LOAD ; then
    LOAD=$''
else
    LOAD=$'LoadPlugin load'
fi
if is_true $DISABLE_MEMORY ; then
    MEMORY=$''
else
    MEMORY=$'LoadPlugin memory'
fi
if is_true $DISABLE_PROTOCOLS ; then
    PROTOCOLS=$''
else
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
fi
if is_true $DISABLE_VMEM ; then
    VMEM=$''
else
    VMEM=$'LoadPlugin vmem \
\
<Plugin vmem> \
  Verbose false \
</Plugin>'
fi
if is_true $DISABLE_UPTIME ; then
    UPTIME=$''
else
    UPTIME=$'LoadPlugin uptime'
fi

if is_true $DISABLE_AGENT_PROCESS_STATS ; then
    AGENT_PROCESS_STATS=$''
else
    AGENT_PROCESS_STATS=$'LoadPlugin processes \
\
<Plugin processes> \
    Process collectd \
</Plugin>'
fi

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
sed -i -e "s#%%%AGENT_PROCESS_STATS%%%#$AGENT_PROCESS_STATS#g" $COLLECTD_CONF


# Process option to disable aggregation plugin
if is_true $DISABLE_AGGREGATION ; then
    if [ -f "$AGGREGATION_CONF" ]; then
        rm $AGGREGATION_CONF
    fi
fi

# Process timeout for Docker
if [ -n "$DOCKER_TIMEOUT" ] ; then
    sed -i -e '/\bTimeout\b/I c\' $DOCKER_CONF
    sed -i -e '/<Module dockerplugin>/a \'"    Timeout ${DOCKER_TIMEOUT}" $DOCKER_CONF
    cat $DOCKER_CONF
fi

# Process Interval for Docker
if [ -n "$DOCKER_INTERVAL" ] ; then
    sed -i -e '/\bInterval\b/I c\' $DOCKER_CONF
    sed -i -e '/<Module dockerplugin>/a \'"    Interval ${DOCKER_INTERVAL}" $DOCKER_CONF
    cat $DOCKER_CONF
fi

# Process option to disable docker plugin
if is_true $DISABLE_DOCKER ; then
    if [ -f "$DOCKER_CONF" ]; then
        rm $DOCKER_CONF
    fi
fi

# Disable the SFX Plugin or write out configurations
if is_true $DISABLE_SFX_PLUGIN ; then
    if [ -f "$PLUGIN_CONF" ]; then
        rm $PLUGIN_CONF
    fi
else
    # set etc path if the old etc mount point doesn't exist
    if [[ -d "/hostfs/etc" && ! -d "/mnt/etc" ]]; then
        sed -i -e "s#%%%ETC_PATH%%%#EtcPath \"/hostfs/etc\"#g" $PLUGIN_CONF
    else 
        sed -i -e "s#%%%ETC_PATH%%%##g" $PLUGIN_CONF
    fi

    # set proc path if the old proc mount point doesn't exist
    if [[ -d "/hostfs/proc" && ! -d "/mnt/proc" ]]; then
        sed -i -e "s#%%%PROC_PATH%%%#ProcPath \"/hostfs/proc\"#g" $PLUGIN_CONF
    else 
        sed -i -e "s#%%%PROC_PATH%%%##g" $PLUGIN_CONF
    fi

    if is_true $PER_CORE_CPU_UTIL && ! is_true $DISABLE_AGGREGATION ; then
        PER_CORE_UTIL_CONFIG="true" 
    else
        PER_CORE_UTIL_CONFIG="false" 
    fi
    sed -i -e "s#%%%PERCORECPUUTIL%%%#$PER_CORE_UTIL_CONFIG#g" $PLUGIN_CONF
    sed -i -e "s#%%%INGEST_HOST%%%#$SF_INGEST_HOST#g" $PLUGIN_CONF
    sed -i -e "s#%%%API_TOKEN%%%#$SF_API_TOKEN#g" $PLUGIN_CONF
    sed -i -e "s#%%%INTERVAL%%%#$COLLECTD_INTERVAL#g" $PLUGIN_CONF
    sed -i -e "s#%%%AWS_PATH%%%#$AWS_VALUE#g" $PLUGIN_CONF
    sed -i -e "s#%%%DOG_STATSD_PORT%%%#$DOG_STATSD_PORT#g" $PLUGIN_CONF
    cat $PLUGIN_CONF
fi

# Redirect metrics for per core cpu utilization
if is_true $PER_CORE_CPU_UTIL && ! is_true $DISABLE_SFX_PLUGIN ; then
    sed -i -e "s#%%%PER_CORE_UTIL_FILTER%%%#Plugin \"python.signalfx_metadata\"#g" $FILTERING_CONF
else
    sed -i -e "s#%%%PER_CORE_UTIL_FILTER%%%##g" $FILTERING_CONF
fi

# Disable the Write_HTTP plugin or write out configurations
if is_true $DISABLE_WRITE_HTTP ; then
    if [ -f "$WRITE_HTTP_CONF" ]; then
        rm $WRITE_HTTP_CONF
    fi
else
    sed -i -e "s#%%%AWS_PATH%%%#$AWS_VALUE#g" $WRITE_HTTP_CONF
    if [ -n "$ADD_DIMENSIONS" ]; then
        if [ -z "$AWS_VALUE" ] ; then
            ADD_DIMENSIONS="?$ADD_DIMENSIONS"
        else
            ADD_DIMENSIONS="\&$ADD_DIMENSIONS"
        fi
    fi
    sed -i -e "s#%%%DIMENSIONS%%%#$ADD_DIMENSIONS#g" $WRITE_HTTP_CONF
    sed -i -e "s#%%%BUFFERSIZE%%%#$COLLECTD_BUFFERSIZE#g" $WRITE_HTTP_CONF
    sed -i -e "s#%%%FLUSHINTERVAL%%%#$COLLECTD_FLUSHINTERVAL#g" $WRITE_HTTP_CONF
    sed -i -e "s#%%%INGEST_HOST%%%#$SF_INGEST_HOST#g" $WRITE_HTTP_CONF
    sed -i -e "s#%%%API_TOKEN%%%#$SF_API_TOKEN#g" $WRITE_HTTP_CONF
    sed -i -e "s#%%%WRITE_HTTP_TIMEOUT%%%#$WRITE_HTTP_TIMEOUT#g" $WRITE_HTTP_CONF
    sed -i -e "s#%%%LOG_HTTP_ERROR%%%#$LOG_HTTP_ERROR#g" $WRITE_HTTP_CONF
    cat $WRITE_HTTP_CONF
fi

cat $COLLECTD_CONF

# Legacy support incase someone hasn't noticed our run instructions changed
if [ -d "/mnt/etc" ]; then
	cp -f /mnt/etc/*-release /etc
fi

# Legacy support in case someone hasn't noticed our run instructions changed
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
