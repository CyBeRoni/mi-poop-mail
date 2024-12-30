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
    "deploy_cert" | "unchanged_cert" )
    # Given arguments: deploy_cert domain path/to/privkey.pem path/to/cert.pem path/to/fullchain.pem
    if [ "x$2" = "x$(mdata-get dovecot:primary_hostname)" ]; then
        cat << EOF > /opt/local/etc/dovecot/ssl-certificates.conf
ssl_cert = <$5
ssl_key = <$3
EOF
    fi

        mkdir -p /opt/local/etc/exim/ssl/$2
        cp $3 $5 /opt/local/etc/exim/ssl/$2
        ;;
    "startup_hook")
        ;;
    "exit_hook")
        svcadm restart exim
        svcadm restart dovecot
        ;;
    *)
    exit 0
    ;;
esac
