# docker-collectd

## Description

[collectd](http://collectd.org) is a daemon which collects system performance
statistics periodically and provides mechanisms to store the values in a
variety of ways, for example in RRD files.

This image allows you to run collectd in a completelly containerized
environment, but while retaining the ability to report statistics about the
_host_ the collectd container is running on.

## How to use this image

Run collectd with the default configuration with the following command:

```
docker run --privileged -e "SF_API_TOKEN=XXXXXXXXXXXXXXXXXXXXXX" \
  -v /proc:/mnt/proc:ro quay.io/signalfuse/collectd
```

If you just want to look around inside the image, you can run `bash`.
Then you can run `/opt/setup/run.sh` yourself to configure the bind mount
and start collectd.

```
docker run --privileged -e "SF_API_TOKEN=XXXXXXXXXXXXXXXXXXXXXX" \
  -v /proc:/mnt/proc:ro quay.io/signalfuse/collectd bash
```

If you don't want to pass your API token through a command-line argument, you
can put `SF_API_TOKEN=XXXXXXXXXXXXXXXXXXXXXX` into a file (that you can
`chmod 600`) and use the `--env-file` command-line argument:

```
docker run --privileged --env-file=token.env \
  -v /proc:/mnt/proc:ro quay.io/signalfuse/collectd
```

## FAQ

### Do I need to run the container as privileged?

Yes. Collectd needs access to the parent host's `/proc` filesystem to get
statistics. It's possible to run collectd without passing the parent host's
`/proc` filesystem without running the container as privileged, but the metrics
would not be accurate.

### Why can't I exec into the running docker container?

Because the docker container's proc filesystem has been replaced by the host
and because the PIDs are remapped, they no longer line up. See the example
above on how to run the image with a different command so you can then execute
`/.docker/run.sh` yourself to be on it while it runs.

### Can I configure anything?

Yes! You are required to set the `SF_API_TOKEN`, but you also can set the
following:

1. `COLLECTD_HOSTNAME` - if set we will set this in
   `/etc/collectd/collectd.conf`, otherwise collectd will use DNS to figure
   out your hostname.
1. `COLLECTD_INTERVAL` - if set we will use the specified interval for collectd 
   and the plugin, otherwise the default interval is 10 seconds.
1. `COLLECTD_CONFIGS` - if set we will include `$COLLECTD_CONFIGS/*.conf` in
   collectd.conf where you can include any other plugins you want to enable.
1. `COLLECTD_BUFFERSIZE` - if set we will set `write_http`'s buffersize to the
   value provided, otherwise a default value of 16384 will be used.
