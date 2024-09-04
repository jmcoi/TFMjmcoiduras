#!/bin/bash

# Requires the following variables
# KUBECTL: kubectl command
# OSMNS: OSM namespace in the cluster vim
# NETNUM: used to select external networks
# VACC: "pod_id" or "deploy/deployment_id" of the access vnf
# VCPE: "pod_id" or "deploy/deployment_id" of the cpd vnf
# VWAN: "pod_id" or "deploy/deployment_id" of the wan vnf
# CUSTUNIP: the ip address for the customer side of the tunnel
# VNFTUNIP: the ip address for the vnf side of the tunnel
# VCPEPUBIP: the public ip address for the vcpe
# VCPEGW: the default gateway for the vcpe

set -u # to verify variables are defined
: $KUBECTL
: $OSMNS
: $NETNUM
: $VACC
: $VCPE
: $VWAN
: $CUSTUNIP
: $CUSTPREFIX
: $VNFTUNIP
: $VCPEPUBIP
: $VCPEGW

if [[ ! $VACC =~ "sdedge-ns-repo-accesschart"  ]]; then
    echo ""       
    echo "ERROR: incorrect <access_deployment_id>: $VACC"
    exit 1
fi

if [[ ! $VCPE =~ "sdedge-ns-repo-cpechart"  ]]; then
    echo ""       
    echo "ERROR: incorrect <cpe_deployment_id>: $VCPE"
    exit 1
fi

if [[ ! $VWAN =~ "sdedge-ns-repo-wanchart"  ]]; then
    echo ""       
    echo "ERROR: incorrect <wan_deployment_id>: $VWAN"
    exit 1
fi



ACC_EXEC="$KUBECTL exec -n $OSMNS $VACC --"
CPE_EXEC="$KUBECTL exec -n $OSMNS $VCPE --"
WAN_EXEC="$KUBECTL exec -n $OSMNS $VWAN --"

# IP privada por defecto para el vCPE
VCPEPRIVIP="192.168.255.254"
# IP privada por defecto para el router del cliente
CUSTGW="192.168.255.253"

# Router por defecto inicial en k8s (calico)
K8SGW="169.254.1.1"

## 1. Obtener IPs de las VNFs
echo "## 1. Obtener IPs de las VNFs"
IPACCESS=`$ACC_EXEC hostname -I | awk '{print $1}'`
echo "IPACCESS = $IPACCESS"

IPCPE=`$CPE_EXEC hostname -I | awk '{print $1}'`
echo "IPCPE = $IPCPE"

IPWAN=`$WAN_EXEC hostname -I | awk '{print $1}'`
echo "IPWAN = $IPWAN"

## 2. Iniciar el Servicio OpenVirtualSwitch en wan VNF:
echo "## 2. Iniciar el Servicio OpenVirtualSwitch en wan VNF"
$WAN_EXEC service openvswitch-switch start

## 3. En VNF:access agregar un bridge y sus vxlans
echo "## 3. En VNF:access agregar un bridge y sus vxlan"


$ACC_EXEC ovs-vsctl del-br brwan
$ACC_EXEC ovs-vsctl add-br brwan
$ACC_EXEC ovs-vsctl set bridge brwan protocols=OpenFlow10,OpenFlow12,OpenFlow13
$ACC_EXEC ovs-vsctl set-fail-mode brwan secure
$ACC_EXEC ovs-vsctl set bridge brwan other-config:datapath-id=0000000000000002
$ACC_EXEC ip link add vxlan1 type vxlan id 1 remote $CUSTUNIP dstport 4789 dev net$NETNUM
$ACC_EXEC ip link add axswan type vxlan id 3 remote $IPWAN dstport 4788 dev eth0
$ACC_EXEC ovs-vsctl add-port brwan vxlan1
$ACC_EXEC ovs-vsctl add-port brwan axswan
$ACC_EXEC ifconfig vxlan1 up
$ACC_EXEC ifconfig axswan up
$ACC_EXEC ovs-vsctl set-controller brwan tcp:127.0.0.1:6633
$ACC_EXEC ovs-vsctl set-manager ptcp:6632

## 4. En VNF:wan agregar el conmutador y su vxlan
echo "## 4. En VNF:wan agregar el conmutador y su vxlan"
$WAN_EXEC ovs-vsctl add-br brwan
$WAN_EXEC ip link add axswan type vxlan id 3 remote $IPACCESS dstport 4788 dev eth0
$WAN_EXEC ovs-vsctl add-port brwan axswan
#in the following, it should be net1 (only one MplsNet)
$WAN_EXEC ovs-vsctl add-port brwan net1
$WAN_EXEC ifconfig axswan up

## 6. Politicas WAN
echo "## 6. Politicas WAN"

$ACC_EXEC sleep 5

$ACC_EXEC curl -X PUT -d '"tcp:127.0.0.1:6632"' http://127.0.0.1:8080/v1.0/conf/switches/0000000000000002/ovsdb_addr
$ACC_EXEC sleep 5
$ACC_EXEC curl -X POST -d '{"port_name": "axswan", "type": "linux-htb", "max_rate": "1000000", "queues": [{"max_rate": "1000000"}, {"min_rate": "300000"},{"min_rate": "100000"}]}' http://127.0.0.1:8080/qos/queue/0000000000000002
$ACC_EXEC sleep 5
$ACC_EXEC curl -X POST -d '{"match": {"nw_dst": "10.20.0.1", "nw_proto": "TCP", "tp_dst": "5002"}, "actions":{"mark": "36"}}' http://127.0.0.1:8080/qos/rules/0000000000000002
$ACC_EXEC sleep 5
$ACC_EXEC curl -X POST -d '{"match": {"nw_dst": "10.20.0.1", "nw_proto": "TCP", "tp_dst": "5003"}, "actions":{"mark": "46"}}' http://127.0.0.1:8080/qos/rules/0000000000000002
$ACC_EXEC sleep 5
$ACC_EXEC curl -X POST -d '{"match": {"ip_dscp": "36"}, "actions":{"queue": "1"}}' http://127.0.0.1:8080/qos/rules/0000000000000002
$ACC_EXEC sleep 5
$ACC_EXEC curl -X POST -d '{"match": {"ip_dscp": "46"}, "actions":{"queue": "2"}}' http://127.0.0.1:8080/qos/rules/0000000000000002

$ACC_EXEC sleep 5

$ACC_EXEC curl -X PUT -d '"tcp:10.255.0.2:6632"' http://127.0.0.1:8080/v1.0/conf/switches/0000000000000003/ovsdb_addr
$ACC_EXEC sleep 5
$ACC_EXEC curl -X POST -d '{"port_name": "eth1", "type": "linux-htb", "max_rate": "1000000", "queues": [{"max_rate": "1000000"}, {"min_rate": "300000"},{"min_rate": "100000"}]}' http://127.0.0.1:8080/qos/queue/0000000000000003
$ACC_EXEC sleep 5
$ACC_EXEC curl -X POST -d '{"match": {"nw_src": "10.20.0.1", "nw_proto": "TCP", "tp_dst": "5002"}, "actions":{"mark": "36"}}' http://127.0.0.1:8080/qos/rules/0000000000000003
$ACC_EXEC sleep 5
$ACC_EXEC curl -X POST -d '{"match": {"nw_src": "10.20.0.1", "nw_proto": "TCP", "tp_dst": "5003"}, "actions":{"mark": "46"}}' http://127.0.0.1:8080/qos/rules/0000000000000003
$ACC_EXEC sleep 5
$ACC_EXEC curl -X POST -d '{"match": {"ip_dscp": "36"}, "actions":{"queue": "1"}}' http://127.0.0.1:8080/qos/rules/0000000000000003
$ACC_EXEC sleep 5
$ACC_EXEC curl -X POST -d '{"match": {"ip_dscp": "46"}, "actions":{"queue": "2"}}' http://127.0.0.1:8080/qos/rules/0000000000000003



