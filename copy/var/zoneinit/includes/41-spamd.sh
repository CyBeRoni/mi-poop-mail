#!/bin/bash

# create cronjob for sa-update
echo '2 37 * * * /opt/local/bin/sa-update && svcadm refresh svc:/network/spamd' >> /etc/cron.d/crontabs/spamd

# enable spamd service
/usr/sbin/svccfg import /opt/local/lib/svc/manifest/spamd.xml
/usr/sbin/svcadm enable svc:/network/spamd

mkdir /var/run/spamd