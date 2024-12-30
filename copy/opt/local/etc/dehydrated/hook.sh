#!/bin/bash

case "$1" in
    "deploy_challenge")
        case "$CHALLENGETYPE" in
            "dns-01")
                /opt/local/etc/dehydrated/pdns_api.sh "$@"
             ;;
             esac
        ;;
    "clean_challenge")
        case "$CHALLENGETYPE" in
            "dns-01")
                /opt/local/etc/dehydrated/pdns_api.sh "$@"
             ;;
             esac
        ;;
    "deploy_cert")
    # Given arguments: deploy_cert domain path/to/privkey.pem path/to/cert.pem path/to/fullchain.pem
        cat <<- EOF
            ssl_cert = <$5
            ssl_key = <$3
        EOF > /opt/local/etc/dovecot/ssl-certificates.conf

        mkdir -p /opt/local/etc/exim/ssl/$2
        cp $3 $5 /opt/local/etc/exim/ssl/$2

        svcadm disable exim
        svcadm disable dovecot
        svcadm enable exim
        svcadm enable dovecot
        ;;
    "unchanged_cert")
        ;;
    "startup_hook")
        ;;
    "exit_hook")
        ;;
    *)
    exit 0
    ;;
esac
