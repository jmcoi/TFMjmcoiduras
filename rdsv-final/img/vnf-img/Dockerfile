FROM ubuntu:20.04
# install required packages
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Madrid
RUN apt-get clean
RUN apt-get update \
    && apt-get install -y \
    net-tools \
    traceroute \
    curl \
    iptables \
    inetutils-ping \
    nano \
    build-essential \
    bridge-utils \
    isc-dhcp-server \
    tcpdump \
    openvswitch-switch \
    openvswitch-common \
    iperf \
    iproute2 \
    vim \
    ryu-bin \
    arpwatch
    
COPY qos_simple_switch_13.py /
COPY vnx_config_nat /usr/bin/
COPY isc-dhcp-server /etc/default/isc-dhcp-server
COPY dhcpd.conf /etc/dhcp/dhcpd.conf 
