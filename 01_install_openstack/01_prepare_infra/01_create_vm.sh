export IP=10.0.0.132

apt update && apt upgrade -y
apt install qemu-system libvirt-daemon-system libvirt-clients bridge-utils virtinst wget  genisoimage guestfs-tools virt-manager -y

# sudo apt autoremove qemu-system libvirt-daemon-system libvirt-clients bridge-utils virtinst wget  genisoimage guestfs-tools virt-manager -y

usermod -aG libvirt $(whoami)
usermod -aG kvm $(whoami)
systemctl enable --now libvirtd
chown :kvm -R /var/lib/libvirt/images
chmod g+rw -R /var/lib/libvirt/images
systemctl restart libvirtd

wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

# sudo apt autoremove qemu-system libvirt-daemon-system libvirt-clients bridge-utils virtinst wget  genisoimage guestfs-tools virt-manager -y

# cat > /etc/netplan/01-vmbr0.yaml <<EOF
# network:
#   version: 2
#   renderer: networkd
#   bridges:
#     vmbr0:
#       addresses: [10.30.30.1/24]
#       interfaces: []
#       dhcp4: no
# EOF
# netplan apply
# ip a show vmbr0
# cat > vmhost-bridge.xml <<EOF
# <network>
#   <name>vmhost-bridge</name>
#   <forward mode="bridge"/>
#   <bridge name="vmbr0"/>
# </network>
# EOF

# sudo virsh net-define vmhost-bridge.xml
# sudo virsh net-start vmhost-bridge
# sudo virsh net-autostart vmhost-bridge

ssh-keygen

cat > manage.xml <<EOF
<network>
  <name>manage</name>
  <bridge name='manage-br' stp='off' delay='0'/>
  <ip address='10.3.0.1' netmask='255.255.255.0'/>
</network>
EOF

sudo virsh net-define manage.xml
sudo virsh net-start manage
sudo virsh net-autostart manage

# virsh net-destroy manage
# virsh net-undefine manage

cat > helm-net.xml <<EOF
<network>
  <name>helm-net</name>
  <bridge name='helm-net-br' stp='off' delay='0'/>
  <ip address='10.10.0.1' netmask='255.255.255.0'/>
</network>
EOF
sudo virsh net-define helm-net.xml
sudo virsh net-start helm-net
sudo virsh net-autostart helm-net

# virsh net-destroy helm-net
# virsh net-undefine helm-net

for j in 0 1 2 3
do
    cp /home/ubuntu/noble-server-cloudimg-amd64.img /var/lib/libvirt/images/ctr$j.img
    virt-customize -a "/var/lib/libvirt/images/ctr$j.img" --hostname ctr$j
    qemu-img resize "/var/lib/libvirt/images/ctr$j.img" 200G
done
for i in 0 1 2 3
do
    VM_NAME="ctr$i"
    # VM_DISK="/var/lib/libvirt/images/helm_primary$i.qcow2"
    VM_ISO="/var/lib/libvirt/images/ctr$i.img"
    CLOUD_INIT_ISO="/var/lib/libvirt/images/seed-ctr$i.iso"
    cat > user-data <<EOF
#cloud-config
users:
  - name: ubuntu
    ssh-authorized-keys:
      - $(cat /home/ubuntu/.ssh/id_rsa.pub)
      - $(cat /root/.ssh/id_rsa.pub)
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    groups: sudo
    shell: /bin/bash
chpasswd:
  list: |
     ubuntu:kali
  expire: False
ssh_pwauth: True
runcmd:
  - echo '#!/bin/bash' > /opt/upgrade_reboot.sh
  - echo 'export DEBIAN_FRONTEND=noninteractive' >> /opt/upgrade_reboot.sh
  - echo 'LOGFILE="/home/ubuntu/cloud-init-upgrade.log"' >> /opt/upgrade_reboot.sh
  - echo 'echo "=== Starting system update at \$(date) ===" > \$LOGFILE' >> /opt/upgrade_reboot.sh
  - sudo rm -f /etc/resolv.conf
  - MY_IP=\$(ip r g 1 | awk '{print \$7}' | head -n1)
  - HOST_NAME=\$(hostnamectl --static)
  - echo "127.0.1.1   \$HOST_NAME" | sudo tee -a /etc/hosts
  - echo "\$MY_IP \$HOST_NAME" | sudo tee -a /etc/hosts
  # 2. systemd-resolved тохиргооны файлыг засах
  # DNS серверүүдийг тохируулж, DNSStubListener-ийг идэвхгүй болгоно.
  - echo "systemd-resolved.conf файлыг засаж байна..."
  - |
    sudo sed -i '/^#\?DNS=/cDNS=8.8.8.8 1.1.1.1' /etc/systemd/resolved.conf
    sudo sed -i '/^#\?DNSStubListener=/cDNSStubListener=no' /etc/systemd/resolved.conf
  - sudo systemctl restart systemd-resolved
  # 4. /etc/resolv.conf файлын зөв симболик холбоосыг дахин үүсгэх
  - echo "/etc/resolv.conf холбоосыг дахин үүсгэж байна..."
  - sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
  - sleep 5
  - echo 'apt update >> \$LOGFILE 2>&1' >> /opt/upgrade_reboot.sh
  - echo 'echo "=== Finished update at \$(date) ===" >> \$LOGFILE' >> /opt/upgrade_reboot.sh
  - echo 'apt install -y screenfetch net-tools >> \$LOGFILE 2>&1' >> /opt/upgrade_reboot.sh
  - sudo echo 'screenfetch -n'|sudo tee -a /root/.bashrc
  - sudo chmod -x /etc/update-motd.d/10-help-text
  - sudo chmod -x /etc/update-motd.d/80-livepatch
  - sudo chmod -x /etc/update-motd.d/90-updates-available
  - sudo chmod -x /etc/update-motd.d/91-release-upgrade
  - echo 'apt update >> \$LOGFILE 2>&1' >> /opt/upgrade_reboot.sh
  - echo 'apt -y upgrade --fix-missing >> \$LOGFILE 2>&1' >> /opt/upgrade_reboot.sh
  - echo 'echo "=== Finished upgrade at \$(date) ===" >> \$LOGFILE' >> /opt/upgrade_reboot.sh
  - echo 'if [ -f /var/run/reboot-required ]; then' >> /opt/upgrade_reboot.sh
  - echo '  echo "Reboot required, rebooting..." >> \$LOGFILE' >> /opt/upgrade_reboot.sh
  - echo '  reboot' >> /opt/upgrade_reboot.sh
  - echo 'else' >> /opt/upgrade_reboot.sh
  - echo '  echo "No reboot required." >> \$LOGFILE' >> /opt/upgrade_reboot.sh
  - echo 'fi' >> /opt/upgrade_reboot.sh
  - chmod +x /opt/upgrade_reboot.sh
  - /opt/upgrade_reboot.sh
EOF

cat > network-config <<EOF
network:
    version: 2
    ethernets:
        enp1s0:
            dhcp4: yes
            dhcp6: no
        enp2s0:
            dhcp4: no
            dhcp6: no
            addresses: [10.3.0.1${i}/24]
            routes:
              - to: 10.22.22.0/24
                via: 10.3.0.1
        enp3s0:
            dhcp4: no
            dhcp6: no
            addresses: [10.10.0.1${i}/24]
EOF
    cat > meta-data <<EOF
instance-id: $VM_NAME
local-hostname: $VM_NAME
EOF
    echo "Generate a cloud-init ISO"
    genisoimage -output $CLOUD_INIT_ISO -volid cidata -joliet -rock user-data meta-data network-config
    virt-install \
    --name $VM_NAME \
    --os-variant ubuntu22.04 \
    --memory 409600 \
    --vcpus 20 \
    --disk $VM_ISO,device=disk,bus=virtio \
    --disk $CLOUD_INIT_ISO,device=cdrom \
    --import \
    --network network=default \
    --network network=manage,model=virtio \
    --network network=helm-net,model=virtio \
    --virt-type kvm \
    --qemu-commandline='-smbios type=1,serial=ds=nocloud;h='"${VM_NAME}"'.lan' \
    --noautoconsole \
    --console pty,target_type=serial
done
# for i in 0 1 2 3
# do
# virsh destroy noble$i
# virsh undefine noble$i --nvram
# rm -f /var/lib/libvirt/images/noble$i.img
# rm -f /var/lib/libvirt/images/seed-noble$i.iso
# done



for j in 4 5 6 7
do
    cp /home/ubuntu/noble-server-cloudimg-amd64.img /var/lib/libvirt/images/az$j.img
    virt-customize -a "/var/lib/libvirt/images/az$j.img" --hostname az$j
    qemu-img resize "/var/lib/libvirt/images/az$j.img" 200G
done
for i in 4 5 6 7
do
    VM_NAME="az$i"
    # VM_DISK="/var/lib/libvirt/images/helm_primary$i.qcow2"
    VM_ISO="/var/lib/libvirt/images/az$i.img"
    CLOUD_INIT_ISO="/var/lib/libvirt/images/seed-az$i.iso"
    cat > user-data <<EOF
#cloud-config
users:
  - name: ubuntu
    ssh-authorized-keys:
      - $(cat /home/ubuntu/.ssh/id_rsa.pub)
      - $(cat /root/.ssh/id_rsa.pub)
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    groups: sudo
    shell: /bin/bash
chpasswd:
  list: |
     ubuntu:kali
  expire: False
ssh_pwauth: True
runcmd:
  - echo '#!/bin/bash' > /opt/upgrade_reboot.sh
  - echo 'export DEBIAN_FRONTEND=noninteractive' >> /opt/upgrade_reboot.sh
  - echo 'LOGFILE="/home/ubuntu/cloud-init-upgrade.log"' >> /opt/upgrade_reboot.sh
  - echo 'echo "=== Starting system update at \$(date) ===" > \$LOGFILE' >> /opt/upgrade_reboot.sh
  - sudo rm -f /etc/resolv.conf
  - MY_IP=\$(ip r g 1 | awk '{print \$7}' | head -n1)
  - HOST_NAME=\$(hostnamectl --static)
  - echo "127.0.1.1   \$HOST_NAME" | sudo tee -a /etc/hosts
  - echo "\$MY_IP \$HOST_NAME" | sudo tee -a /etc/hosts
  # 2. systemd-resolved тохиргооны файлыг засах
  # DNS серверүүдийг тохируулж, DNSStubListener-ийг идэвхгүй болгоно.
  - echo "systemd-resolved.conf файлыг засаж байна..."
  - |
    sudo sed -i '/^#\?DNS=/cDNS=8.8.8.8 1.1.1.1' /etc/systemd/resolved.conf
    sudo sed -i '/^#\?DNSStubListener=/cDNSStubListener=no' /etc/systemd/resolved.conf
  - sudo systemctl restart systemd-resolved
  # 4. /etc/resolv.conf файлын зөв симболик холбоосыг дахин үүсгэх
  - echo "/etc/resolv.conf холбоосыг дахин үүсгэж байна..."
  - sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
  - sleep 5
  - echo 'apt update >> \$LOGFILE 2>&1' >> /opt/upgrade_reboot.sh
  - echo 'echo "=== Finished update at \$(date) ===" >> \$LOGFILE' >> /opt/upgrade_reboot.sh
  - echo 'apt install -y screenfetch net-tools >> \$LOGFILE 2>&1' >> /opt/upgrade_reboot.sh
  - sudo echo 'screenfetch -n'|sudo tee -a /root/.bashrc
  - sudo chmod -x /etc/update-motd.d/10-help-text
  - sudo chmod -x /etc/update-motd.d/80-livepatch
  - sudo chmod -x /etc/update-motd.d/90-updates-available
  - sudo chmod -x /etc/update-motd.d/91-release-upgrade
  - echo 'apt update >> \$LOGFILE 2>&1' >> /opt/upgrade_reboot.sh
  - echo 'apt -y upgrade --fix-missing >> \$LOGFILE 2>&1' >> /opt/upgrade_reboot.sh
  - echo 'echo "=== Finished upgrade at \$(date) ===" >> \$LOGFILE' >> /opt/upgrade_reboot.sh
  - echo 'if [ -f /var/run/reboot-required ]; then' >> /opt/upgrade_reboot.sh
  - echo '  echo "Reboot required, rebooting..." >> \$LOGFILE' >> /opt/upgrade_reboot.sh
  - echo '  reboot' >> /opt/upgrade_reboot.sh
  - echo 'else' >> /opt/upgrade_reboot.sh
  - echo '  echo "No reboot required." >> \$LOGFILE' >> /opt/upgrade_reboot.sh
  - echo 'fi' >> /opt/upgrade_reboot.sh
  - chmod +x /opt/upgrade_reboot.sh
  - /opt/upgrade_reboot.sh
EOF

cat > network-config <<EOF
network:
    version: 2
    ethernets:
        enp1s0:
            dhcp4: yes
            dhcp6: no
        enp2s0:
            dhcp4: no
            dhcp6: no
            addresses: [10.3.0.1${i}/24]
            routes:
              - to: 10.22.22.0/24
                via: 10.3.0.1
        enp3s0:
            dhcp4: no
            dhcp6: no
            addresses: [10.10.0.1${i}/24]
EOF
    cat > meta-data <<EOF
instance-id: $VM_NAME
local-hostname: $VM_NAME
EOF
    echo "Generate a cloud-init ISO"
    genisoimage -output $CLOUD_INIT_ISO -volid cidata -joliet -rock user-data meta-data network-config
    virt-install \
    --name $VM_NAME \
    --os-variant ubuntu22.04 \
    --memory 409600 \
    --vcpus 20 \
    --disk $VM_ISO,device=disk,bus=virtio \
    --disk $CLOUD_INIT_ISO,device=cdrom \
    --import \
    --network network=default \
    --network network=manage,model=virtio \
    --network network=helm-net,model=virtio \
    --virt-type kvm \
    --qemu-commandline='-smbios type=1,serial=ds=nocloud;h='"${VM_NAME}"'.lan' \
    --noautoconsole \
    --console pty,target_type=serial
done
# for i in 4 5 6 7
# do
# virsh destroy az$i
# virsh undefine az$i --nvram
# rm -f /var/lib/libvirt/images/az$i.img
# rm -f /var/lib/libvirt/images/seed-az$i.iso
# done


for j in 8
do
    cp /home/ubuntu/noble-server-cloudimg-amd64.img /var/lib/libvirt/images/ceph$j.img
    virt-customize -a "/var/lib/libvirt/images/ceph$j.img" --hostname ceph$j
    qemu-img resize "/var/lib/libvirt/images/ceph$j.img" 200G
    # Create new disks for ceph OSDs
    qemu-img create -f qcow2 /var/lib/libvirt/images/ceph_osd1.img 100G
    qemu-img create -f qcow2 /var/lib/libvirt/images/ceph_osd2.img 100G
    qemu-img create -f qcow2 /var/lib/libvirt/images/ceph_osd3.img 100G
done

chown :kvm -R /var/lib/libvirt/images
chmod g+rw -R /var/lib/libvirt/images

for i in 8
do
    VM_NAME="ceph$i"
    # VM_DISK="/var/lib/libvirt/images/helm_primary$i.qcow2"
    VM_ISO="/var/lib/libvirt/images/ceph$i.img"
    CLOUD_INIT_ISO="/var/lib/libvirt/images/seed-ceph$i.iso"
    cat > user-data <<EOF
#cloud-config
users:
  - name: ubuntu
    ssh-authorized-keys:
      - $(cat /home/ubuntu/.ssh/id_rsa.pub)
      - $(cat /root/.ssh/id_rsa.pub)
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    groups: sudo
    shell: /bin/bash
chpasswd:
  list: |
     ubuntu:kali
  expire: False
ssh_pwauth: True
runcmd:
  - echo '#!/bin/bash' > /opt/upgrade_reboot.sh
  - echo 'export DEBIAN_FRONTEND=noninteractive' >> /opt/upgrade_reboot.sh
  - echo 'LOGFILE="/home/ubuntu/cloud-init-upgrade.log"' >> /opt/upgrade_reboot.sh
  - echo 'echo "=== Starting system update at \$(date) ===" > \$LOGFILE' >> /opt/upgrade_reboot.sh
  - sudo rm -f /etc/resolv.conf
  - MY_IP=\$(ip r g 1 | awk '{print \$7}' | head -n1)
  - HOST_NAME=\$(hostnamectl --static)
  - echo "127.0.1.1   \$HOST_NAME" | sudo tee -a /etc/hosts
  - echo "\$MY_IP \$HOST_NAME" | sudo tee -a /etc/hosts
  # 2. systemd-resolved тохиргооны файлыг засах
  # DNS серверүүдийг тохируулж, DNSStubListener-ийг идэвхгүй болгоно.
  - echo "systemd-resolved.conf файлыг засаж байна..."
  - |
    sudo sed -i '/^#\?DNS=/cDNS=8.8.8.8 1.1.1.1' /etc/systemd/resolved.conf
    sudo sed -i '/^#\?DNSStubListener=/cDNSStubListener=no' /etc/systemd/resolved.conf
  - sudo systemctl restart systemd-resolved
  # 4. /etc/resolv.conf файлын зөв симболик холбоосыг дахин үүсгэх
  - echo "/etc/resolv.conf холбоосыг дахин үүсгэж байна..."
  - sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
  - sleep 5
  - echo 'apt update >> \$LOGFILE 2>&1' >> /opt/upgrade_reboot.sh
  - echo 'echo "=== Finished update at \$(date) ===" >> \$LOGFILE' >> /opt/upgrade_reboot.sh
  - echo 'apt install -y screenfetch net-tools >> \$LOGFILE 2>&1' >> /opt/upgrade_reboot.sh
  - sudo echo 'screenfetch -n'|sudo tee -a /root/.bashrc
  - sudo chmod -x /etc/update-motd.d/10-help-text
  - sudo chmod -x /etc/update-motd.d/80-livepatch
  - sudo chmod -x /etc/update-motd.d/90-updates-available
  - sudo chmod -x /etc/update-motd.d/91-release-upgrade
  - echo 'apt update >> \$LOGFILE 2>&1' >> /opt/upgrade_reboot.sh
  - echo 'apt -y upgrade --fix-missing >> \$LOGFILE 2>&1' >> /opt/upgrade_reboot.sh
  - echo 'echo "=== Finished upgrade at \$(date) ===" >> \$LOGFILE' >> /opt/upgrade_reboot.sh
  - echo 'if [ -f /var/run/reboot-required ]; then' >> /opt/upgrade_reboot.sh
  - echo '  echo "Reboot required, rebooting..." >> \$LOGFILE' >> /opt/upgrade_reboot.sh
  - echo '  reboot' >> /opt/upgrade_reboot.sh
  - echo 'else' >> /opt/upgrade_reboot.sh
  - echo '  echo "No reboot required." >> \$LOGFILE' >> /opt/upgrade_reboot.sh
  - echo 'fi' >> /opt/upgrade_reboot.sh
  - chmod +x /opt/upgrade_reboot.sh
  - /opt/upgrade_reboot.sh
EOF

cat > network-config <<EOF
network:
    version: 2
    ethernets:
        enp1s0:
            dhcp4: yes
            dhcp6: no
        enp2s0:
            dhcp4: no
            dhcp6: no
            addresses: [10.3.0.1${i}/24]
            routes:
              - to: 10.22.22.0/24
                via: 10.3.0.1
        enp3s0:
            dhcp4: no
            dhcp6: no
            addresses: [10.10.0.1${i}/24]
EOF
    cat > meta-data <<EOF
instance-id: $VM_NAME
local-hostname: $VM_NAME
EOF
    echo "Generate a cloud-init ISO"
    genisoimage -output $CLOUD_INIT_ISO -volid cidata -joliet -rock user-data meta-data network-config
    virt-install \
    --name $VM_NAME \
    --os-variant ubuntu22.04 \
    --memory 409600 \
    --vcpus 20 \
    --disk $VM_ISO,device=disk,bus=virtio \
    --disk /var/lib/libvirt/images/ceph_osd1.img,device=disk,bus=virtio \
    --disk /var/lib/libvirt/images/ceph_osd2.img,device=disk,bus=virtio \
    --disk /var/lib/libvirt/images/ceph_osd3.img,device=disk,bus=virtio \
    --disk $CLOUD_INIT_ISO,device=cdrom \
    --import \
    --network network=default \
    --network network=manage,model=virtio \
    --network network=helm-net,model=virtio \
    --virt-type kvm \
    --qemu-commandline='-smbios type=1,serial=ds=nocloud;h='"${VM_NAME}"'.lan' \
    --noautoconsole \
    --console pty,target_type=serial
done
# for i in 8
# do
# virsh destroy ceph$i
# virsh undefine ceph$i --nvram
# rm -f /var/lib/libvirt/images/ceph$i.img
# rm -f /var/lib/libvirt/images/seed-ceph$i.iso
# done