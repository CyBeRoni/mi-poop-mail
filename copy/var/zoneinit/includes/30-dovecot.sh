#!/bin/sh

primary_hostname=$(mdata-get dovecot:primary_hostname || true)
qualify_domain=$(mdata-get dovecot:qualify_domain || true)
hostname=$(mdata-get sdc:hostname)
domain=$(mdata-get sdc:dns_domain)


if [ "x${primary_hostname}" = "x" ]; then
  primary_hostname=${hostname}.${domain}
fi

if [ "x${qualify_domain}" != "x" ]; then
  echo "auth_default_realm = ${qualify_domain}" > /opt/local/etc/dovecot/conf.d/10-auth-qualify-domain.conf
fi

curl https://raw.githubusercontent.com/internetstandards/dhe_groups/master/ffdhe3072.pem > /opt/local/etc/dovecot/dhparams.pem

# Create config and sieve dirs, ignoring if they already exist
mkdir -p /srv/mail/dovecot/conf || true
mkdir -p /srv/mail/dovecot/sieve/before || true
mkdir -p /srv/mail/dovecot/sieve/after || true

# Create a local config file, if it doesn't exist already
test -e /srv/mail/dovecot/conf/local.conf || echo '# local dovecot config items here' > /srv/mail/dovecot/conf/local.conf

# Create log dir
umask 002
mkdir /var/log/dovecot || true
touch /var/log/dovecot/main
touch /var/log/dovecot/info
touch /var/log/dovecot/debug
chown -R dovecot:mail /var/log/dovecot

# Enable dovecot
/usr/sbin/svcadm enable svc:/pkgsrc/dovecot:default

logadm -w /var/log/dovecot/main -p 1d -C 10 -N -o dovecot -g mail -m 660 -a "/opt/local/bin/doveadm log reopen"
logadm -w /var/log/dovecot/info -p 1d -C 10 -N -o dovecot -g mail -m 660 -a "/opt/local/bin/doveadm log reopen"
logadm -w /var/log/dovecot/debug -p 1d -C 10 -N -o dovecot -g mail -m 660 -a "/opt/local/bin/doveadm log reopen"

# Compile system sieve files
cd /opt/local/etc/dovecot/sieve_after
for i in *.sieve; do sievec $i; done 


