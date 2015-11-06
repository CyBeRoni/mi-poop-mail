#!/bin/bash

# create cronjob for sa-update
echo '0 5 * * * spamd /opt/local/bin/sa-update && kill -SIGHUP $(cat /var/spamassassin/spamd.pid)' > /etc/cron.d/sa-update

# Run pyzor discover
sudo -u spamd pyzor --homedir /opt/local/etc/spamassassin ping || \
	sudo -u spamd pyzor --homedir /opt/local/etc/spamassassin discover

# enable spamd service
/usr/sbin/svccfg import /opt/local/lib/svc/manifest/spamd.xml
/usr/sbin/svcadm enable svc:/network/spamd
