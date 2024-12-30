#!/bin/bash

if mdata-get system:timezone; then
  sm-set-timezone $(mdata-get system:timezone)
fi
