#!/bin/bash
  
# Requires the following variables
# OSMNS: OSM namespace in the cluster vim
# SINAME: name of the service instance
# HOMETUNIP: the ip address for the home side of the tunnel
# VNFTUNIP: the ip address for the vnf side of the tunnel
# VCPEPUBIP: the public ip address for the vcpe
# VCPEGW: the default gateway for the vcpe

set -u # to verify variables are defined
: $OSMNS
: $SINAME1
: $SINAME2
: $HOMETUNIP
: $VNFTUNIP
: $VCPEPUBIP
: $VCPEGW

export KUBECTL="microk8s kubectl"

#Con esta expresion no necesitariamos un SINAME1 SINAME2, solo con poner access y cpe en las lineas 30 y 31 valdría
#osm ns-list | grep $1 |  awk '{split($0,a,"|");print a[3]}' | xargs osm vnf-list --ns | grep $1 | awk '{split($0,a,"|");print a[2]}' | xargs osm vnf-show --literal |  grep name  | grep $1 | awk '{split($0,a,":");print a[2]}' | sed 's/ //g'""

deployment_id() {
    echo `osm ns-list | grep $1 | awk '{split($0,a,"|");print a[3]}' | xargs osm vnf-list --ns | grep $2 | awk '{split($0,a,"|");print a[2]}' | xargs osm vnf-show --literal | grep name | grep $2 | awk '{split($0,a,":");print a[2]}' | sed 's/ //g'`
}

## 0. Obtener deployment ids de las vnfs
echo "## 0. Obtener deployment ids de las vnfs"
OSMACC=$(deployment_id $SINAME1 "access")
OSMCPE=$(deployment_id $SINAME2 "cpe")
echo $OSMACC
echo $OSMCPE

export VACC="deploy/$OSMACC"
export VCPE="deploy/$OSMCPE"

./renes_start.sh
