#!/bin/bash

# Requires the following variables
# KUBECTL: kubectl command
# OSMNS: OSM namespace in the cluster vim
# NETNUM: used to select external networks
# VACC: "pod_id" or "deploy/deployment_id" of the access vnf
# VCPE: "pod_id" or "deploy/deployment_id" of the cpd vnf
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

ACC_EXEC="$KUBECTL exec -n $OSMNS $VACC --"
CPE_EXEC="$KUBECTL exec -n $OSMNS $VCPE --"

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

## 2. Iniciar el Servicio OpenVirtualSwitch en cada VNF:
echo "## 2. Iniciar el Servicio OpenVirtualSwitch en cada VNF"
$ACC_EXEC service openvswitch-switch start
$CPE_EXEC service openvswitch-switch start

## 3. En VNF:access agregar un bridge y configurar IPs y rutas
echo "## 3. En VNF:access agregar un bridge y configurar IPs y rutas"
$ACC_EXEC ryu-manager ryu.app.rest_qos ryu.app.rest_conf_switch ./qos_simple_switch_13.py &

$ACC_EXEC sleep 5

$ACC_EXEC ovs-vsctl del-br brint
$ACC_EXEC ovs-vsctl add-br brint
$ACC_EXEC ovs-vsctl set bridge brint protocols=OpenFlow10,OpenFlow12,OpenFlow13
$ACC_EXEC ovs-vsctl set-fail-mode brint secure
$ACC_EXEC ovs-vsctl set bridge brint other-config:datapath-id=0000000000000001
$ACC_EXEC ifconfig net$NETNUM $VNFTUNIP/24
$ACC_EXEC ip link add vxlan2 type vxlan id 2 remote $CUSTUNIP dstport 8742 dev net$NETNUM
$ACC_EXEC ip link add axscpe type vxlan id 4 remote $IPCPE dstport 8742 dev eth0
$ACC_EXEC ovs-vsctl add-port brint vxlan2
$ACC_EXEC ovs-vsctl add-port brint axscpe
$ACC_EXEC ifconfig vxlan2 up
$ACC_EXEC ifconfig axscpe up
$ACC_EXEC ovs-vsctl set-controller brint tcp:127.0.0.1:6633
$ACC_EXEC ovs-vsctl set-manager ptcp:6632

## 4. En VNF:cpe agregar un bridge y configurar IPs y rutas
echo "## 4. En VNF:cpe agregar un bridge y configurar IPs y rutas"
$CPE_EXEC ovs-vsctl add-br brint
$CPE_EXEC ifconfig brint $VCPEPRIVIP/24
$CPE_EXEC ip link add axscpe type vxlan id 4 remote $IPACCESS dstport 8742 dev eth0
$CPE_EXEC ovs-vsctl add-port brint axscpe
$CPE_EXEC ifconfig axscpe up
$CPE_EXEC ifconfig brint mtu 1400
$CPE_EXEC ifconfig net$NETNUM $VCPEPUBIP/24
$CPE_EXEC ip route add $IPACCESS/32 via $K8SGW
$CPE_EXEC ip route del 0.0.0.0/0 via $K8SGW
$CPE_EXEC ip route add 0.0.0.0/0 via $VCPEGW
$CPE_EXEC ip route add $CUSTPREFIX via $CUSTGW

## 5. En VNF:cpe activar NAT para dar salida a Internet
echo "## 5. En VNF:cpe activar NAT para dar salida a Internet"
$CPE_EXEC /vnx_config_nat brint net$NETNUM


## 6. Politicas INET
echo "## 6. Politicas INET"

$ACC_EXEC curl -X PUT -d '"tcp:127.0.0.1:6632"' http://127.0.0.1:8080/v1.0/conf/switches/0000000000000001/ovsdb_addr
$ACC_EXEC sleep 5
$ACC_EXEC curl -X POST -d '{"port_name": "axscpe", "type": "linux-htb", "max_rate": "1000000", "queues": [{"max_rate": "1000000"}, {"min_rate": "300000"},{"min_rate": "100000"}]}' http://127.0.0.1:8080/qos/queue/0000000000000001
$ACC_EXEC sleep 5
$ACC_EXEC curl -X POST -d '{"match": {"nw_dst": "192.168.255.253", "nw_proto": "TCP", "tp_dst": "5002"}, "actions":{"mark": "36"}}' http://127.0.0.1:8080/qos/rules/0000000000000001
$ACC_EXEC sleep 5
$ACC_EXEC curl -X POST -d '{"match": {"nw_dst": "192.168.255.253", "nw_proto": "TCP", "tp_dst": "5003"}, "actions":{"mark": "46"}}' http://127.0.0.1:8080/qos/rules/0000000000000001
$ACC_EXEC sleep 5
$ACC_EXEC curl -X POST -d '{"match": {"ip_dscp": "36"}, "actions":{"queue": "1"}}' http://127.0.0.1:8080/qos/rules/0000000000000001
$ACC_EXEC sleep 5
$ACC_EXEC curl -X POST -d '{"match": {"ip_dscp": "46"}, "actions":{"queue": "2"}}' http://127.0.0.1:8080/qos/rules/0000000000000001


$ACC_EXEC sleep 5

$ACC_EXEC curl -X PUT -d '"tcp:10.255.0.2:6632"' http://127.0.0.1:8080/v1.0/conf/switches/0000000000000004/ovsdb_addr
$ACC_EXEC sleep 5
$ACC_EXEC curl -X POST -d '{"port_name": "eth2", "type": "linux-htb", "max_rate": "1000000", "queues": [{"max_rate": "1000000"}, {"min_rate": "300000"},{"min_rate": "100000"}]}' http://127.0.0.1:8080/qos/queue/0000000000000004
$ACC_EXEC sleep 5
$ACC_EXEC curl -X POST -d '{"match": {"nw_src": "192.168.255.253", "nw_proto": "TCP", "tp_dst": "5002"}, "actions":{"mark": "36"}}' http://127.0.0.1:8080/qos/rules/0000000000000004
$ACC_EXEC sleep 5
$ACC_EXEC curl -X POST -d '{"match": {"nw_src": "192.168.255.253", "nw_proto": "TCP", "tp_dst": "5003"}, "actions":{"mark": "46"}}' http://127.0.0.1:8080/qos/rules/0000000000000004
$ACC_EXEC sleep 5
$ACC_EXEC curl -X POST -d '{"match": {"ip_dscp": "36"}, "actions":{"queue": "1"}}' http://127.0.0.1:8080/qos/rules/0000000000000004
$ACC_EXEC sleep 5
$ACC_EXEC curl -X POST -d '{"match": {"ip_dscp": "46"}, "actions":{"queue": "2"}}' http://127.0.0.1:8080/qos/rules/0000000000000004




