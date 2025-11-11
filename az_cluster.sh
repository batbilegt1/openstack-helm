#!/bin/bash

# === USER CONFIGURATION ===
NODES=(
  "vm5 192.168.122.43"
  "vm6 192.168.122.228"
  "vm7 192.168.122.50"
  "vm8 192.168.122.173"
  "vm9 192.168.122.28"
)
CONTROL_PLANE_HOSTNAME="vm5"
USER="ubuntu"
SSH_KEY="$HOME/.ssh/id_rsa"
PUB_KEY="${SSH_KEY}.pub"

# === Install Helm ===
sudo snap install helm --classic
helm repo add openstack-helm https://tarballs.opendev.org/openstack/openstack-helm
helm plugin install https://opendev.org/openstack/openstack-helm-plugin

# === Clone Required Repos ===
mkdir -p ~/osh && cd ~/osh
git clone https://opendev.org/openstack/openstack-helm.git
git clone https://opendev.org/zuul/zuul-jobs.git

sudo apt update
sudo apt install -y python3-pip
pip install --user ansible
sudo apt install -y ansible

export ANSIBLE_ROLES_PATH=~/osh/openstack-helm/roles:~/osh/zuul-jobs/roles

# === Generate Dynamic Inventory ===
cat > ~/osh/inventory.yaml <<EOF
all:
  vars:
    ansible_user: $USER
    ansible_port: 22
    ansible_ssh_private_key_file: $SSH_KEY
    ansible_ssh_extra_args: -o StrictHostKeyChecking=no
    kubectl:
      user: $USER
      group: $USER
    docker_users:
      - $USER
    client_ssh_user: $USER
    cluster_ssh_user: $USER
    metallb_setup: true
    loopback_setup: true
    loopback_device: /dev/loop100
    loopback_image: /var/lib/openstack-helm/ceph-loop.img
    loopback_image_size: 12G
  children:
    primary:
      hosts:
        $CONTROL_PLANE_HOSTNAME:
          ansible_host: $(for node in "${NODES[@]}"; do
              [[ "$(echo $node | awk '{print $1}')" == "$CONTROL_PLANE_HOSTNAME" ]] && echo $node | awk '{print $2}'
          done)
    k8s_cluster:
      hosts:
$(for node in "${NODES[@]}"; do
    HOSTNAME=$(echo $node | awk '{print $1}')
    IP=$(echo $node | awk '{print $2}')
    echo "        $HOSTNAME:"
    echo "          ansible_host: $IP"
done)
    k8s_control_plane:
      hosts:
        $CONTROL_PLANE_HOSTNAME:
          ansible_host: $(for node in "${NODES[@]}"; do
              [[ "$(echo $node | awk '{print $1}')" == "$CONTROL_PLANE_HOSTNAME" ]] && echo $node | awk '{print $2}'
          done)
    k8s_nodes:
      hosts:
$(for node in "${NODES[@]}"; do
    HOSTNAME=$(echo $node | awk '{print $1}')
    IP=$(echo $node | awk '{print $2}')
    if [[ "$HOSTNAME" != "$CONTROL_PLANE_HOSTNAME" ]]; then
        echo "        $HOSTNAME:"
        echo "          ansible_host: $IP"
    fi
done)
EOF

# === Generate Ansible Playbook ===
cat > ~/osh/deploy-env.yaml <<EOF
---
- hosts: all
  become: true
  gather_facts: true
  roles:
    - ensure-python
    - ensure-pip
    - clear-firewall
    - deploy-env
EOF

# === Run the Ansible Playbook ===
cd ~/osh
ansible-playbook -i inventory.yaml deploy-env.yaml

kubectl label --overwrite nodes --all openstack-compute-node=enabled
kubectl label --overwrite nodes --all openvswitch=enabled

rm -rf ~/.local/share/helm/plugins/openstack-helm-plugin.git
helm plugin list

echo "deb https://download.ceph.com/debian-reef/ jammy main" | sudo tee /etc/apt/sources.list.d/ceph.list
wget -q -O- https://download.ceph.com/keys/release.gpg | sudo gpg --dearmor -o /usr/share/keyrings/ceph.gpg
sudo apt update
sudo apt install -y cephadm ceph-common lvm2
sudo mkdir -p /etc/ceph
sudo mv /home/ubuntu/ceph.conf /etc/ceph/
sudo mv /home/ubuntu/ceph.client.*.keyring /etc/ceph/
sudo chown root:root /etc/ceph/ceph.conf /etc/ceph/ceph.client.*.keyring
sudo chmod 644 /etc/ceph/ceph.conf
sudo chmod 600 /etc/ceph/ceph.client.*.keyring
sudo ceph -s --conf /etc/ceph/ceph.conf --keyring /etc/ceph/ceph.client.admin.keyring
sudo chmod 644 /etc/ceph/ceph.client.admin.keyring
ceph -s --keyring /etc/ceph/ceph.client.admin.keyring

kubectl -n openstack create configmap ceph-etc \
  --from-file=ceph.conf=/etc/ceph/ceph.conf \
  --dry-run=client -o yaml | kubectl apply -f -

helm repo add ceph-csi https://ceph.github.io/csi-charts
helm repo update
helm install ceph-csi-rbd ceph-csi/ceph-csi-rbd --namespace kube-system

kubectl get pods -n kube-system | grep csi
kubectl get csidrivers

OPENSTACK_NS="openstack"
KUBE_SYSTEM_NS="kube-system"
CEPH_SECRET_NAME="ceph-secret"
CEPH_KEY="AQAqzQ1pSInIKhAAiecs+MN4nT8PMwF2LaxgpQ=="
CLUSTER_ID="6e5c1cd1-bbc6-11f0-92ec-525400d7cbaf"
MONITOR_IP="192.168.122.28:6789"

kubectl create namespace $OPENSTACK_NS --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic $CEPH_SECRET_NAME \
  --namespace=$OPENSTACK_NS \
  --type="kubernetes.io/rbd" \
  --from-literal=key="$CEPH_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: general
provisioner: rbd.csi.ceph.com
parameters:
  clusterID: "$CLUSTER_ID"
  pool: rbd
  imageFormat: "2"
  imageFeatures: layering
  csi.storage.k8s.io/provisioner-secret-name: $CEPH_SECRET_NAME
  csi.storage.k8s.io/provisioner-secret-namespace: $OPENSTACK_NS
  csi.storage.k8s.io/node-stage-secret-name: $CEPH_SECRET_NAME
  csi.storage.k8s.io/node-stage-secret-namespace: $OPENSTACK_NS
reclaimPolicy: Delete
allowVolumeExpansion: true
mountOptions:
  - discard
volumeBindingMode: Immediate
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ceph-csi-config
  namespace: $KUBE_SYSTEM_NS
data:
  config.json: |-
    [
      {
        "clusterID": "$CLUSTER_ID",
        "monitors": [
          "$MONITOR_IP"
        ]
      }
    ]
EOF

kubectl get sc -A

kubectl -n openstack create secret generic pvc-ceph-client-key \
  --from-literal=key="$CEPH_KEY"

cd ~/osh/openstack-helm

export OPENSTACK_RELEASE=2025.1
export FEATURES="${OPENSTACK_RELEASE} ubuntu_noble"
export OVERRIDES_DIR=$(pwd)/overrides

OVERRIDES_URL=https://opendev.org/openstack/openstack-helm/raw/branch/master/values_overrides
for chart in rabbitmq mariadb memcached openvswitch libvirt keystone heat glance cinder placement nova neutron horizon; do
    helm osh get-values-overrides -d -u ${OVERRIDES_URL} -p ${OVERRIDES_DIR} -c ${chart} ${FEATURES}
done

helm upgrade --install openvswitch openstack-helm/openvswitch \
    --namespace=openstack \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c openvswitch ${FEATURES})

helm upgrade --install libvirt openstack-helm/libvirt \
    --namespace=openstack \
    --set conf.ceph.enabled=true \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c libvirt ${FEATURES})