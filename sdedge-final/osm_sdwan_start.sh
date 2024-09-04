#!/bin/bash
  
# Requires the following variables
# OSMNS: OSM namespace in the cluster vim
# SIID: id of the service instance
# NETNUM: used to select external networks
# REMOTESITE: the public IP of the remote site vCPE

set -u # to verify variables are defined
: $OSMNS
: $SIID
: $NETNUM
: $REMOTESITE

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

./start_sdwan.sh



