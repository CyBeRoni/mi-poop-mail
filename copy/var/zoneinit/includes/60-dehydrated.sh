#!/bin/bash

test -d /srv/mail/ssl/dehydrated/accounts || dehydrated --register --accept-terms

echo '43 3 * * 0 /opt/local/bin/dehydrated -c -g' >> /etc/cron.d/crontabs/root

# Run once, but ignore failures
/opt/local/bin/dehydrated -c -g || true