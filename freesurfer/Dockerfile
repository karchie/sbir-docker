FROM centos:centos6
MAINTAINER Kevin A. Archie <karchie@wustl.edu>

RUN yum update -y
RUN yum install -y tcsh libgomp bc perl-core

# Tomcat user / XNAT archive owner uid:gid 91:91
RUN groupadd --gid 91 xnat
RUN useradd --uid 91 --gid xnat --home-dir /home/xnat xnat
RUN mkdir -p /home/xnat

RUN chown -R xnat.xnat /home/xnat

ENV FREESURFER_HOME /freesurfer
ENV NO_FSFAST true

USER xnat
ENV HOME /home/xnat
WORKDIR /data
VOLUME ["/data", "/freesurfer"]
ENTRYPOINT ["/bin/bash"]
