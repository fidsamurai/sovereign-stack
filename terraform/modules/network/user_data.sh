#!/bin/bash
# 1. Update the system
yum update -y

# 2. Enable IPv4 Forwarding in the kernel
# This allows the instance to pass traffic from one interface/subnet to another
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

# 3. Determine the primary network interface (usually eth0 or ens5)
PRIMARY_INTERFACE=$(ip route get 8.8.8.8 | grep -oP 'dev \K\S+')

# 4. Configure iptables to masquerade (SNAT) traffic 
# This changes the source IP of outgoing private traffic to the NAT instance's IP
yum install iptables-services -y
systemctl enable iptables
systemctl start iptables

# Clean existing rules
iptables -F
iptables -t nat -F

# Apply the NAT Masquerade rule
iptables -t nat -A POSTROUTING -o $PRIMARY_INTERFACE -j MASQUERADE

# 5. Save the iptables rules so they persist after reboot
service iptables save