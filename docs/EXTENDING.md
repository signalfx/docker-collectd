# Extending SignalFx collectd Docker image

## Introduction

The SignalFx collectd Docker image includes collectd, the SignalFx collectd 
plugin and the SignalFx Docker collectd plugin. For information on 
configuring the container, please see the documentation located in the 
[README](../README.md).

```
Any modifications to this Docker image will need to be tested to ensure 
complete functionality. SignalFx has not tested all possible configurations.
```

## Dockerfile

Docker images are built from Dockerfiles. These are extension-less text files 
named *Dockerfile*. Read Docker's official 
[documentation](https://docs.docker.com/engine/reference/builder/) for more 
information on Dockerfiles.

A new Dockerfile should be created in an empty directory. This 
directory will act as the image workspace. The SignalFx collectd Docker 
image is located at [quay.io](https://quay.io/repository/signalfuse/collectd). 
This image should be extended in a new Docker image.  

```Dockerfile
# Reference base image
FROM quay.io/signalfuse/collectd
```

A name and contact information should be provided with the command *MAINTAINER*
for the new image.

```Dockerfile
# Reference base image
FROM quay.io/signalfuse/collectd

# Provide contact information
MAINTAINER <Name> <Contact Info>
```

## Plugins

Each SignalFx supported collectd integration has its own set of documentation
and managed configuration files. Please refer to the integrations page in 
SignalFx to find each plugin, documentation, and managed 
configuration files.

### ADD

The files for each plugin must be copied into the workspace. *ADD* is the 
command used to add a resource from the workspace to the Docker image. *ADD*
follows the syntax ```ADD <path to resource in workspace> <path in image>```

```Dockerfile
# Reference base image
FROM quay.io/signalfuse/collectd

# Provide contact information
MAINTAINER <Name> <Contact Info>

# Add files
ADD example-plugin/example-file.py /usr/share/collectd
ADD example-plugin/example-file.conf /usr/share/collectd
```

### RUN

The *RUN* command is used to execute shell commands while building an image.
This is the command that should be used to install additional apt packages, 
move files around, etc.  This is a good place to *chmod* custom run scripts 
after they have been added to the Docker image.

```Dockerfile
# Reference base image
FROM quay.io/signalfuse/collectd

# Provide contact information
MAINTAINER <Name> <Contact Info>

# Add files
ADD example-plugin/example-file.py /usr/share/collectd
ADD example-plugin/example-file.conf /usr/share/collectd

# Run shell commands
RUN <shell commands>
```

### WORKDIR

The *WORKDIR* command is used to set the working directory in the Dockerfile.
At the end of the file, the working directory should be set to /.docker/.
This is where the *run.sh* script is stored in the base Docker image. Custom
scripts should be copied here if they need to execute when the container 
starts.

```Dockerfile
# Reference base image
FROM quay.io/signalfuse/collectd

# Provide contact information
MAINTAINER <Name> <Contact Info>

# Add files
ADD example-plugin/example-file.py /usr/share/collectd
ADD example-plugin/example-file.conf /usr/share/collectd

# Run shell commands
RUN <shell commands>

# Change work directory
WORKDIR /.docker/
```

### CMD

*CMD* executes an executable when the container built from a Docker image 
starts. The SignalFx collectd Docker image has a script located in
/.docker/ and named *run.sh*. This script must be the last script executed by
*CMD*

```Dockerfile
# Reference base image
FROM quay.io/signalfuse/collectd

# Provide contact information
MAINTAINER <Name> <Contact Info>

# Add files
ADD example-plugin/example-file.py /usr/share/collectd
ADD example-plugin/example-file.conf /usr/share/collectd

# Run shell commands
RUN <shell commands>

# Change work directory
WORKDIR /.docker/

# Execute commands when the container starts
CMD /.docker/run.sh
```

### Custom startup scripts

If other scripts need to be executed at startup, they must be included in the
same *CMD* statement and chained together using *&&* with the SignalFx *run.sh*
script at the end of the chain.

```Dockerfile
# Reference base image
FROM quay.io/signalfuse/collectd

# Provide contact information
MAINTAINER <Name> <Contact Info>

# Add files
ADD example-plugin/example-file.py /usr/share/collectd
ADD example-plugin/example-file.conf /usr/share/collectd

# Adding custom startup script
ADD example-script.sh /.docker/

# Run shell commands
# Making startup script executable
RUN chmod +x /.docker/example-script.sh

# Change work directory
WORKDIR /.docker/

# Execute commands when the container starts (example-script.sh && run.sh)
CMD /.docker/example-script.sh && /.docker/run.sh
```

### Variables

Run time variables should be read from environment variables and passed into 
the container at run time using the ​*-e*​ flag.  These variables can be used to 
simplify the configuration of plugins, however additional steps must be taken 
to assign the values to the appropriate plugin configuration file.

```BASH
$ docker run --privileged \
   -e "SF_API_TOKEN=XXXXXXXXXXXXXXXXXXXXXX" \
   -v /etc/hostname:/mnt/hostname:ro \
   -v /proc:/mnt/proc:ro \
   -v /var/run/docker.sock:/var/run/docker.sock \
   -v /etc:/mnt/etc:ro \
   quay.io/signalfuse/collectd
```

The following environment variables are reserved by SignalFx and should not be
used in custom scripts:

```
SF_API_TOKEN
COLLECTD_CONFIGS
COLLECTD_HOSTNAME
COLLECTD_BUFFERSIZE
SF_INGEST_HOST
COLLECTD_INTERVAL
COLLECTD_FLUSHINTERVAL
AWS_UNIQUE_ID
```

## Building The Image

To build the Dockerfile into an image, execute the following command from the
root of the Dockerfile workspace.

```
$ docker build -t <custom tag name> .
```

This will build a Docker image and tag it with the name specified as the 
*custom tag name*

## Running

To run the new Docker image, follow the instructions provided in the SignalFx
collectd Docker [README](../README.md).