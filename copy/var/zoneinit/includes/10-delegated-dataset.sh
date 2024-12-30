#!/bin/bash
UUID=$(mdata-get sdc:uuid)
DDS=zones/$UUID/data

if ! zfs list $DDS > /dev/null; then
        # No delegated dataset configured
        exit 0
fi

zfs set mountpoint=/srv/mail/ $DDS
zfs set compression=lz4 $DDS

test -d /srv/mail/domains || mkdir /srv/mail/domains
test -d /srv/mail/ssl || mkdir /srv/mail/ssl
test -d /srv/mail/ssl/dehydrated || mkdir /srv/mail/ssl/dehydrated
test -d /srv/mail/ssl/dehydrated/config.d || mkdir /srv/mail/ssl/dehydrated/config.d
test -d /srv/mail/ssl/dehydrated/wellknown || mkdir /srv/mail/ssl/dehydrated/wellknown
test -d /srv/mail/passwd || mkdir /srv/mail/passwd
test -d /srv/mail/exim || mkdir /srv/mail/exim
test -d /srv/mail/exim/conf || mkdir /srv/mail/exim/conf
test -d /srv/mail/exim/spool || mkdir /srv/mail/exim/spool
test -d /srv/mail/dkim || mkdir /srv/mail/dkim
test -d /srv/mail/aliases || mkdir /srv/mail/aliases

chown -R mail:mail /srv/mail/exim/spool
chown -R mail:mail /srv/mail/domains