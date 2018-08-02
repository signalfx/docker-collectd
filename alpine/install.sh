#!/bin/sh -e

ALPINE_VERSION=${1:-latest}
COLLECTD_STAGE=${2:-release}
PLUGIN_STAGE=${3:-release}
COLLECTD_ADDR=https://dl.signalfx.com/apks/collectd/alpine/${ALPINE_VERSION}/${COLLECTD_STAGE}/collectd.tar.gz
PLUGIN_ADDR=https://dl.signalfx.com/apks/signalfx-collectd-plugin/alpine/${ALPINE_VERSION}/${PLUGIN_STAGE}/signalfx-collectd-plugin.tar.gz

# Get paths to local apks for 'apk add' in case there are newer versions in remote repos
get_local_apk() {
    local APK_NAME=$1
    local REPO_DIR=$2
    local APK_PATH=`find $REPO_DIR -name "*.apk" | grep -e "${APK_NAME}-\d" | sort -V | tail -n1`
    if [ -z "$APK_PATH" ]; then
        echo "apk \"$APK_NAME\" not found in $REPO_DIR!"
        exit 1
    fi
    echo $APK_PATH
}

apk update
apk upgrade
apk add py-pip \
        unzip \
        jq \
        curl \
        coreutils
# Make directory for local signalfx-collectd repository
mkdir -p /repo
cd /repo
# Curl down and unarchive the collectd repo
curl -LOk ${COLLECTD_ADDR}
tar -xvzf /repo/collectd.tar.gz
rm /repo/collectd.tar.gz
ls -la /repo/collectd/x86_64
echo /repo/collectd >> /etc/apk/repositories
# Curl down and unarchive the signalfx-plugin repo
curl -LOk ${PLUGIN_ADDR}
tar -xvzf /repo/signalfx-collectd-plugin.tar.gz
rm /repo/signalfx-collectd-plugin.tar.gz
ls -la /repo/signalfx-collectd-plugin/x86_64
echo /repo/signalfx-collectd-plugin >> /etc/apk/repositories
# View the apk repository data
cat /etc/apk/repositories
# Update apk repository data
apk update
# Install collectd and signalfx-collectd-plugin
COLLECTD_REPO_DIR="/repo/collectd/x86_64/"
COLLECTD_APK=`get_local_apk 'collectd' $COLLECTD_REPO_DIR`
if [ "$COLLECTD_APK" = "$(apk search -x collectd).apk" ]; then
    apk add collectd \
            collectd-python \
            collectd-write_http \
            signalfx-collectd-plugin
else
    # remote repo has collectd with a version number greater than the local apk in /repo/collectd/
    # explicitly install collectd apks from local paths (requires --allow-untrusted even if the apks are signed)
    COLLECTD_PYTHON_APK=`get_local_apk 'collectd-python' $COLLECTD_REPO_DIR`
    COLLECTD_WRITE_HTTP_APK=`get_local_apk 'collectd-write_http' $COLLECTD_REPO_DIR`
    PLUGIN_REPO_DIR="/repo/signalfx-collectd-plugin/x86_64/"
    PLUGIN_APK=`get_local_apk 'signalfx-collectd-plugin' $PLUGIN_REPO_DIR`
    apk add --allow-untrusted $COLLECTD_APK \
                              $COLLECTD_PYTHON_APK \
                              $COLLECTD_WRITE_HTTP_APK \
                              $PLUGIN_APK
fi
# Clean up existing configs
rm -rf /etc/collectd
# Install default configs
mv /tmp/collectd /etc/
# Download the SignalFx docker-collectd-plugin
cd /tmp
curl -L "https://github.com/signalfx/docker-collectd-plugin/archive/master.zip" --output /tmp/docker-collectd-plugin.zip
# Extract the SignalFx docker-collectd-plugin
unzip /tmp/docker-collectd-plugin.zip -d /tmp
# Move the SignalFx docker-collectd-plugin into place
mv /tmp/docker-collectd-plugin-master/ /usr/share/collectd/docker-collectd-plugin
# Install pip requirements for the docker-collectd-plugin
pip install -r /usr/share/collectd/docker-collectd-plugin/requirements.txt
# Download the configuration file for docker-collectd-plugin
curl -L "https://github.com/signalfx/integrations/archive/master.zip" --output /tmp/integrations.zip
# Extract the configuration file for docker-collectd-plugin
unzip /tmp/integrations.zip -d /tmp
# Move the managed config into place
cp /tmp/integrations-master/collectd-docker/10-docker.conf /etc/collectd/managed_config/
# Set correct permissions on startup script
cd /run
rm -rf /tmp/*
