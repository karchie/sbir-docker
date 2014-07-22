# Copyright (c) 2014 Washington University School of Medicine
# Author: Kevin A. Archie <karchie@wustl.edu>

import argparse
import getpass
import pyxnat
import docker


def get_sessions(xnat, project_id=None, scan_type_filter=None):
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
        if 'RAGE' in scan[type_idx]:
            key = (scan[proj_idx], scan[subj_idx], scan[expt_idx])
            if key not in sessions:
                sessions[key] = {}
            sessions[key][scan[scan_idx]] = scan[type_idx]
    return sessions

    

parser = argparse.ArgumentParser(description='Talk to XNAT')
parser.add_argument('--url', help='XNAT base URL')
parser.add_argument('--user', help='XNAT login')


args = parser.parse_args()

if args.user:
    user = args.user;
else:
    user = raw_input('Username [%s]: ' % getpass.getuser())
    if not user:
        user = getpass.getuser()

password = getpass.getpass();

xnat = pyxnat.Interface(args.url, user, password)

sessions = get_sessions(xnat, 'ADNI_ALL',
                        lambda t : 'RAGE' in t);

print sessions
