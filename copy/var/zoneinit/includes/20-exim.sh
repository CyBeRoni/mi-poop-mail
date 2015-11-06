#!/bin/bash

hostname=$(mdata-get sdc:hostname)
domainname=$(mdata-get sdc:dns_domain)

qualify_domain=$(mdata-get exim:qualify_domain || true)

if [ "x${qualify_domain}" = "x" ]; then
  qualify_domain="${hostname}.${domainname}"
fi

cat <<EOF > /opt/local/etc/exim/configure.local
# Generated file.

primary_hostname=${hostname}.${domainname}
qualify_domain=${qualify_domain}
EOF

pushd /srv/mail/exim/conf
test -e relay_to_domains || echo '# Add domains to relay for here, one per line' > relay_to_domains
test -e relay_from_hosts || echo '# Add hosts to accept messages for relay from here, one per line' > relay_from_hosts
test -e senderverify_exceptions || echo '# Add addresses to not do sender verification on here, one per line' > senderverify_exceptions
test -e global_aliases || echo '# Add aliases that should exist in EVERY domain here, one per line' > global_aliases
test -e address_domains || echo '# Add address aliases here, one per line' > address_domains
#test -e wildcard_domains || echo '# Add domains here that should accept all local_parts here, one per line' > wildcard_domains
test -e rewrite_domains || echo '# Add domains here that should be rewritten, followed by what they should be rewritten to, one per line (dom: replacement)' > rewrite_domains

popd

svcadm enable svc:/pkgsrc/exim:default

# Log watch cron job
echo '0 4 * * * root /opt/local/bin/exim-cron.sh' > /etc/cron.d/exim-cron

# configure logadm
logadm -w /var/log/exim/main -p 1d -C 10 -N -o mail -g mail -m 640 -c
logadm -w /var/log/exim/reject -p 1d -C 10 -N -o mail -g mail -m 640 -c
