FROM alpine:3.4

MAINTAINER SignalFx Support <support+collectd@signalfx.com>

# Specify Versions
ARG PLUGIN_VERSION=0.0.27
ARG PLUGIN_PKG=sfx0
ARG COLLECTD_VERSION=5.5.2
ARG COLLECTD_PKG=sfx0

# Expected versions to check against
ARG EXPECTED_COLLECTD_VERSION=${COLLECTD_VERSION}
ARG EXPECTED_PLUGIN_VERSION=${PLUGIN_VERSION}

ARG COLLECTD_ADDR=https://dl.signalfx.com/apks/collectd/alpine/release/collectd/x86_64
ARG PLUGIN_ADDR=https://dl.signalfx.com/apks/signalfx-collectd-plugin/alpine/release/signalfx-collectd-plugin/x86_64

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
    && mkdir -p /tmp/repo/collectd/x86_64 \
    # Back up apk repositories file
    && cp /etc/apk/repositories /tmp/repo \
    # Change to temporary repo
    && cd /tmp/repo/collectd/x86_64 \
    # Curl down signalfx-collectd repository
    && curl -LOk ${COLLECTD_ADDR}/APKINDEX.tar.gz \
    && curl -LOk ${COLLECTD_ADDR}/collectd-${COLLECTD_VERSION}-r${COLLECTD_PKG}.apk \
    && curl -LOk ${COLLECTD_ADDR}/collectd-apache-${COLLECTD_VERSION}-r${COLLECTD_PKG}.apk \
    && curl -LOk ${COLLECTD_ADDR}/collectd-curl-${COLLECTD_VERSION}-r${COLLECTD_PKG}.apk \
    && curl -LOk ${COLLECTD_ADDR}/collectd-iptables-${COLLECTD_VERSION}-r${COLLECTD_PKG}.apk \
    && curl -LOk ${COLLECTD_ADDR}/collectd-java-${COLLECTD_VERSION}-r${COLLECTD_PKG}.apk \
    && curl -LOk ${COLLECTD_ADDR}/collectd-mysql-${COLLECTD_VERSION}-r${COLLECTD_PKG}.apk \
    && curl -LOk ${COLLECTD_ADDR}/collectd-network-${COLLECTD_VERSION}-r${COLLECTD_PKG}.apk \
    && curl -LOk ${COLLECTD_ADDR}/collectd-nginx-${COLLECTD_VERSION}-r${COLLECTD_PKG}.apk \
    && curl -LOk ${COLLECTD_ADDR}/collectd-perl-${COLLECTD_VERSION}-r${COLLECTD_PKG}.apk \
    && curl -LOk ${COLLECTD_ADDR}/collectd-postgresql-${COLLECTD_VERSION}-r${COLLECTD_PKG}.apk \
    && curl -LOk ${COLLECTD_ADDR}/collectd-python-${COLLECTD_VERSION}-r${COLLECTD_PKG}.apk \
    && curl -LOk ${COLLECTD_ADDR}/collectd-snmp-${COLLECTD_VERSION}-r${COLLECTD_PKG}.apk \
    && curl -LOk ${COLLECTD_ADDR}/collectd-virt-${COLLECTD_VERSION}-r${COLLECTD_PKG}.apk \
    && curl -LOk ${COLLECTD_ADDR}/collectd-write_http-${COLLECTD_VERSION}-r${COLLECTD_PKG}.apk \
    && ls -la /tmp/repo/collectd/x86_64 \
    # Add locally stored signalfx-collectd repository
    && echo /tmp/repo/collectd >> /etc/apk/repositories \
    # Make directory for signalfx-collectd-plugin repository
    && mkdir -p /tmp/repo/signalfx-collectd-plugin/x86_64/ \
    && cd /tmp/repo/signalfx-collectd-plugin/x86_64/ \
    # Curl down signalfx-collectd-plugin repository
    && curl -LOk ${PLUGIN_ADDR}/APKINDEX.tar.gz \
    && curl -LOk ${PLUGIN_ADDR}/signalfx-collectd-plugin-${PLUGIN_VERSION}-r${PLUGIN_PKG}.apk \
    && ls -la /tmp/repo/signalfx-collectd-plugin/x86_64 \
    # Add locally stored signalfx-collect-plugin repository
    && echo /tmp/repo/signalfx-collectd-plugin >> /etc/apk/repositories \
    && cat /etc/apk/repositories \
    # Update apk repository data
    && apk update \
    # Install collectd and signalfx-collectd-plugin
    && apk add collectd \
               collectd-apache \
               collectd-curl \
               collectd-iptables \
               collectd-java \
               collectd-mysql \
               collectd-network \
               collectd-nginx \
               collectd-perl \
               collectd-postgresql \
               collectd-python \
               collectd-snmp \
               collectd-virt \
               collectd-write_http \
               signalfx-collectd-plugin \
    && grep "VERSION = \"$EXPECTED_PLUGIN_VERSION\"" /opt/signalfx-collectd-plugin/signalfx_metadata.py \
    && collectd -h | grep $EXPECTED_COLLECTD_VERSION \
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
    # Restore original apk repositories file
    && rm /etc/apk/repositories \
    && cp /tmp/repo/repositories /etc/apk/ \
    # Set correct permissions on startup script
    && cd /run \
    && chmod +x run.sh \
    && rm -rf /tmp/* \
    
# Set the shell as the entry point
ENTRYPOINT sh

# Execute the script run.sh in the shell
CMD /run/run.sh
