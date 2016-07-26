# Dockerfile for base collectd install

FROM alpine:3.4
MAINTAINER SignalFx Support <support+collectd@signalfx.com>

# Define collectd and plugin versions
ENV EXPECTED_PLUGIN_VERSION 0.0.22
ENV EXPECTED_COLLECTD_VERSION 5.5.1-r0

# Add default collectd configs
ADD configs /tmp/

# Add in startup script
ADD run.sh /.docker/

# Install collectd and dependencies
RUN apk --update add \
          bash \
          collectd=${EXPECTED_COLLECTD_VERSION} \
          collectd-python \
          collectd-write_http \
          python \
    # Installation dependencies that will be removed
    && apk --update add --virtual install-dependencies \
          build-base \
          curl \
          linux-headers \
          py-pip \
          python-dev \
          tar \
    # Download the signalfx-collectd-plugin
    && curl -sL https://github.com/signalfx/signalfx-collectd-plugin/archive/v${EXPECTED_PLUGIN_VERSION}.tar.gz | tar -zxC /tmp \
    # Install pip requirements for the signalfx-collectd-plugin
    && pip install -r /tmp/signalfx-collectd-plugin-${EXPECTED_PLUGIN_VERSION}/requirements.txt \
    # Move the signalfx-collectd-plugin into place
    && mkdir -p /opt/signalfx-collectd-plugin \
    && cp /tmp/signalfx-collectd-plugin-${EXPECTED_PLUGIN_VERSION}/src/aggregator.py \
          /tmp/signalfx-collectd-plugin-${EXPECTED_PLUGIN_VERSION}/src/collectd_dogstatsd.py \
          /tmp/signalfx-collectd-plugin-${EXPECTED_PLUGIN_VERSION}/src/dogstatsd.py \
          /tmp/signalfx-collectd-plugin-${EXPECTED_PLUGIN_VERSION}/src/dummy_collectd.py \
          /tmp/signalfx-collectd-plugin-${EXPECTED_PLUGIN_VERSION}/src/signalfx_metadata.py \
          /tmp/signalfx-collectd-plugin-${EXPECTED_PLUGIN_VERSION}/types.db.plugin \
          /opt/signalfx-collectd-plugin/ \
    # Clean up existing configs
    && rm -rf /etc/collectd \
    # Install default configs
    && mv /tmp/collectd /etc/ \
    # Download the SignalFx docker-collectd-plugin
    && curl -sL "https://github.com/signalfx/docker-collectd-plugin/archive/master.tar.gz" | tar -zxC /tmp \
    # Move the SignalFx docker-collectd-plugin into place
    && mv /tmp/docker-collectd-plugin-master/ /usr/share/collectd/docker-collectd-plugin \
    # Install pip requirements for the docker-collectd-plugin
    && pip install -r /usr/share/collectd/docker-collectd-plugin/requirements.txt \
    # Download the configuration file for docker-collectd-plugin
    && curl -sL "https://github.com/signalfx/integrations/archive/master.tar.gz" | tar -zxC /tmp \
    # Move the managed config into place
    && cp /tmp/integrations-master/collectd-docker/10-docker.conf /etc/collectd/managed_config/ \
    # Set correct permissions on startup script
    && chmod +x /.docker/run.sh \
    # Uninstall helper packages
    && apk del install-dependencies \
    # Clean up tmp directory
    && rm -rf /tmp/* /var/cache/apk/*
    
# Change directory and declare startup command
WORKDIR /.docker/
CMD /.docker/run.sh
