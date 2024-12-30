#!/bin/bash

ssh_disabled=$(mdata-get system:ssh_disabled || true)

if [ "x$ssh_disabled" != "x" ] && [ "x${ssh_disabled}" != "xfalse" ]; then
  /usr/sbin/svcadm disable svc:/network/ssh:default
fi


