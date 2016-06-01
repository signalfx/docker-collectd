# Dockerfile for base collectd install

FROM ubuntu:15.04
MAINTAINER SignalFx Support <support+collectd@signalfx.com>

# Install common softwares
ENV DEBIAN_FRONTEND noninteractive
ENV EXPECTED_PLUGIN_VERSION 0.0.21
ENV EXPECTED_COLLECTD_VERSION 5.5.1.sfx0

# Add in startup script
ADD run.sh /.docker/
# Setup our collectd
ADD configs /tmp/

# Install all apt-get utils and required repos
RUN apt-get install -y apt-transport-https software-properties-common curl vim && \
    add-apt-repository ppa:signalfx/collectd-release && \
    add-apt-repository ppa:signalfx/collectd-plugin-release && \
    apt-get update && \
    apt-get -y upgrade && \
    # Install SignalFx Plugin and collectd
    apt-get install -y signalfx-collectd-plugin collectd jq && \
    grep "VERSION = \"$EXPECTED_PLUGIN_VERSION\"" /opt/signalfx-collectd-plugin/signalfx_metadata.py && \
    collectd -h | grep $EXPECTED_COLLECTD_VERSION && \
    # Clean up existing configs
    rm -rf /etc/collectd && \
    # Install default configs
    mv /tmp/collectd /etc/ && \
    # Install unzip and pip
    apt-get install -qy unzip python-pip && \
    # Download the SignalFx docker-collectd-plugin
    curl -L "https://github.com/signalfx/docker-collectd-plugin/archive/master.zip" --output /tmp/master.zip && \
    # Extract the SignalFx docker-collectd-plugin
    unzip /tmp/master.zip -d /tmp && \
    # Move the SignalFx docker-collectd-plugin into place
    mv /tmp/docker-collectd-plugin-master/ /usr/share/collectd/docker-collectd-plugin && \
    # Install pip requirements for the docker-collectd-plugin
    pip install -r /usr/share/collectd/docker-collectd-plugin/requirements.txt && \
    # Move the managed config into place
    cp /usr/share/collectd/docker-collectd-plugin/dockerplugin.conf /etc/collectd/managed_config/ && \
    # Clean up the docker-collectd-plugin zip file
    rm /tmp/master.zip && \
    # Set correct permissions on startup script
    chmod +x /.docker/run.sh
    
# Change directory and declare startup command
WORKDIR /.docker/
CMD /.docker/run.sh
