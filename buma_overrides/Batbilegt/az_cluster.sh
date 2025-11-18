#!/bin/bash
set -euo pipefail

# === USER CONFIGURATION ===
NODES=(
  "vm15 192.168.122.230"
  "vm16 192.168.122.147"
  "vm17 192.168.122.96"
  "vm18 192.168.122.191"
)
CONTROL_PLANE_HOSTNAME="vm15"
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

# === Install Ansible ===
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

# Ensure ceph.conf hints for service users exist
if ! sudo grep -q "^\[client.cinder\]" /etc/ceph/ceph.conf; then
  sudo tee -a /etc/ceph/ceph.conf > /dev/null <<'EOF'
[client.cinder]
    keyfile = /etc/ceph/ceph.client.cinder.keyring
    client_mount_timeout = 30
EOF
fi

kubectl -n openstack create configmap ceph-etc \
  --from-file=ceph.conf=/etc/ceph/ceph.conf \
  --dry-run=client -o yaml | kubectl apply -f -

OPENSTACK_NS="openstack"
kubectl create namespace $OPENSTACK_NS --dry-run=client -o yaml | kubectl apply -f -

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
  --wait --timeout=10m \
  $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c openvswitch ${FEATURES})

helm upgrade --install libvirt openstack-helm/libvirt \
    --namespace=openstack \
    --set conf.ceph.enabled=true \
    --wait --timeout=10m \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c libvirt ${FEATURES})

# === Compute-only OpenStack services ===
# Control cluster public and RabbitMQ LB IPs
CONTROL_PUBLIC_IP="192.168.122.240"
RABBIT_LB_IP="192.168.122.241"

# Neutron: agents only on AZ cluster (OVS agent)
cat > ~/osh/openstack-helm/overrides/neutron/neutron_agents_only.yaml <<EOF
manifests:
  daemonset_ovs_agent: true
  daemonset_dhcp_agent: false
  daemonset_l3_agent: false
  daemonset_metadata_agent: false
  daemonset_lb_agent: false
  deployment_server: false
  deployment_rpc_server: false
  ingress_server: false
  service_server: false
  service_ingress_server: false
endpoints:
  oslo_messaging:
    host_fqdn_override:
      default: ${RABBIT_LB_IP}
  identity:
    host_fqdn_override:
      default: ${CONTROL_PUBLIC_IP}
    port:
      api:
        internal: 80
  compute:
    host_fqdn_override:
      default: ${CONTROL_PUBLIC_IP}
    port:
      api:
        default: 80
EOF

helm upgrade --install neutron openstack-helm/neutron \
  --namespace openstack \
  --wait --timeout=20m \
  --values /home/ubuntu/osh/openstack-helm/overrides/neutron/2025.1-ubuntu_noble.yaml \
  --values /home/ubuntu/osh/openstack-helm/overrides/neutron/neutron_agents_only.yaml

# Nova: compute-only on AZ cluster
cat > ~/osh/openstack-helm/overrides/nova/nova_compute_only.yaml <<EOF
manifests:
  daemonset_compute: true
  deployment_api_metadata: false
  deployment_api_osapi: false
  deployment_conductor: false
  deployment_novncproxy: false
  deployment_serialproxy: false
  deployment_spiceproxy: false
  deployment_scheduler: false
  ingress_metadata: false
  ingress_novncproxy: false
  ingress_serialproxy: false
  ingress_spiceproxy: false
  ingress_osapi: false
  service_ingress_metadata: false
  service_ingress_novncproxy: false
  service_ingress_serialproxy: false
  service_ingress_spiceproxy: false
  service_ingress_osapi: false
  service_metadata: false
  service_novncproxy: false
  service_serialproxy: false
  service_spiceproxy: false
  service_osapi: false
  job_db_init: false
  job_db_sync: false
  job_db_drop: false
  job_image_repo_sync: false
  job_ks_endpoints: false
  job_ks_service: false
  # Keep ks_user and rabbit_init so this cluster can authenticate to control-plane services
  job_ks_user: true
  job_rabbit_init: true
endpoints:
  oslo_messaging:
    host_fqdn_override:
      default: ${RABBIT_LB_IP}
  identity:
    host_fqdn_override:
      default: ${CONTROL_PUBLIC_IP}
    port:
      api:
        internal: 80
  image:
    host_fqdn_override:
      default: ${CONTROL_PUBLIC_IP}
    port:
      api:
        public: 80
        default: 80
  volumev3:
    host_fqdn_override:
      default: ${CONTROL_PUBLIC_IP}
    port:
      api:
        public: 80
        default: 80
  compute:
    host_fqdn_override:
      default: ${CONTROL_PUBLIC_IP}
    port:
      api:
        public: 80
        default: 80
  placement:
    host_fqdn_override:
      default: ${CONTROL_PUBLIC_IP}
    port:
      api:
        default: 80
EOF

helm upgrade --install nova openstack-helm/nova \
  --namespace openstack \
  --wait --timeout=25m \
  --values /home/ubuntu/osh/openstack-helm/overrides/nova/2025.1-ubuntu_noble.yaml \
  --values /home/ubuntu/osh/openstack-helm/overrides/nova/nova_compute_only.yaml