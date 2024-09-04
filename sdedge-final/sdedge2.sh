#!/bin/bash
export OSMNS  # needs to be defined in calling shell
export SIID="prueba.slice_corpcpe_2_ns" # $NSID1 needs to be defined in calling shell
export SNAME="$BASH_SOURCE"

export NETNUM=2  # used to select external networks (set to 2 for sdedge2)

# CUSTUNIP: the ip address for the home side of the tunnel
export CUSTUNIP="10.255.0.2"

# CUSTPREFIX: the customer private prefix
export CUSTPREFIX="10.20.2.0/24"

# VNFTUNIP: the ip address for the vnf side of the tunnel
export VNFTUNIP="10.255.0.1"

# VCPEPUBIP: the public ip address for the vcpe
export VCPEPUBIP="10.100.2.1"

# VCPEGW: the default gateway for the vcpe
export VCPEGW="10.100.2.254"

./osm_sdedge_start.sh
