
echo "deb https://download.ceph.com/debian-reef/ jammy main" | sudo tee /etc/apt/sources.list.d/ceph.list
wget -q -O- https://download.ceph.com/keys/release.gpg | sudo gpg --dearmor -o /usr/share/keyrings/ceph.gpg
sudo apt update
sudo apt install -y cephadm ceph-common lvm2

sudo cephadm bootstrap --mon-ip 192.168.122.102 \
  --initial-dashboard-user admin \
  --initial-dashboard-password 'password'

sudo ceph -s
sudo cephadm shell
ceph orch device ls
ceph orch daemon add osd vm19:/dev/vdb
ceph config set mon mon_allow_pool_size_one true

ceph osd pool create volumes 32
ceph osd pool create images 32
ceph osd pool create vms 32
ceph osd pool create rbd 128 128

# Initialize the pools for RBD usage
rbd pool init volumes
rbd pool init images
rbd pool init vms
rbd pool init rbd

ceph osd pool set volumes size 1 --yes-i-really-mean-it
ceph osd pool set images size 1 --yes-i-really-mean-it
ceph osd pool set vms size 1 --yes-i-really-mean-it
ceph osd pool set rbd size 1 --yes-i-really-mean-it

# For single-OSD lab environments, also set min_size and defaults
ceph osd pool set volumes min_size 1
ceph osd pool set images min_size 1
ceph osd pool set vms min_size 1
ceph osd pool set rbd min_size 1
ceph config set global osd_pool_default_size 1
ceph config set global osd_pool_default_min_size 1

ceph osd pool get volumes size
ceph osd pool get images size
ceph osd pool get vms size
ceph osd pool get rbd size

ceph osd pool application enable volumes rbd
ceph osd pool application enable images rbd
ceph osd pool application enable vms rbd
ceph osd pool application enable rbd rbd

# Enable Glance application tag on images pool
ceph osd pool application enable images glance-image --yes-i-really-mean-it

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

# Standard OpenStack users (glance, cinder, cinder-backup)
ceph auth get-or-create client.glance \
  mon 'profile rbd' \
  osd 'profile rbd pool=images' \
  mgr 'profile rbd pool=images' \
  -o /etc/ceph/ceph.client.glance.keyring

ceph auth get-or-create client.cinder \
  mon 'profile rbd' \
  osd 'profile rbd pool=volumes, profile rbd pool=vms, profile rbd-read-only pool=images' \
  mgr 'profile rbd pool=volumes, profile rbd pool=vms' \
  -o /etc/ceph/ceph.client.cinder.keyring

ceph auth get-or-create client.cinder-backup \
  mon 'profile rbd' \
  osd 'profile rbd pool=backups' \
  mgr 'profile rbd pool=backups' \
  -o /etc/ceph/ceph.client.cinder-backup.keyring

ceph config generate-minimal-conf > ceph.conf
ceph auth get client.admin -o ceph.client.admin.keyring
exit

sudo cat /etc/ceph/ceph.client.admin.keyring
sudo cat /etc/ceph/ceph.conf

sudo groupadd --system cinder
sudo groupadd --system glance
sudo groupadd --system nova
sudo ceph auth get-key client.volumes | sudo tee /etc/ceph/ceph.client.volumes.keyring
sudo ceph auth get-key client.images  | sudo tee /etc/ceph/ceph.client.images.keyring
sudo ceph auth get-key client.nova    | sudo tee /etc/ceph/ceph.client.nova.keyring
sudo ceph auth get-key client.cinder  | sudo tee /etc/ceph/ceph.client.cinder.keyring
sudo ceph auth get-key client.glance  | sudo tee /etc/ceph/ceph.client.glance.keyring
sudo chgrp cinder /etc/ceph/ceph.client.volumes.keyring
sudo chmod 0640 /etc/ceph/ceph.client.volumes.keyring
sudo chgrp glance /etc/ceph/ceph.client.images.keyring
sudo chmod 0640 /etc/ceph/ceph.client.images.keyring
sudo chgrp cinder /etc/ceph/ceph.client.cinder.keyring
sudo chmod 0640 /etc/ceph/ceph.client.cinder.keyring
sudo chgrp glance /etc/ceph/ceph.client.glance.keyring
sudo chmod 0640 /etc/ceph/ceph.client.glance.keyring
sudo chgrp nova /etc/ceph/ceph.client.nova.keyring
sudo chmod 0640 /etc/ceph/ceph.client.nova.keyring

sudo ceph cephadm get-pub-key > ~/ceph.pub

sudo cp /etc/ceph/ceph.client.*.keyring /tmp/
sudo cp /etc/ceph/ceph.conf /tmp/
sudo chmod 644 /tmp/ceph.client.*.keyring /tmp/ceph.conf

scp -i ~/.ssh/id_rsa /tmp/ceph.conf ubuntu@192.168.122.69:/home/ubuntu/
scp -i ~/.ssh/id_rsa /tmp/ceph.client.*.keyring ubuntu@192.168.122.69:/home/ubuntu/
scp -i ~/.ssh/id_rsa /tmp/ceph.conf ubuntu@192.168.122.230:/home/ubuntu/
scp -i ~/.ssh/id_rsa /tmp/ceph.client.*.keyring ubuntu@192.168.122.230:/home/ubuntu/