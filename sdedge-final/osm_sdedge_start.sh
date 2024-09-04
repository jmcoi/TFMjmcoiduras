#!/bin/bash
  
# Requires the following variables
# OSMNS: OSM namespace in the cluster vim
# SIID: id of the service instance
# NETNUM: used to select external networks
# CUSTUNIP: the ip address for the customer side of the tunnel
# VNFTUNIP: the ip address for the vnf side of the tunnel
# VCPEPUBIP: the public ip address for the vcpe
# VCPEGW: the default gateway for the vcpe

set -u # to verify variables are defined
: $OSMNS
: $SIID
: $NETNUM
: $CUSTUNIP
: $VNFTUNIP
: $VCPEPUBIP
: $VCPEGW


export KUBECTL="microk8s kubectl"

deployment_id() {
    echo `osm ns-show $1 | grep kdu-instance | grep $2 | awk -F':' '{gsub(/[", |]/, "", $2); print $2}' `
}

## 0. Obtener deployment ids de las vnfs
echo "## 0. Obtener deployment ids de las vnfs"
OSMACC=$(deployment_id $SIID "access")
OSMCPE=$(deployment_id $SIID "cpe")
OSMWAN=$(deployment_id $SIID "wan")

export VACC="deploy/$OSMACC"
export VCPE="deploy/$OSMCPE"
export VWAN="deploy/$OSMWAN"

./start_corpcpe.sh
./start_sdedge.sh

echo "--"
echo "$(basename "$0")"
echo "K8s deployments para la red $NETNUM:"
echo $VACC
echo $VCPE
echo $VWAN
