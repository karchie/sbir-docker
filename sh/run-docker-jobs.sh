#!/bin/bash
# Copyright (c) 2014 Washington University School of Medicine
# Author: Kevin A. Archie <karchie@wustl.edu>
# Intended to be called by instance user data
# as:
# XNAT_CRED=user:pass sh run-docker-jobs.sh PROJECT SUBJECT:EXPT1:SCAN SUBJECT:EXPT2:SCAN ...
PROJECT=$1
shift
SCANTUPLES=$@

XNAT_HOST=http://54.210.31.65:8080

for scantup in $SCANTUPLES; do
	SUBJECT=$(echo $scantup | cut -f 1 -d :)
	EXPERIMENT=$(echo $scantup | cut -f 2 -d :)
	SCAN=$(echo $scantup | cut -f 3 -d :)

	RESOURCE="projects/$PROJECT/subjects/$SUBJECT/experiments/$EXPERIMENT/resources/FREESURFER"

	echo docker run -i -v /mnt/nfs/xnat/archive/$PROJECT/arc001/$EXPERIMENT:/data -v /mnt/nfs/tools/freesurfer:/freesurfer sbir/freesurfer <<EOF
DICOM_FILE=\$(find /data/SCANS/$SCAN -name '*dcm' -print -quit)

if [-z "\$DICOM_FILE" ]; then
    echo Unable to find DICOM file in /data/SCANS/$SCAN - exiting >&2
    exit 1
fi

curl -X PUT -u "$XNAT_CRED" "$XNAT_HOST/data/$RESOURCE"
recon-all -sd /data/RESOURCES/FREESURFER -s $SUBJECT -i \$DICOM_FILE
recon-all -sd /data/RESOURCES/FREESURFER -s $SUBJECT -autorecon1
# recon-all -sd /data/RESOURCES/FREESURFER -s $SUBJECT -all
EOF

sleep 60						# just doing recon1? stagger only a minute
done

exit 0
