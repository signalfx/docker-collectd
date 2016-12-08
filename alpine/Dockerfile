FROM alpine:3.4

MAINTAINER SignalFx Support <support+collectd@signalfx.com>

# Specify Versions
ARG COLLECTD_STAGE=release
ARG PLUGIN_STAGE=release
ARG ALPINE_VERSION=3.4

# Set repository urls
ARG COLLECTD_ADDR=https://dl.signalfx.com/apks/collectd/alpine/${ALPINE_VERSION}/${COLLECTD_STAGE}/collectd.tar.gz
ARG PLUGIN_ADDR=https://dl.signalfx.com/apks/signalfx-collectd-plugin/alpine/${ALPINE_VERSION}/${PLUGIN_STAGE}/signalfx-collectd-plugin.tar.gz

# Setup our collectd
COPY ["configs", "/tmp/"]

# Add in startup script
COPY ["run.sh", "/run/"]

# Add public repository key
COPY ["support+apk@signalfx.com-57fbc71c.rsa.pub", "/etc/apk/keys"]

# Install all apt-get utils and required repos
RUN apk update \
    && apk upgrade \
    && apk add py-pip \
               unzip \
               curl \
    # Make directory for local signalfx-collectd repository
    && mkdir -p /repo \
    && cd /repo \
    # Curl down and unarchive the collectd repo
    && curl -LOk ${COLLECTD_ADDR} \
    && tar -xvzf /repo/collectd.tar.gz \
    && rm /repo/collectd.tar.gz \
    && ls -la /repo/collectd/x86_64 \
    && echo /repo/collectd >> /etc/apk/repositories \
    # Curl down and unarchive the signalfx-plugin repo
    && curl -LOk ${PLUGIN_ADDR} \
    && tar -xvzf /repo/signalfx-collectd-plugin.tar.gz \
    && rm /repo/signalfx-collectd-plugin.tar.gz \
    && ls -la /repo/signalfx-collectd-plugin/x86_64 \
    && echo /repo/signalfx-collectd-plugin >> /etc/apk/repositories \
    # View the apk repository data
    && cat /etc/apk/repositories \
    # # Update apk repository data
    && apk update \
    # Install collectd and signalfx-collectd-plugin
    && apk add collectd \
               collectd-python \
               collectd-write_http \
               signalfx-collectd-plugin \
    # Clean up existing configs
    && rm -rf /etc/collectd \
    # Install default configs
    && mv /tmp/collectd /etc/ \
    # Download the SignalFx docker-collectd-plugin
    && cd /tmp \
    && curl -L "https://github.com/signalfx/docker-collectd-plugin/archive/master.zip" --output /tmp/docker-collectd-plugin.zip \
    # Extract the SignalFx docker-collectd-plugin
    && unzip /tmp/docker-collectd-plugin.zip -d /tmp \
    # Move the SignalFx docker-collectd-plugin into place
    && mv /tmp/docker-collectd-plugin-master/ /usr/share/collectd/docker-collectd-plugin \
    # Install pip requirements for the docker-collectd-plugin
    && pip install -r /usr/share/collectd/docker-collectd-plugin/requirements.txt \
    # Download the configuration file for docker-collectd-plugin
    && curl -L "https://github.com/signalfx/integrations/archive/master.zip" --output /tmp/integrations.zip \
    # Extract the configuration file for docker-collectd-plugin
    && unzip /tmp/integrations.zip -d /tmp \
    # Move the managed config into place
    && cp /tmp/integrations-master/collectd-docker/10-docker.conf /etc/collectd/managed_config/ \
    # Set correct permissions on startup script
    && cd /run \
    && chmod +x run.sh \
    && rm -rf /tmp/* \

# Set the shell as the entry point
ENTRYPOINT sh

# Execute the script run.sh in the shell
CMD /run/run.sh
