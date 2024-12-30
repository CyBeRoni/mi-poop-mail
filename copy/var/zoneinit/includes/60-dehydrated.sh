#!/bin/bash

test -d /src/mail/ssl/dehydrated/accounts || dehydrated --register --accept-terms

