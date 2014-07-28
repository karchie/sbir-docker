#!/bin/bash
# Copyright (c) 2014 Washington University School of Medicine
# Author: Kevin A. Archie <karchie@wustl.edu>
# Intended to be called by instance user data
# as:
# XNAT_CRED=user:pass sh run-docker-jobs.sh PROJECT:SUBJECT:EXPT1:SCAN PROJECT:SUBJECT:EXPT2:SCAN ...
SCANTUPLES=$@

# XNAT_HOST=http://54.88.203.85/xnat  # cluster
# XNAT_HOST=http://54.210.31.65:8080  # xnat02
DOCKER_HOST=tcp://0.0.0.0:4243
export DOCKER_HOST

#DOCKER=docker
DOCKER=/mnt/nfs/tools/sbir-docker/bin/docker-0.8.1

ARCHIVE_ROOT=/mnt/nfs/xnat/archive
OWNER=$(stat -c %u $ARCHIVE_ROOT)
GROUP=$(stat -c %g $ARCHIVE_ROOT)
OUTPUT_ROOT=/mnt/nfs/resources

for scantup in $SCANTUPLES; do
	PROJECT=$(echo $scantup | cut -f 1 -d :)
	SUBJECT=$(echo $scantup | cut -f 2 -d :)
	EXPERIMENT=$(echo $scantup | cut -f 3 -d :)
	SCAN=$(echo $scantup | cut -f 4 -d :)

#	RESOURCE="projects/$PROJECT/subjects/$SUBJECT/experiments/$EXPERIMENT/resources/FREESURFER"

	OUTPUT_DIR=$OUTPUT_ROOT/$PROJECT/arc001/$EXPERIMENT
	mkdir -p $OUTPUT_DIR
	chown ${OWNER}:${GROUP} $OUTPUT_DIR

	$DOCKER run -a stdin -i -v $ARCHIVE_ROOT/$PROJECT/arc001/$EXPERIMENT:/archive -v $OUTPUT_DIR:/data -v /mnt/nfs/tools/freesurfer:/freesurfer sbir/freesurfer <<EOF
. /freesurfer/SetUpFreeSurfer.sh
DICOM_FILE=\$(find /archive/SCANS/$SCAN -name '*.dcm' -print -quit)

if [ -z "\$DICOM_FILE" ]; then
    echo Unable to find DICOM file in /data/SCANS/$SCAN - exiting >&2
    exit 1
fi

# curl -X PUT -u "$XNAT_CRED" "$XNAT_HOST/data/$RESOURCE"
# recon-all -sd /data/RESOURCES/FREESURFER -s $SUBJECT -i \$DICOM_FILE -autorecon1
mkdir -p /data/RESOURCES/FREESURFER
recon-all -sd /data/RESOURCES/FREESURFER -s $SUBJECT -i \$DICOM_FILE -all

# curl -X POST -u "$XNAT_CRED" "$XNAT_HOST/data/services/refresh/catalog?resource=/archive/$RESOURCE&options=append"

exit 0
EOF

sleep 900						# just doing recon1? stagger 15 mins
done

exit 0
