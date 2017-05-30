#!/bin/sh

# Do we need to register an account?
quickstart=0
test -f /srv/mail/ssl/acme/conf/target || quickstart=1

test -d /srv/mail/ssl/acme/conf || mkdir -p /srv/mail/ssl/acme/conf
test -d /var/lib || mkdir /var/lib

ln -s /srv/mail/ssl/acme /var/lib

cat > /srv/mail/ssl/acme/conf/responses <<EOF
"acme-enter-email": ""
"acme-agreement:https://letsencrypt.org/documents/LE-SA-v1.1.1-August-1-2016.pdf": true
"acmetool-quickstart-choose-server": https://acme-v01.api.letsencrypt.org/directory
"acmetool-quickstart-choose-method": listen
"acmetool-quickstart-complete": true
"acmetool-quickstart-install-cronjob": false
"acmetool-quickstart-install-haproxy-script": false
"acmetool-quickstart-install-redirector-systemd": false
"acmetool-quickstart-key-type": rsa
"acmetool-quickstart-rsa-key-size": 2048
"acmetool-quickstart-ecdsa-curve": nistp256
EOF

cat > /srv/mail/ssl/acme/conf/perm <<EOF
keys 0640 0710 0 6
EOF

# Do quickstart to register an account
if [ $quickstart -eq 1 ]; then
	/opt/local/bin/acmetool quickstart --batch
fi

# Request the primary hostnames
dovecot_dom=$(mdata-get dovecot:primary_hostname || true)
hostname=$(mdata-get sdc:hostname).$(mdata-get sdc:dns_domain)

echo '14 5 * * 0 /opt/local/bin/acmetool reconcile' >> /etc/cron.d/crontabs/root

/opt/local/bin/acmetool want $dovecot_dom $hostname 

