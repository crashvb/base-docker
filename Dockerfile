FROM ubuntu:16.04
MAINTAINER Richard Davis <crashvb@gmail.com>

USER root

# Install packages, download files ...
ADD docker-* entrypoint /sbin/
RUN docker-apt apt-transport-https ca-certificates curl gettext pwgen wget

# Configure: bash profile
RUN sed --in-place "s/HISTSIZE=1000/HISTSIZE=9999/g" /root/.bashrc && \
	sed --in-place "s/HISTFILESIZE=2000/HISTFILESIZE=99999/g" /root/.bashrc && \
	echo "# --- Docker Bash Profile ---" >> /root/.bashrc && \
	echo "set -o vi" >> /root/.bashrc && \
	echo "PS1='\${debian_chroot:+(\$debian_chroot)}\\\\t \[\\\\033[0;31m\]\u\[\\\\033[00m\]@\[\\\\033[7m\]\h\[\\\\033[00m\] [\w]\\\\n\$ '" >> /root/.bashrc && \
	touch ~/.hushlogin

# Configure: ca-certificates
RUN mkdir --mode=0755 --parents /usr/share/ca-certificates/docker/

# Configure: entrypoint
RUN mkdir --mode=0755 --parents /etc/entrypoint.d/
ADD entrypoint.ca-certificates /etc/entrypoint.d/00ca-certificates

ENTRYPOINT ["/sbin/entrypoint"]
CMD ["/bin/bash"]
