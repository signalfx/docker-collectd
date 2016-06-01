# Dockerfile for base collectd install

FROM ubuntu:15.04
MAINTAINER SignalFx Support <support+collectd@signalfx.com>

# Install common softwares
ENV DEBIAN_FRONTEND noninteractive

# Install all apt-get utils and required repos
RUN apt-get install -y apt-transport-https software-properties-common curl vim
RUN add-apt-repository ppa:signalfx/collectd-release && add-apt-repository ppa:signalfx/collectd-plugin-release
ENV EXPECTED_PLUGIN_VERSION 0.0.21
ENV EXPECTED_COLLECTD_VERSION 5.5.1.sfx0
RUN apt-get update && apt-get -y upgrade

# Install SignalFx Plugin and collectd
RUN apt-get install -y signalfx-collectd-plugin collectd jq
RUN grep "VERSION = \"$EXPECTED_PLUGIN_VERSION\"" /opt/signalfx-collectd-plugin/signalfx_metadata.py
RUN collectd -h | grep $EXPECTED_COLLECTD_VERSION

# clean up existing configs
RUN rm -rf /etc/collectd

# Setup our collectd
ADD configs /etc/

#Install unzip and pip
RUN apt-get install -qy unzip python-pip

#Download the SignalFx docker-collectd-plugin
RUN curl -L "https://github.com/signalfx/docker-collectd-plugin/archive/master.zip" --output /tmp/master.zip

#Extract the docker plugin
RUN unzip /tmp/master.zip -d /tmp

#Move the docker plugin into place
RUN mv /tmp/docker-collectd-plugin-master/ /usr/share/collectd/docker-collectd-plugin

#Install pip requirements
RUN pip install -r /usr/share/collectd/docker-collectd-plugin/requirements.txt

#Move the managed config into place
RUN cp /usr/share/collectd/docker-collectd-plugin/dockerplugin.conf /etc/collectd/managed_config/

#Clean up the zip files
RUN rm /tmp/master.zip

# Setup startup
ADD run.sh /.docker/

# Set correct permissions
RUN chmod +x /.docker/run.sh

WORKDIR /.docker/
CMD /.docker/run.sh
