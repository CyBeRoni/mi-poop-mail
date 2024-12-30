#!/bin/bash

test -d /srv/mail/ssl/dehydrated/accounts || dehydrated --register --accept-terms

