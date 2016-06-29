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

## How to use this image

Run collectd with the default configuration with the following command:

```
docker run --privileged \
  -e "SF_API_TOKEN=XXXXXXXXXXXXXXXXXXXXXX" \
  -v /etc/hostname:/mnt/hostname:ro \
  -v /proc:/mnt/proc:ro \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /etc:/mnt/etc:ro \
  quay.io/signalfuse/collectd
```

If you don't want to report Docker metrics from the SignalFx Docker collectd 
plugin, then you can leave out the argument that mounts
the Docker socket `-v /var/run/docker.sock:/var/run/docker.sock`.

```
docker run --privileged \
  -e "SF_API_TOKEN=XXXXXXXXXXXXXXXXXXXXXX" \
  -v /etc/hostname:/mnt/hostname:ro \
  -v /proc:/mnt/proc:ro \
  -v /etc:/mnt/etc:ro \
  quay.io/signalfuse/collectd
```

If you just want to look around inside the image, you can run `bash`.
Then you can run `/opt/setup/run.sh` yourself to configure the bind mount
and start collectd.

```
docker run -ti --privileged \
  -e "SF_API_TOKEN=XXXXXXXXXXXXXXXXXXXXXX" \
  -v /etc/hostname:/mnt/hostname:ro \
  -v /proc:/mnt/proc:ro \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /etc:/mnt/etc:ro \
  quay.io/signalfuse/collectd bash
```

If you don't want to pass your API token through a command-line argument, you
can put `SF_API_TOKEN=XXXXXXXXXXXXXXXXXXXXXX` into a file (that you can
`chmod 600`) and use the `--env-file` command-line argument:

```
docker run --privileged --env-file=token.env \
  -v /etc/hostname:/mnt/hostname:ro \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /proc:/mnt/proc:ro \
  -v /etc:/mnt/etc:ro \
  quay.io/signalfuse/collectd
```

On CoreOS because /etc/*-release are symlinks you want to mount
/usr/share/coreos in place of /etc.

```
docker run --privileged \
  -e "SF_API_TOKEN=XXXXXXXXXXXXXXXXXXXXXX" \
  -v /etc/hostname:/mnt/hostname:ro \
  -v /proc:/mnt/proc:ro \
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

### Do I need to pass in /etc?

It's actually optional but we use this to get the host OS's version so the
SignalFx Collectd Plugin will function correctly and report the right
information.  If you leave it out you will see the container's OS in the
meta-data for this host.

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

1. `COLLECTD_HOSTNAME` - if set we will set this in
   `/etc/collectd/collectd.conf`.  If the environment variable is not set, 
   we will attempt to cat `/mnt/hostname` for the host's hostname.  If no hostname
   is discovered, we will exit with an error code of 1 and display a message
   indicating that a hostname could not be found.
1. `COLLECTD_INTERVAL` - if set we will use the specified interval for collectd
   and the plugin, otherwise the default interval is 10 seconds.
1. `COLLECTD_CONFIGS` - if set we will include `$COLLECTD_CONFIGS/*.conf` in
   collectd.conf where you can include any other plugins you want to enable.
   These of course would need to be mounted in the container with -v.
1. `COLLECTD_BUFFERSIZE` - if set we will set `write_http`'s buffersize to the
   value provided, otherwise a default value of 16384 will be used.
1. `COLLECTD_FLUSHINTERVAL` - if set we will set `write_http`'s flush interval
   to the value provided, otherwise a default value of what COLLECTD_INTERVAL
   is set to will be used.

### Extending
[Click this link to read about Extending SignalFx Docker collectd image](./docs/EXTENDING.md)