#!/bin/bash

# run freshclamd once on provisioning
/opt/local/bin/freshclam

# enable clamav services
/usr/sbin/svcadm enable svc:/pkgsrc/clamav:clamd
/usr/sbin/svcadm enable svc:/pkgsrc/clamav:freshclamd
