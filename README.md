# Docker Custom Bridge Network Lab

## ภาพรวม
Lab นี้มีความตั้งใจ แสดงการสร้างเครือข่าย bridge แบบกำหนดเองเพื่อเชื่อมต่อ Docker containers โดยใช้ Linux bridge และ veth pairs คุณจะได้เรียนรู้การกำหนดค่าเครือข่าย container ด้วยตนเอง โดยไม่ใช้ระบบเครือข่ายมาตรฐานของ Docker

## วัตถุประสงค์การเรียนรู้
- เข้าใจแนวคิด Linux bridge networking
- เรียนรู้การสร้างและจัดการ veth pairs
- กำหนดค่าเครือข่าย container แบบกำหนดเอง
- แก้ไขปัญหาการเชื่อมต่อเครือข่าย
- ทำงานกับ network namespaces

## ข้อกำหนดเบื้องต้น
- ระบบ Ubuntu/Linux ที่ติดตั้ง Docker แล้ว
- สิทธิ์ root/sudo
- ความเข้าใจพื้นฐานเกี่ยวกับ Linux networking
- ติดตั้ง Bridge utilities (`bridge-utils`)

## โครงสร้างเครือข่าย

```
┌─────────────────────────────────────────────────────┐
│                    Host System                      │
│                                                     │
│  ┌─────────────┐      ┌──────────────┐             │
│  │ Container1  │      │  Container2  │             │
│  │             │      │              │             │
│  │   busybox   │      │   busybox    │             │
│  │             │      │              │             │
│  └──────┬──────┘      └──────┬───────┘             │
│         │ veth1              │ veth3                │
│         │ 192.168.100.2/24   │ 192.168.100.3/24    │
│         │                    │                      │
│    ┌────┴────────────────────┴─────┐                │
│    │         br0 Bridge            │                │
│    │      192.168.100.1/24         │                │
│    └────┬────────────────────┬─────┘                │
│         │ veth0              │ veth2                │
│         │                    │                      │
│         └────────────────────┘                      │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## การติดตั้ง Lab

### ขั้นตอนที่ 1: สร้าง Containers
สร้าง containers สองตัวโดยไม่มีเครือข่าย เพื่อกำหนดค่าด้วยตนเอง:

```bash
# สร้าง container1
docker run -d --name container1 --privileged --network none busybox sleep 3600

# สร้าง container2  
docker run -d --name container2 --privileged --network none busybox sleep 3600
```

### ขั้นตอนที่ 2: สร้างเครือข่าย Bridge
ตั้งค่า Linux bridge เพื่อเชื่อมต่อ containers:

```bash
# สร้าง bridge
sudo brctl addbr br0

# กำหนด IP ให้กับ bridge
sudo ip addr add 192.168.100.1/24 dev br0

# เปิดใช้งาน bridge
sudo ip link set br0 up
```

### ขั้นตอนที่ 3: เชื่อมต่อ Container1 กับ Bridge
สร้าง veth pair และเชื่อมต่อ container1:

```bash
# สร้าง veth pair
sudo ip link add veth0 type veth peer name veth1

# เชื่อมต่อด้าน host กับ bridge
sudo brctl addif br0 veth0
sudo ip link set veth0 up

# รับ PID ของ container1
CONTAINER1_PID=$(docker inspect -f '{{.State.Pid}}' container1)

# ย้ายด้าน container ไปยัง namespace ของ container
sudo ip link set veth1 netns $CONTAINER1_PID

# กำหนดค่าเครือข่าย container1
sudo nsenter --target $CONTAINER1_PID --net ip addr add 192.168.100.2/24 dev veth1
sudo nsenter --target $CONTAINER1_PID --net ip link set veth1 up
```

### ขั้นตอนที่ 4: เชื่อมต่อ Container2 กับ Bridge
สร้าง veth pair ที่สองและเชื่อมต่อ container2:

```bash
# สร้าง veth pair ที่สอง
sudo ip link add veth2 type veth peer name veth3

# เชื่อมต่อด้าน host กับ bridge
sudo brctl addif br0 veth2
sudo ip link set veth2 up

# รับ PID ของ container2
CONTAINER2_PID=$(docker inspect -f '{{.State.Pid}}' container2)

# ย้ายด้าน container ไปยัง namespace ของ container
sudo ip link set veth3 netns $CONTAINER2_PID

# กำหนดค่าเครือข่าย container2
sudo nsenter --target $CONTAINER2_PID --net ip addr add 192.168.100.3/24 dev veth3
sudo nsenter --target $CONTAINER2_PID --net ip link set veth3 up
```

### ขั้นตอนที่ 5: กำหนดค่า Routing
เพิ่ม default routes สำหรับการสื่อสารระหว่าง containers:

```bash
# เพิ่ม default route ใน container1
sudo nsenter --target $CONTAINER1_PID --net ip route add default via 192.168.100.1

# เพิ่ม default route ใน container2
sudo nsenter --target $CONTAINER2_PID --net ip route add default via 192.168.100.1
```

### ขั้นตอนที่ 6: กำหนดค่า Bridge Settings
ตั้งค่า kernel parameters เพื่อหลีกเลี่ยงการรบกวนจาก iptables:

```bash
# ปิด netfilter สำหรับ bridge traffic
sudo sysctl net.bridge.bridge-nf-call-iptables=0
sudo sysctl net.bridge.bridge-nf-call-ip6tables=0
sudo sysctl net.bridge.bridge-nf-call-arptables=0

# เปิดใช้งาน IP forwarding
sudo sysctl net.ipv4.ip_forward=1
```

## การทดสอบการเชื่อมต่อ

### ตรวจสอบการกำหนดค่าเครือข่าย
```bash
# ตรวจสอบเครือข่าย container1
sudo nsenter --target $CONTAINER1_PID --net ip addr show veth1
sudo nsenter --target $CONTAINER1_PID --net ip route show

# ตรวจสอบเครือข่าย container2
sudo nsenter --target $CONTAINER2_PID --net ip addr show veth3
sudo nsenter --target $CONTAINER2_PID --net ip route show

# ตรวจสอบสถานะ bridge
brctl show br0
```

### ทดสอบการสื่อสารระหว่าง Containers
```bash
# Ping จาก container1 ไปยัง container2
sudo nsenter --target $CONTAINER1_PID --net ping -c 3 192.168.100.3

# Ping จาก container2 ไปยัง container1
sudo nsenter --target $CONTAINER2_PID --net ping -c 3 192.168.100.2

# ทดสอบจาก host ไปยัง containers
ping -c 2 192.168.100.2
ping -c 2 192.168.100.3
```



### คำสั่งสำหรับ Debug
```bash
# ตรวจสอบ bridge MAC table
brctl showmacs br0

# ตรวจสอบ traffic ด้วย tcpdump
sudo tcpdump -i br0 icmp

# ตรวจสอบ ARP tables
sudo nsenter --target $CONTAINER1_PID --net arp -a
```

