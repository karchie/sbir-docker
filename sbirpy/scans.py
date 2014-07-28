# Copyright (c) 2014 Washington University School of Medicine
# Author: Kevin A. Archie <karchie@wustl.edu>

import argparse
import datetime
import getpass
from itertools import izip, chain, repeat
from warnings import warn

import pyxnat
import boto.ec2
import docker

def get_sessions(xnat, project_id=None, scan_type_pred=None, session_pred=None):
    """
scan type_pred takes the scan type string, true if should be included
session_pred takes a tuple (project,subject.session), true if should be included
    """
    scantable = xnat.array.scans(project_id=project_id,
                                 columns=['xnat:mrSessionData/label',
                                          'xnat:mrScanData/type',
                                          'xnat:subjectData/label'])
    (proj_idx,
     subj_idx,
     scan_idx,
     expt_idx,
     type_idx) = map(lambda name: scantable.headers().index(name),
                     ['project',
                      'subject_label',
                      'xnat:mrscandata/id',
                      'xnat:mrsessiondata/label',
                      'xnat:mrscandata/type'])
                     
    sessions = {}
    for scan in scantable.items():
        if not scan_type_pred or scan_type_pred(scan[type_idx]):
            key = (scan[proj_idx], scan[subj_idx], scan[expt_idx])
            if not session_pred or session_pred(key):
                sessions.setdefault(key, {})[scan[scan_idx]] = scan[type_idx]
    return sessions


def partition(n, iterable, padvalue=None):
    "partition(3, 'abcdefg', 'x') --> ('a','b','c'), ('d','e','f'), ('g','x','x')"
    return izip(*[chain(iterable, repeat(padvalue, n-1))]*n)



# TODO: spin up instance
# TODO: issue docker request


# TODO: snippet like this for evaluating whether a scan rec should get passed to spot_freesurfer
#    fs_rsrc = xnat.select.project(project).subject(subject_label).experiment(expt_label).resource('FREESURFER')
#    if fs_rsrc.exists():
#        return None


def request_spot(aws, price, image_id, n, request_duration, key_name, security_groups, instance_type, user_data, az=None):
    if request_duration:
        now = datetime.datetime.utcnow()
        later = (now + request_duration).isoformat()
    else:
        later = None
    if az:
        zone = aws.region.name + az
    else:
        zone = None
    reqs = aws.request_spot_instances(price=price, image_id=image_id, count=n,
                                      valid_from=None,
                                      valid_until=(later and later.isoformat()),
                                      key_name=key_name,
                                      placement=zone,
                                      security_groups=security_groups,
                                      user_data=user_data,
                                      instance_type=instance_type)
    return reqs


def spot_docker(xnat,
                xnat_password,
                scanrecs,
                aws,
                price,
                image_id,
                key_name,
                instance_type,
                az=None,
                security_groups=None):
    scanspec = ' '.join(['{}:{}:{}:{}'.format(k[0],k[1],k[2],min(v,key=int)) for (k,v) in scanrecs])
    xnat_cred = '{}:{}'.format(xnat._user, xnat_password)
    user_data = """\
#!/bin/sh
XNAT_CRED={}:{} sh /mnt/nfs/tools/sbir-docker/sh/run-docker-jobs.sh {}
sleep 300;
while [ -n "$(docker -H tcp://0.0.0.0:4243 ps -q)" ]; do sleep 600; done
shutdown -h now
""".format(xnat._user, xnat_password, scanspec)

    return request_spot(aws, price, image_id, 1, None, key_name, security_groups, instance_type, user_data, az)

def del_resources(xnat, resource_name, project_id=None, scan_type_pred=None, sessions_pred=None, sessions=None):
    if not sessions:
        sessions = get_sessions(xnat, project_id, scan_type_pred, sessions_pred)
    for (proj, subj, expt) in sessions:
        print "trying {} {} {}...".format(proj, subj, expt)
        rsrc = xnat.select.project(proj).subject(subj).experiment(expt).resource(resource_name)
        if rsrc.exists():
            print "Deleting {} {} resource {}".format(proj, expt, resource_name)
            rsrc.delete(True)


def resource_exists(xnat, project, subject, experiment, resource):
    return xnat.select.project(project).subject(subject).experiment(experiment).resource(resource).exists()

def scans_main():
    parser = argparse.ArgumentParser(description='Talk to XNAT')
    parser.add_argument('--xnat', help='XNAT base URL')
    parser.add_argument('--user', help='XNAT login')
    parser.add_argument('--docker', help='Docker URL')
    parser.add_argument('--region', help='AWS region')
    parser.add_argument('--access-key', help='AWS access key ID')
    parser.add_argument('--secret-key', help='AWS secret access key')
    
    args = parser.parse_args()
    
    if args.user:
        user = args.user
    else:
        user = raw_input('Username [%s]: ' % getpass.getuser())
        if not user:
            user = getpass.getuser()
            
    password = getpass.getpass()
    
    xnat = pyxnat.Interface(args.url, user, password)

    sessions = get_sessions(xnat, 'ADNI_ALL',
                            lambda t : 'RAGE' in t,
                            lambda t : not resource_exists(xnat, t[0], t[1], t[2], 'FREESURFER'))

    print sessions
    
if __name__ == "__main__":
    scans_main()
