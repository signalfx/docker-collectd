# docker-collectd

## Description

[collectd](http://collectd.org) is a daemon which collects system performance
statistics periodically and provides mechanisms to store the values in a
variety of ways, for example in RRD files.

This image allows you to run collectd in a completely containerized
environment, but while retaining the ability to report statistics about the
_host_ the collectd container is running on.

The SignalFx collectd Docker plugin is also included, and will report metrics
about your containers.

## Image Options

| Base Image | Image Name |
| ---------- | ------------ |
| Ubuntu | `quay.io/signalfuse/collectd` |
| Alpine Linux |  `quay.io/signalfuse/collectd-alpine` |

## How to use this image

Run collectd with the default configuration with the following command:

```
docker run --privileged \
  --net="host" \
  -e "SF_API_TOKEN=XXXXXXXXXXXXXXXXXXXXXX" \
  -v /etc/hostname:/mnt/hostname:ro \
  -v /proc:/mnt/proc:ro \
  -v /:/hostfs:ro \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /etc:/mnt/etc:ro \
  quay.io/signalfuse/collectd
```

If you don't want to report Docker metrics from the SignalFx Docker collectd 
plugin, then you can leave out the argument that mounts
the Docker socket `-v /var/run/docker.sock:/var/run/docker.sock`.

```
docker run --privileged \
  --net="host" \
  -e "SF_API_TOKEN=XXXXXXXXXXXXXXXXXXXXXX" \
  -v /etc/hostname:/mnt/hostname:ro \
  -v /proc:/mnt/proc:ro \
  -v /:/hostfs:ro \
  -v /etc:/mnt/etc:ro \
  quay.io/signalfuse/collectd
```

If you just want to look around inside the image, you can run `bash`.
Then you can run `/opt/setup/run.sh` yourself to configure the bind mount
and start collectd.

```
docker run -ti --privileged \
  --net="host" \
  -e "SF_API_TOKEN=XXXXXXXXXXXXXXXXXXXXXX" \
  -v /etc/hostname:/mnt/hostname:ro \
  -v /proc:/mnt/proc:ro \
  -v /:/hostfs:ro \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /etc:/mnt/etc:ro \
  quay.io/signalfuse/collectd bash
```

If you don't want to pass your API token through a command-line argument, you
can put `SF_API_TOKEN=XXXXXXXXXXXXXXXXXXXXXX` into a file (that you can
`chmod 600`) and use the `--env-file` command-line argument:

```
docker run --privileged --env-file=token.env \
  --net="host" \
  -v /etc/hostname:/mnt/hostname:ro \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /proc:/mnt/proc:ro \
  -v /:/hostfs:ro \
  -v /etc:/mnt/etc:ro \
  quay.io/signalfuse/collectd
```

If you want to apply custom dimensions and values to all metrics, you set the 
environment variable `DIMENSIONS` to a string of space separated  Key/Value 
pairs defined `KEY=VALUE`.

```
docker run --privileged --env-file=token.env \
  --net="host" \
  -e DIMENSIONS="hello=world foo=bar"
  -v /etc/hostname:/mnt/hostname:ro \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /proc:/mnt/proc:ro \
  -v /:/hostfs:ro \
  -v /etc:/mnt/etc:ro \
  quay.io/signalfuse/collectd
```

On CoreOS because /etc/*-release are symlinks you want to mount
/usr/share/coreos in place of /etc.

```
docker run --privileged \
  --net="host" \
  -e "SF_API_TOKEN=XXXXXXXXXXXXXXXXXXXXXX" \
  -v /etc/hostname:/mnt/hostname:ro \
  -v /proc:/mnt/proc:ro \
  -v /:/hostfs:ro \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /usr/share/coreos:/mnt/etc:ro \
  quay.io/signalfuse/collectd
```

## FAQ

### Do I need to run the container as privileged?

Yes. Collectd needs access to the parent host's `/proc` filesystem to get
statistics. It's possible to run collectd without passing the parent host's
`/proc` filesystem without running the container as privileged, but the metrics
would not be accurate.

### Do I need to provide the network flag?

Yes.  Setting the `--net` option to `"host"` allows the container to see the host's networking stack and provide accurate information.

### Do I need to pass in /etc?

It's actually optional but we use this to get the host OS's version so the
SignalFx Collectd Plugin will function correctly and report the right
information.  If you leave it out you will see the container's OS in the
meta-data for this host.

### Do I need to mount the host's / to /hostfs?

This is a requirement for the df plugin to correctly report information about
the host and not from the container.  If you explicitly disable the df plugin
then this is no longer a requirement to run the container.

### Do I need to provide a host name?

You have an option to either bind mount your host's `/etc/hostname` to the 
container's `/mnt/hostname` or to set the environment variable 
`COLLECTD_HOSTNAME`. You may set the environment variable using the runtime 
option `-e "COLLECTD_HOSTNAME=<hostname>"` where `<hostname>` is a 
valid host name string. You may also set the environment variable in an optional
 environment file.  Please note that if `/etc/hostname` is mounted and 
 `COLLECTD_HOSTNAME` is set, that the mounted host name will be used.
A hostname must be specified regardless of the method.

### Why can't I exec into the running docker container?

Because the docker container's proc filesystem has been replaced by the host
and because the PIDs are remapped, they no longer line up. See the example
above on how to run the image with a different command so you can then execute
`/.docker/run.sh` yourself to be on it while it runs.

### Can I configure anything?

Yes! You are required to set the `SF_API_TOKEN` and provide a hostname either 
by mounting `/etc/hostname` to `/mnt/hostname` or setting `COLLECTD_HOSTNAME`,
but you also can set the following:

| Environment Variable | Description | Example |
| -------------------- | ----------- | ------- |
| `COLLECTD_BUFFERSIZE` | if set we will set `write_http`'s buffersize to the value provided, otherwise a default value of 16384 will be used. | `-e "COLLECTD_BUFFERSIZE=<size>"` |
| `COLLECTD_CONFIGS` | if set we will include `$COLLECTD_CONFIGS/*.conf` in collectd.conf where you can include any other plugins you want to enable. These of course would need to be mounted in the container with -v. | `-e "COLLECTD_CONFIGS=<path to confs>"` |
| `COLLECTD_FLUSHINTERVAL` | if set we will set `write_http`'s flush interval to the value provided, otherwise a default value of what COLLECTD_INTERVAL is set to will be used. | `-e "COLLECTD_FLUSHINTERVAL=<interval>"` |
| `COLLECTD_HOSTNAME` | if set we will set this in `/etc/collectd/collectd.conf`.  If the environment variable is not set, we will attempt to cat `/mnt/hostname` for the host's hostname.  If no hostname is discovered, we will exit with an error code of 1 and display a message indicating that a hostname could not be found. | `-e "COLLECTD_HOSTNAME=<hostname>"` |
| `COLLECTD_INTERVAL` | if set we will use the specified interval for collectd and the plugin, otherwise the default interval is 10 seconds. | `-e "COLLECTD_INTERVAL=<interval>"` |
| `WRITE_HTTP_TIMEOUT` | if set we will set `write_http`'s timeout to the value provided, otherwise the default value of WRITE_HTTP_TIMEOUT will be `9000`. | `-e WRITE_HTTP_TIMEOUT=9000` |
| `LOG_HTTP_ERROR` | if set we will set `write_http`'s LogHttpError settting to the value provided, otherwise the default value of LOG_HTTP_ERROR will be `false`. | `-e LOG_HTTP_ERROR=false` |
| `DIMENSIONS` | If set with a string of space separated `key=value` dimension pairs, then each metric dipatched will be tagged with those dimensions. | `-e DIMENSIONS="foo=bar hello=world"` |
| `DISABLE_AGGREGATION` | If set to [ True, true, or TRUE ], disables the collectd aggregation plugin | `-e "DISABLE_AGGREGATION=True"` |
| `DISABLE_CPU` | If set to [ True, true, or TRUE ], disables the collectd cpu plugin | `-e "DISABLE_CPU=True"` |
| `DISABLE_CPUFREQ` | If set to [ True, true, or TRUE ], disables the collectd cpu frequency plugin | `-e "DISABLE_CPUFREQ=True"` |
| `DISABLE_DF` | If set to [ True, true, or TRUE ], disables the collectd df plugin | `-e "DISABLE_DF=True"` |
| `DISABLE_DISK` | If set to [ True, true, or TRUE ], disables the collectd disk plugin | `-e "DISABLE_DISK=True"` |
| `DISABLE_DOCKER` | If set to [ True, true, or TRUE ], disables the collectd docker plugin | `-e "DISABLE_DOCKER=True"` |
| `DISABLE_HOST_MONITORING` | If set to [ True, true, or TRUE ], disables the collectd aggregation, cpu, cpu frequency, df, disk, docker, interface, load, memory, protocols, vmem, uptime, SignalFx collectd, and write http plugins | `-e "DISABLE_HOST_MONITORING=True"` |
| `DISABLE_INTERFACE` | If set to [ True, true, or TRUE ], disables the collectd interface plugin | `-e "DISABLE_INTERFACE=True"` |
| `DISABLE_LOAD` | If set to [ True, true, or TRUE ], disables the collectd load plugin | `-e "DISABLE_LOAD=True"` |
| `DISABLE_MEMORY` | If set to [ True, true, or TRUE ], disables the collectd memory plugin | `-e "DISABLE_MEMORY=True"` |
| `DISABLE_PROTOCOLS` | If set to [ True, true, or TRUE ], disables the collectd protocols plugin | `-e "DISABLE_PROTOCOLS=True"` |
| `DISABLE_VMEM` | If set to [ True, true, or TRUE ], disables the collectd vmem plugin | `-e "DISABLE_VMEM=True"` |
| `DISABLE_UPTIME` | If set to [ True, true, or TRUE ], disables the collectd uptime plugin | `-e "DISABLE_UPTIME=True"` |
| `DISABLE_SFX_PLUGIN` | If set to [ True, true, or TRUE ], disables the SignalFx collectd plugin | `-e "DISABLE_SFX_PLUGIN=True"` |
| `DISABLE_WRITE_HTTP` | If set to [ True, true, or TRUE ], disables the collectd write http plugin | `-e "DISABLE_WRITE_HTTP=True"` |
| `PER_CORE_CPU_UTIL` | If set to [True, true, or TRUE], configures the SignalFx collectd plugin to report CPU utilization per core | `-e "PER_CORE_CPU_UTIL=True` |
| `DOCKER_TIMEOUT` | The number of seconds calls to the Docker API should wait to timeout | `-e "DOCKER_TIMEOUT=3"` |
| `DOCKER_INTERVAL` | If set we will use the specified interval for the docker plugin, otherwise the global collectd interval (defaulted to 10 secs) will be used | `-e "DOCKER_INTERVAL=10"` |
| `SF_INGEST_HOST` | Will set the ingest url on the signalfx metadata plugin and on collectd itself | `-e "SF_INGEST_HOST=http://ingest.proxy.com" ` |

### Extending
[Click this link to read about Extending SignalFx Docker collectd image](./docs/EXTENDING.md)
