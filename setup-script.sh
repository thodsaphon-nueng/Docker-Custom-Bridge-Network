#!/bin/bash
set -e

echo "Setting up Docker Bridge Network Lab..."

# Create containers
echo "Creating containers..."
docker run -d --name container1 --privileged --network none busybox sleep 3600
docker run -d --name container2 --privileged --network none busybox sleep 3600

# Create bridge
echo "Creating bridge network..."
sudo brctl addbr br0
sudo ip addr add 192.168.100.1/24 dev br0
sudo ip link set br0 up

# Setup container1
echo "Connecting container1..."
sudo ip link add veth0 type veth peer name veth1
sudo brctl addif br0 veth0
sudo ip link set veth0 up

CONTAINER1_PID=$(docker inspect -f '{{.State.Pid}}' container1)
sudo ip link set veth1 netns $CONTAINER1_PID
sudo nsenter --target $CONTAINER1_PID --net ip addr add 192.168.100.2/24 dev veth1
sudo nsenter --target $CONTAINER1_PID --net ip link set veth1 up
sudo nsenter --target $CONTAINER1_PID --net ip route add default via 192.168.100.1

# Setup container2
echo "Connecting container2..."
sudo ip link add veth2 type veth peer name veth3
sudo brctl addif br0 veth2
sudo ip link set veth2 up

CONTAINER2_PID=$(docker inspect -f '{{.State.Pid}}' container2)
sudo ip link set veth3 netns $CONTAINER2_PID
sudo nsenter --target $CONTAINER2_PID --net ip addr add 192.168.100.3/24 dev veth3
sudo nsenter --target $CONTAINER2_PID --net ip link set veth3 up
sudo nsenter --target $CONTAINER2_PID --net ip route add default via 192.168.100.1

# Configure system settings
echo "Configuring system settings..."
sudo sysctl net.bridge.bridge-nf-call-iptables=0
sudo sysctl net.bridge.bridge-nf-call-ip6tables=0
sudo sysctl net.bridge.bridge-nf-call-arptables=0
sudo sysctl net.ipv4.ip_forward=1

echo "Lab setup complete!"
echo ""
echo "Test connectivity with:"
echo "  sudo nsenter --target \$(docker inspect -f '{{.State.Pid}}' container1) --net ping -c 3 192.168.100.3"
echo ""
echo "Run './test-connectivity.sh' for full connectivity test"