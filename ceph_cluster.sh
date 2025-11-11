
echo "deb https://download.ceph.com/debian-reef/ jammy main" | sudo tee /etc/apt/sources.list.d/ceph.list
wget -q -O- https://download.ceph.com/keys/release.gpg | sudo gpg --dearmor -o /usr/share/keyrings/ceph.gpg
sudo apt update
sudo apt install -y cephadm ceph-common lvm2

sudo cephadm bootstrap --mon-ip 192.168.122.28 \
  --initial-dashboard-user admin \
  --initial-dashboard-password 'password'

sudo ceph -s
sudo cephadm shell
ceph orch device ls
ceph orch daemon add osd vm9:/dev/vdb
ceph config set mon mon_allow_pool_size_one true

ceph osd pool create volumes 32
ceph osd pool create images 32
ceph osd pool create vms 32
ceph osd pool create rbd 128 128

ceph osd pool set volumes size 1 --yes-i-really-mean-it
ceph osd pool set images size 1 --yes-i-really-mean-it
ceph osd pool set vms size 1 --yes-i-really-mean-it
ceph osd pool set rbd size 1 --yes-i-really-mean-it

ceph osd pool get volumes size
ceph osd pool get images size
ceph osd pool get vms size
ceph osd pool get rbd size

ceph osd pool application enable volumes rbd
ceph osd pool application enable images rbd
ceph osd pool application enable vms rbd
ceph osd pool application enable rbd rbd

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

sudo cat /etc/ceph/ceph.client.admin.keyring
sudo cat /etc/ceph/ceph.conf

sudo groupadd --system cinder
sudo groupadd --system glance
sudo groupadd --system nova
sudo ceph auth get-key client.volumes | sudo tee /etc/ceph/ceph.client.volumes.keyring
sudo ceph auth get-key client.images  | sudo tee /etc/ceph/ceph.client.images.keyring
sudo ceph auth get-key client.nova    | sudo tee /etc/ceph/ceph.client.nova.keyring
sudo chgrp cinder /etc/ceph/ceph.client.volumes.keyring
sudo chmod 0640 /etc/ceph/ceph.client.volumes.keyring
sudo chgrp glance /etc/ceph/ceph.client.images.keyring
sudo chmod 0640 /etc/ceph/ceph.client.images.keyring
sudo chgrp nova /etc/ceph/ceph.client.nova.keyring
sudo chmod 0640 /etc/ceph/ceph.client.nova.keyring

sudo ceph cephadm get-pub-key > ~/ceph.pub

sudo cp /etc/ceph/ceph.client.*.keyring /tmp/
sudo cp /etc/ceph/ceph.conf /tmp/
sudo chmod 644 /tmp/ceph.client.*.keyring /tmp/ceph.conf

scp -i ~/.ssh/id_rsa /tmp/ceph.conf ubuntu@192.168.122.68:/home/ubuntu/
scp -i ~/.ssh/id_rsa /tmp/ceph.client.*.keyring ubuntu@192.168.122.68:/home/ubuntu/
scp -i ~/.ssh/id_rsa /tmp/ceph.conf ubuntu@192.168.122.43:/home/ubuntu/
scp -i ~/.ssh/id_rsa /tmp/ceph.client.*.keyring ubuntu@192.168.122.43:/home/ubuntu/

sudo ceph orch host add vm26 192.168.122.68
sudo ceph orch host add vm26 192.168.122.43