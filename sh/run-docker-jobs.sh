#!/bin/bash
# Copyright (c) 2014 Washington University School of Medicine
# Author: Kevin A. Archie <karchie@wustl.edu>
# Intended to be called by instance user data
# as:
# XNAT_CRED=user:pass sh run-docker-jobs.sh PROJECT:SUBJECT:EXPT1:SCAN PROJECT:SUBJECT:EXPT2:SCAN ...
SCANTUPLES=$@

XNAT_HOST=https://my-xnat.org
DOCKER_HOST=tcp://0.0.0.0:4243
export DOCKER_HOST

#DOCKER=docker
# CentOS docker build (1.0.0) handles attached stdin/detached stderr/out differently from 0.8.1
# I would call the 1.0.0 behavior broken but I haven't argued that w/ docker people yet.
# The submission script below doesn't work with the 1.0.0 client.
DOCKER=/mnt/nfs/tools/sbir-docker/bin/docker-0.8.1

ARCHIVE_ROOT=/mnt/nfs/xnat/archive
OWNER=$(stat -c %u $ARCHIVE_ROOT)
GROUP=$(stat -c %g $ARCHIVE_ROOT)

for scantup in $SCANTUPLES; do
	PROJECT=$(echo $scantup | cut -f 1 -d :)
	SUBJECT=$(echo $scantup | cut -f 2 -d :)
	EXPERIMENT=$(echo $scantup | cut -f 3 -d :)
	SCAN=$(echo $scantup | cut -f 4 -d :)

	RESOURCE="projects/$PROJECT/subjects/$SUBJECT/experiments/$EXPERIMENT/resources/FREESURFER"

	$DOCKER run -a stdin -i -v $ARCHIVE_ROOT/$PROJECT/arc001/$EXPERIMENT:/data -v /mnt/nfs/tools/freesurfer:/freesurfer sbir/freesurfer <<EOF
. /freesurfer/SetUpFreeSurfer.sh
DICOM_FILE=\$(find /data/SCANS/$SCAN -name '*.dcm' -print -quit)

if [ -z "\$DICOM_FILE" ]; then
    echo Unable to find DICOM file in /data/SCANS/$SCAN - exiting >&2
    exit 1
fi

curl -X PUT -u "$XNAT_CRED" "$XNAT_HOST/data/$RESOURCE"  # create a session-level resource

# recon-all -sd /data/RESOURCES/FREESURFER -s $SUBJECT -i \$DICOM_FILE -autorecon1    # partial run for testing

# mkdir -p /data/RESOURCES/FREESURFER   # resource creation not reliably creating directory; this shouldn't be necessary

recon-all -sd /data/RESOURCES/FREESURFER -s $SUBJECT -i \$DICOM_FILE -all

# put the generated files into the resource catalog
curl -X POST -u "$XNAT_CRED" "$XNAT_HOST/data/services/refresh/catalog?resource=/archive/$RESOURCE&options=append"

exit 0
EOF

sleep 300						# stagger jobs by 5 minutes. This should probably be made a parameter somehow
done

exit 0
