#!/bin/bash
# 1. Update the system using the modern dnf manager
dnf update -y

# 2. Enable IPv4 Forwarding (The "Sovereign" way)
# We use a dedicated file in sysctl.d to avoid overwriting system defaults
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/95-nat-forwarding.conf
sysctl -p /etc/sysctl.d/95-nat-forwarding.conf

# 3. Dynamic Interface Detection
# Nitro instances (T4g/T3) often use 'ens5' or 'enX0' instead of 'eth0'
PRIMARY_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

# 4. Install and Setup iptables-services
dnf install iptables-services -y

# 5. Apply NAT Rules
# We use the -A (Append) to the POSTROUTING chain
iptables -t nat -A POSTROUTING -o "$PRIMARY_INTERFACE" -j MASQUERADE

# 6. Persistence (Crucial for AL2023)
# AL2023 requires the service to be enabled AND the rules to be saved
systemctl enable --now iptables
service iptables save

# 7. Verification Log (Optional - viewable in /var/log/messages)
echo "NAT Instance configured on $PRIMARY_INTERFACE with IP Forwarding enabled." | logger -t "NAT-INIT"