# Dockerfile for base collectd install

FROM ubuntu:16.04
MAINTAINER SignalFx Support <support+collectd@signalfx.com>

# Install common softwares
ENV DEBIAN_FRONTEND noninteractive

# Setup our collectd
ADD ["configs", "/tmp/"]

# Install all apt-get utils and required repos
RUN apt-get update \
    && apt-get upgrade -y \
    # Install add-apt-repository
    && apt-get install -y \
        software-properties-common \
    && add-apt-repository -y ppa:signalfx/collectd-release \
    && add-apt-repository -y ppa:signalfx/collectd-plugin-release \
    && apt-get update \
    # Install
    && apt-get install -y \
        # Install SignalFx Plugin
        signalfx-collectd-plugin \
        # Install collectd
        collectd \
        # Install helper packages
        curl \
        jq \
        unzip \
        # Install pip
        python-pip \
    # Clean up existing configs
    && rm -rf /etc/collectd \
    # Install default configs
    && mv /tmp/collectd /etc/ \
    # Download the SignalFx docker-collectd-plugin
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
    # Uninstall helper packages
    && apt-get --purge -y remove \
        software-properties-common \
        unzip \
    # Clean up packages
    && apt-get autoclean \
    && apt-get clean \
    && apt-get autoremove -y \
    # Remove extraneous files
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/share/man/* \
    && rm -rf /usr/share/info/* \
    && rm -rf /var/cache/man/* \
    # Clean up tmp directory
    && rm -rf /tmp/*

# Add in startup script
ADD ["run.sh", "/.docker/"]

# Set correct permissions on startup script
RUN chmod +x /.docker/run.sh

# Change directory and declare startup command
WORKDIR /.docker/
CMD /.docker/run.sh
