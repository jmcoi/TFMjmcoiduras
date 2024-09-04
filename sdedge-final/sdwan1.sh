#!/bin/bash
export OSMNS  # needs to be defined in calling shell
export SIID="prueba.slice_corpcpe_1_ns" # $NSID1 needs to be defined in calling shell

export NETNUM=1 # used to select external networks

export REMOTESITE="10.100.2.1"

./osm_sdwan_start.sh



