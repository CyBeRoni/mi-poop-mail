#!/bin/bash

mdata-get system:timezone && sm-set-timezone $(mdata-get system:timezone)
