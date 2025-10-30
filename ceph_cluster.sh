#!/bin/bash

# -------------------------
# Configurable IP addresses
# -------------------------
ceph_cluster_bootstrap_node_ip="10.10.0.12"       # Ceph monitor IP
controller_cluster_master_node_ip="10.2.0.4"      # Controller/master node
az_cluster_master_node_ip="10.2.0.8"              # AZ/compute node

# -------------------------
# Install Ceph
# -------------------------
echo "deb https://download.ceph.com/debian-reef/ jammy main" | sudo tee /etc/apt/sources.list.d/ceph.list
wget -q -O- https://download.ceph.com/keys/release.gpg | sudo gpg --dearmor -o /usr/share/keyrings/ceph.gpg
sudo apt update
sudo apt install -y cephadm ceph-common lvm2

# -------------------------
# Bootstrap Ceph monitor
# -------------------------
sudo cephadm bootstrap --mon-ip ${ceph_cluster_bootstrap_node_ip} \
  --initial-dashboard-user admin \
  --initial-dashboard-password 'password'

sudo ceph -s
sudo cephadm shell

# -------------------------
# Configure OSD
# -------------------------
ceph orch device ls
ceph orch daemon add osd az-w4:/dev/vdb
ceph config set mon mon_allow_pool_size_one true

# -------------------------
# Create pools
# -------------------------
ceph osd pool create volumes 32
ceph osd pool create images 32
ceph osd pool create vms 32
ceph osd pool create rbd 128 128

ceph osd pool set volumes size 1 --yes-i-really-mean-it
ceph osd pool set images size 1 --yes-i-really-mean-it
ceph osd pool set vms size 1 --yes-i-really-mean-it
ceph osd pool set rbd size 1 --yes-i-really-mean-it

ceph osd pool application enable volumes rbd
ceph osd pool application enable images rbd
ceph osd pool application enable vms rbd
ceph osd pool application enable rbd rbd

# -------------------------
# Create keyrings
# -------------------------
ceph auth get-or-create client.volumes \
  mon 'allow r' \
  osd 'allow class-read object_prefix rbd_children, allow rwx pool=volumes, allow rx pool=images' \
  -o /etc/ceph/ceph.client.volumes.keyring

ceph auth get-or-create client.images \
  mon 'allow r' \
  osd 'allow class-read object_prefix rbd_children, allow rwx pool=images' \
  -o /etc/ceph/ceph.client.images.keyring

ceph auth get-or-create client.nova \
  mon 'allow r' \
  osd 'allow class-read object_prefix rbd_children, allow rwx pool=vms, allow rx pool=images' \
  -o /etc/ceph/ceph.client.nova.keyring

ceph config generate-minimal-conf > ceph.conf
ceph auth get client.admin -o ceph.client.admin.keyring

exit

# -------------------------
# Set permissions for OpenStack services
# -------------------------
sudo groupadd --system cinder
sudo groupadd --system glance
sudo groupadd --system nova

sudo chgrp cinder /etc/ceph/ceph.client.volumes.keyring
sudo chmod 0640 /etc/ceph/ceph.client.volumes.keyring
sudo chgrp glance /etc/ceph/ceph.client.images.keyring
sudo chmod 0640 /etc/ceph/ceph.client.images.keyring
sudo chgrp nova /etc/ceph/ceph.client.nova.keyring
sudo chmod 0640 /etc/ceph/ceph.client.nova.keyring

# -------------------------
# Copy config & keyrings to nodes
# -------------------------
sudo cp /etc/ceph/ceph.client.*.keyring /tmp/
sudo cp /etc/ceph/ceph.conf /tmp/
sudo chmod 644 /tmp/ceph.client.*.keyring /tmp/ceph.conf

for node in ${controller_cluster_master_node_ip} ${az_cluster_master_node_ip}; do
    scp -i ~/.ssh/id_rsa -P 707 /tmp/ceph.conf ubuntu@$node:/home/ubuntu/
    scp -i ~/.ssh/id_rsa -P 707 /tmp/ceph.client.*.keyring ubuntu@$node:/home/ubuntu/
done
