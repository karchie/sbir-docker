FROM centos:centos6
MAINTAINER Kevin A. Archie <karchie@wustl.edu>

RUN yum update -y
RUN yum install -y tcsh libgomp bc perl-core

RUN groupadd --gid 91 xnat
RUN useradd --uid 91 --gid xnat --home-dir /home/xnat xnat
RUN mkdir -p /home/xnat

# freesurfer now mounted in
# ADD freesurfer-Linux-centos6_x86_64-stable-pub-v5.3.0.tar.gz /usr/local
# ADD license $FREESURFER_HOME/.license

RUN chown -R xnat.xnat /home/xnat

ENV FREESURFER_HOME /freesurfer
ENV NO_FSFAST true

USER xnat
ENV HOME /home/xnat
WORKDIR /data
VOLUME ["/archive", "/data", "/freesurfer"]
ENTRYPOINT ["/bin/bash"]
