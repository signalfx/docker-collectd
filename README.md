# docker-collectd

## Description

collectd is a daemon which collects system performance statistics periodically
and provides mechanisms to store the values in a variety of ways, for example
in RRD files.

This image allows you to run collectd in a completelly containerized
environment

## How to use this image

Run collectd with the default configuration:

```
docker run --privileged -e "SF_API_TOKEN=XXXXXXXXXXXXXXXXXXXXXX" \
  -v /proc:/mnt/proc:ro signalfuse/collectd
```

Run the container and exec bash in the environment so you can look around.
Then you can run `/opt/setup/run.sh` yourself to configure the bind mount
and start collectd.

```
docker run --privileged -e "SF_API_TOKEN=XXXXXXXXXXXXXXXXXXXXXX" \
  -v /proc:/mnt/proc:ro signalfuse/collectd bash
```

## FAQ

### Do I need to run the container as privileged

Yes. Collectd needs access to the parent host's `/proc` filesystem to get
statistics. It's possible to run collectd without passing the parent host's
`/proc` filesystem without running the container as privileged, but the metrics
would not be acurate.

### Why can't I exec into the running docker container

Because the docker container's proc filesystem has been replaced by the host
and because the pids have been remapped they no longer line up.  See example
above on how to run it with a command and then you can execute `/.docker/run.sh`
to be on it while it runs.

### Can I configure anything

Yes!  You are required to set the SF_API_TOKEN, but you also can set the
following:

1. `COLLECTD_HOSTNAME` - if set we will set this in
  `/etc/collectd/collectd.conf` else use dns.
1. `COLLECTD_INTERVAL` - if set we will use the specified interval for collectd 
  and the plugin else the default interval is 10 seconds.
1. `COLLECTD_CONFIGS` - if set we will include `$COLLECTD_CONFIGS/*.conf` in
  collectd.conf where you can include any other plugins you want to enable.
1. `COLLECTD_BUFFERSIZE` - if set we will set write_http's buffersize to the
  value provided otherwise a default value of 16384 will be used.
