#!/usr/bin/env python

USER = 'orchard'
SSH_PORT = 22
SSHKEY = '/home/{}/.ssh/id_rsa'.format(USER)

MON_HOSTS = ['mon1', 'mon2', 'mon3']
MDS_HOSTS = ['mds1', 'mds2']
OSDS = {
        'osd1': [0, 1, 2, 3],
        'osd2': [4, 5, 6, 7], 
        'osd3': [8, 9, 10, 11]
        }
