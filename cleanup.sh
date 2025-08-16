#!/bin/bash
echo "Cleaning up Docker Bridge Network Lab..."

# Stop and remove containers
echo "Removing containers..."
docker stop container1 container2 2>/dev/null || true
docker rm container1 container2 2>/dev/null || true

# Remove network interfaces
echo "Removing network interfaces..."
sudo ip link delete veth0 2>/dev/null || true
sudo ip link delete veth2 2>/dev/null || true

# Remove bridge
echo "Removing bridge..."
sudo ip link set br0 down 2>/dev/null || true
sudo brctl delbr br0 2>/dev/null || true

# Reset sysctl settings
echo "Resetting system settings..."
sudo sysctl net.bridge.bridge-nf-call-iptables=1
sudo sysctl net.bridge.bridge-nf-call-ip6tables=1  
sudo sysctl net.bridge.bridge-nf-call-arptables=1
sudo sysctl net.ipv4.ip_forward=0

echo "Cleanup complete!"
echo "Your system has been restored to its original state."