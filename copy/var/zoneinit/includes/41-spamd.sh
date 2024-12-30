#!/bin/bash

# create cronjob for sa-update
echo '0 5 * * * /opt/local/bin/sa-update && kill -SIGHUP $(cat /var/spamassassin/spamd.pid)' >> /etc/cron.d/crontabs/spamd

# enable spamd service
/usr/sbin/svccfg import /opt/local/lib/svc/manifest/spamd.xml
/usr/sbin/svcadm enable svc:/network/spamd
