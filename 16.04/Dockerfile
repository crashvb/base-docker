FROM ubuntu:16.04
ARG org_opencontainers_image_created=undefined
ARG org_opencontainers_image_revision=undefined
LABEL \
	org.opencontainers.image.authors="Richard Davis <crashvb@gmail.com>" \
	org.opencontainers.image.base.name="ubuntu:16.04" \
	org.opencontainers.image.created="${org_opencontainers_image_created}" \
	org.opencontainers.image.description="Custom base image with tooling to support derivations." \
	org.opencontainers.image.licenses="Apache-2.0" \
	org.opencontainers.image.source="https://github.com/crashvb/base-docker" \
	org.opencontainers.image.revision="${org_opencontainers_image_revision}" \
	org.opencontainers.image.title="crashvb/base" \
	org.opencontainers.image.url="https://github.com/crashvb/base-docker"

USER root

# Install packages, download files ...
ADD docker-* entrypoint healthcheck /sbin/
ADD entrypoint.sh /usr/local/lib/
RUN docker-apt apt-transport-https ca-certificates curl gettext pwgen wget vim

# Configure: bash profile
RUN sed --in-place --expression="/^HISTSIZE/s/1000/9999/" --expression="/^HISTFILESIZE/s/2000/99999/" /root/.bashrc && \
	echo "set -o vi" >> /root/.bashrc && \
	echo "PS1='\${debian_chroot:+(\$debian_chroot)}\\\\t \[\\\\033[0;31m\]\u\[\\\\033[00m\]@\[\\\\033[7m\]\h\[\\\\033[00m\] [\w]\\\\n\$ '" >> /root/.bashrc && \
	touch ~/.hushlogin

# Configure: entrypoint, ca-certificates
RUN mkdir --mode=0755 --parents /etc/entrypoint.d/ /etc/healthcheck.d/ /usr/share/ca-certificates/docker/
ADD entrypoint.ca-certificates /etc/entrypoint.d/00ca-certificates

HEALTHCHECK CMD /sbin/healthcheck

ENTRYPOINT ["/sbin/entrypoint"]
CMD ["/bin/bash"]
