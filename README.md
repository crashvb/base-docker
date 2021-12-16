# base-docker

## Overview

This docker image is a custom base image.

It is intended to be as minimalistic as possible, while still:

* Facilitating docker "entrypoint" best practices.
* Assisting with debian package deployment.
* Supporting organization-wide customizations.

## Docker "entrypoint" Best Practices

Two instructions control what process is spawned when a docker container is created: <tt>ENTRYPOINT</tt> and <tt>CMD</tt>. The full documentation for these, and other instructions is [available online](https://docs.docker.com/reference/builder/), and it is *strongly* recommended that it is reviewed prior to creating Dockerfiles.

In brief, the <tt>ENTRYPOINT</tt> instruction specifies _what_ process will be spawned. If it is defined in exec form the executable is launched directly; otherwise, it is provided as an argument to `/bin/sh -c`. The <tt>CMD</tt> instruction specifies _how_ the process will be spawned. If it is defined in exec form it is appended directly to the <tt>ENTRYPOINT</tt> arguments; otherwise, it processed by a command shell before the resultant is appended.

By defining both instructions in the base image, and by embedding a shell script, the following is accomplished:

* Dockerfile restrictions as to the existence and / or pairing of the instructions are satisfied.
* A fail-safe command is present in every derived imaged.
* Container initialization is facilitated as modifications to the embedded shell script will be executed before the main process.

NOTE: Although launching multiple processes using the entrypoint is possible, it is recommended that a process control system be used instead; such as [supervisord](https://supervisord.org/).

### Entrypoint Script

The emedded entrypoint script is located at `/sbin/entrypoint` and performs the following actions:

1. All scripts in `/etc/entrypoint.d/` are executed.
2. The file `$EP_RUN` is created.
3. The script arguments, from `CMD` are executed.

#### Environment Variables for Sub-scripts

* <tt>EP_PWGEN_LENGTH</tt> - The length of randomly generated passwords (default: `64`).
* <tt>EP_RUN</tt> - The fully-qualified path to the entrypoint run file: `/var/local/container_initialized`.
* <tt>EP_SECRETS_ROOT</tt> - The directory in which docker secrets are mounted. (default: `/run/secrets`).
* <tt>EP_USER</tt> - The name of the user as which to execute `CMD`.

#### Exported Functions for Sub-scripts

* <tt>log</tt> - Logs to standard output.
* <tt>generate_password</tt> - Generates a random password.
* <tt>render_template</tt> - Renders a given bash template.

#### Sample Entrypoint Script

```bash
#!/bin/bash
# /etc/entrypoint.d/foo

set -e

# Configure: foo
if [[ ! -e $EP_RUN ]] ; then
	log "Configuring $(basename $0) for first run ..."
	export VAR1=${VAR1:=VAL1}

	# Interpolate all variables
	VAR2=VAL2 render_template /usr/local/share/foo.conf /etc/foo/foo.conf

	# Interpolate select variables
	render_template /usr/local/share/bar.conf /etc/bar/bar.conf "\$ONLY \$THESE \$VARS"
fi
```

#### Entrypoint Scripts

#### ca-certificates

The embedded entrypoint script is located at `/etc/entrypoint.d/ca-certificates` and performs the following actions:

1. Certificates located in `/usr/share/ca-certificates/docker/` are deployted into the containers trust store.

### Healthcheck Script

The emedded healthcheck script is located at `/sbin/healthcheck` and performs the following actions:

1. If the container has not finished initializing, the script returns success.
2. Scripts in `/etc/healthcheck.d/` are executed, aborting after the first failure.

#### Exported Functions for Sub-scripts

* <tt>log</tt> - Logs to standard output.

#### Sample Healthcheck Script

```bash
#!/bin/bash
# /etc/healthcheck.d/foo

set -e

log "Checking if $(basename $0) is healthy ..."
ps --pid=1
```

## Debian Package Deployment

A typical Dockerfile will install packages similar to the following:

```dockerfile
RUN apt-get update && \
	apt-get install --no-install-recommends --yes long list of packages && \
	apt-get clean && \
	apt-get autoremove && \
	rm --force --recursive /tmp/* /var/lib/apt/lists/* /var/tmp/*
```

While effective, this boilerplate code is on the edge of readability, and can be expressed more simply as `RUN docker-apt <long list of packages>`.

For that purpose, three scripts have been embedded in the base image:

* <tt>docker-apt-install</tt> - Updates the aptitude repository list and installs given arguments.
* <tt>docker-apt-clean</tt> - Cleans transient aptitude caches.
* <tt>docker-apt</tt> - Invokes both of the above scripts.

### Environment Variables for docker-apt-install

* APT_ALL_REPOS - If defined, all configured repositories will be enabled before installing packges.

## Organization-wide Customizations

As of yet, this images does not contain any customizations; however, in the future it could contain common packages or initialization scripts. Typical uses could include:

* Generation and / or distribution of SSH authorized_keys and known_hosts files.

## Standard Configuration

### Container Layout

```
/
├─ etc/
│  ├─ entrypoint.d/
│  └─ healthcheck.d/
├─ sbin/
│  ├─ docker-yum
│  ├─ docker-yum-clean
│  ├─ docker-yum-install
│  ├─ entrypoint
│  ├─ entrypoint.ca-certificates
│  └─ healthcheck
├─ usr/
│  └─ share/
│     └─ ca-certificates/
│        └─ docker/
└─ var/
   └─ local/
      └─ container_initialized
```

### Exposed Ports

None.

### Volumes

None.

## Development

[Source Control](https://github.com/crashvb/base-docker)

