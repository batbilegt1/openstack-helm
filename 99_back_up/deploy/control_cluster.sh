#!/bin/bash
set -euo pipefail

# === USER CONFIGURATION ===
NODES=(
  "vm11 192.168.122.69"
  "vm12 192.168.122.6"
  "vm13 192.168.122.106"
  "vm14 192.168.122.201"
)
CONTROL_PLANE_HOSTNAME="vm11"
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

tee > /tmp/openstack_namespace.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: openstack
EOF
kubectl apply -f /tmp/openstack_namespace.yaml

rm -rf ~/.local/share/helm/plugins/openstack-helm-plugin.git
helm plugin list

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --version="4.8.3" \
  --namespace=openstack \
  --create-namespace \
  --set controller.kind=Deployment \
  --set controller.admissionWebhooks.enabled=false \
  --set controller.scope.enabled=true \
  --set controller.ingressClassResource.name=nginx \
  --set controller.ingressClassResource.controllerValue="k8s.io/ingress-nginx" \
  --set controller.ingressClass=nginx \
  --set controller.labels.app=ingress-api \
  --set controller.service.enabled=true \
  --set controller.service.type=LoadBalancer \
  --set controller.service.loadBalancerIP=192.168.122.240

tee > /tmp/metallb_system_namespace.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: metallb-system
EOF
kubectl apply -f /tmp/metallb_system_namespace.yaml

helm repo add metallb https://metallb.github.io/metallb
helm install metallb metallb/metallb -n metallb-system

tee > /tmp/metallb_ipaddresspool.yaml <<EOF
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
    name: public
    namespace: metallb-system
spec:
  addresses:
  - "192.168.122.240-192.168.122.249"
EOF

kubectl apply -f /tmp/metallb_ipaddresspool.yaml

tee > /tmp/metallb_l2advertisement.yaml <<EOF
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
    name: public
    namespace: metallb-system
spec:
    ipAddressPools:
    - public
EOF

kubectl apply -f /tmp/metallb_l2advertisement.yaml

kubectl label --overwrite nodes --all openstack-control-plane=enabled

echo "deb https://download.ceph.com/debian-reef/ jammy main" | sudo tee /etc/apt/sources.list.d/ceph.list
wget -q -O- https://download.ceph.com/keys/release.gpg | sudo gpg --dearmor -o /usr/share/keyrings/ceph.gpg
sudo apt update
sudo apt install -y cephadm ceph-common lvm2
sudo mkdir -p /etc/ceph
sudo mv /home/ubuntu/ceph.conf /etc/ceph/
sudo mv /home/ubuntu/ceph.client.*.keyring /etc/ceph/
sudo chown root:root /etc/ceph/ceph.conf /etc/ceph/ceph.client.*.keyring
sudo chmod 644 /etc/ceph/ceph.conf
sudo chmod 644 /etc/ceph/ceph.client.*.keyring
sudo ceph -s --conf /etc/ceph/ceph.conf --keyring /etc/ceph/ceph.client.admin.keyring
sudo chmod 644 /etc/ceph/ceph.client.admin.keyring
ceph -s --keyring /etc/ceph/ceph.client.admin.keyring

# Ensure ceph.conf has client.glance keyfile stanza (works with raw key secret)
if ! sudo grep -q "^\[client.glance\]" /etc/ceph/ceph.conf; then
  sudo tee -a /etc/ceph/ceph.conf > /dev/null <<'EOF'
[client.glance]
    keyfile = /etc/ceph/ceph.client.glance.keyring
    client_mount_timeout = 30
EOF
fi
# Refresh ceph-etc ConfigMap with updated ceph.conf (includes client.glance keyfile)
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
CLUSTER_ID=$(sudo ceph fsid)
MONITOR_IP="192.168.122.102:6789";
CEPH_KEY=$(sudo awk '/key =/ {print $3}' /etc/ceph/ceph.client.admin.keyring)

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

kubectl -n openstack delete secret pvc-ceph-client-key --ignore-not-found
kubectl -n openstack create secret generic pvc-ceph-client-key \
  --type Opaque \
  --from-literal=key="$CEPH_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

cd ~/osh/openstack-helm

export OPENSTACK_RELEASE=2025.1
export FEATURES="${OPENSTACK_RELEASE} ubuntu_noble"
export OVERRIDES_DIR=$(pwd)/overrides

OVERRIDES_URL=https://opendev.org/openstack/openstack-helm/raw/branch/master/values_overrides
for chart in rabbitmq mariadb memcached openvswitch libvirt keystone heat glance cinder placement nova neutron horizon; do
    helm osh get-values-overrides -d -u ${OVERRIDES_URL} -p ${OVERRIDES_DIR} -c ${chart} ${FEATURES}
done

python3 -m venv ~/openstack-client
source ~/openstack-client/bin/activate
pip install python-openstackclient
mkdir -p ~/.config/openstack
cat << EOF > ~/.config/openstack/clouds.yaml
clouds:
  openstack_helm:
    region_name: RegionOne
    identity_api_version: 3
    auth:
      username: 'admin'
      password: 'password'
      project_name: 'admin'
      project_domain_name: 'default'
      user_domain_name: 'default'
      auth_url: 'http://keystone.openstack.svc.cluster.local/v3'
EOF

source ~/openstack-client/bin/activate

helm upgrade --install rabbitmq openstack-helm/rabbitmq \
    --namespace=openstack \
    --set pod.replicas.server=1 \
    --wait --timeout=15m \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c rabbitmq ${FEATURES})

# Expose RabbitMQ for AZ cluster via MetalLB
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: rabbitmq-external
  namespace: openstack
  annotations:
    metallb.universe.tf/loadBalancerIPs: "192.168.122.241"
spec:
  type: LoadBalancer
  selector:
    application: rabbitmq
    component: server
  ports:
    - name: amqp
      port: 5672
      targetPort: 5672
    - name: http
      port: 15672
      targetPort: 15672
EOF

helm upgrade --install mariadb openstack-helm/mariadb \
  --namespace=openstack \
  --set pod.replicas.server=1 \
  --wait --timeout=15m \
  $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c mariadb ${FEATURES})

helm upgrade --install memcached openstack-helm/memcached \
  --namespace=openstack \
  --wait --timeout=15m \
  $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c memcached ${FEATURES})

helm upgrade --install keystone openstack-helm/keystone \
  --namespace=openstack \
  --wait --timeout=15m \
  $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c keystone ${FEATURES})

helm upgrade --install heat openstack-helm/heat \
  --namespace=openstack \
  --wait --timeout=15m \
  $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c heat ${FEATURES})

helm upgrade --install placement openstack-helm/placement \
  --namespace=openstack \
  --wait --timeout=15m \
  $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c placement ${FEATURES})

tee > ~/osh/openstack-helm/overrides/glance/glance_ceph.yaml <<EOF
storage: rbd
conf:
  ceph:
    enabled: true
    monitors: ["192.168.122.28:6789"]
    keyring_secret_name: images-rbd-keyring
  glance:
    glance_store:
      enabled_backends: rbd:rbd
      default_backend: rbd
      stores: rbd
    DEFAULT:
      enabled_backends: rbd:rbd
    rbd:
      rbd_store_pool: images
      rbd_store_user: glance
      rbd_store_ceph_conf: /etc/ceph/ceph.conf
      rados_connect_timeout: -1
      report_rbd_errors: true
EOF

kubectl -n openstack delete secret images-rbd-keyring --ignore-not-found
helm upgrade --install glance openstack-helm/glance \
  --namespace openstack \
  --values /home/ubuntu/osh/openstack-helm/overrides/glance/2025.1-ubuntu_noble.yaml \
  --values /home/ubuntu/osh/openstack-helm/overrides/glance/glance_ceph.yaml

GLANCE_API_POD=$(kubectl get pods -n openstack -l app.kubernetes.io/name=glance,app.kubernetes.io/component=api -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n openstack "$GLANCE_API_POD" -- ceph -s -n client.glance
kubectl exec -n openstack "$GLANCE_API_POD" -- ceph -s --id glance --keyring /etc/ceph/ceph.client.glance.keyring

sudo rbd -p images ls

sudo tee ~/osh/openstack-helm/overrides/cinder/cinder_ceph.yaml > /dev/null<<EOF
cinder:
  conf:
    ceph:
      enabled: true
      monitors: ["192.168.122.28:6789"]
      keyring_secret_name: cinder-rbd-keyring
    cinder:
      DEFAULT:
        enabled_backends: rbd1
        glance_api_version: 2
      rbd1:
        volume_driver: cinder.volume.drivers.rbd.RBDDriver
        volume_backend_name: rbd1
        rbd_pool: cinder.volumes
        rbd_user: cinder
        rbd_ceph_conf: /etc/ceph/ceph.conf
        rados_connect_timeout: -1
        rbd_flatten_volume_from_snapshot: false
        rbd_max_clone_depth: 5
        rbd_store_chunk_size: 4
        report_discard_supported: true
  extra_mounts:
    - name: ceph-conf
      mountPath: /etc/ceph
      hostPath: /etc/ceph
EOF

# Provide the full cinder keyring to the chart via a secret (like Glance)
kubectl -n openstack create secret generic cinder-rbd-keyring \
  --from-file=keyring=/etc/ceph/ceph.client.cinder.keyring \
  --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install cinder openstack-helm/cinder \
  --namespace openstack \
  --values /home/ubuntu/osh/openstack-helm/overrides/cinder/2025.1-ubuntu_noble.yaml \
  --values /home/ubuntu/osh/openstack-helm/overrides/cinder/cinder_ceph.yaml

CINDER_VOL_POD=$(kubectl get pods -n openstack -l application=cinder,component=volume -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n openstack "$CINDER_VOL_POD" -- ceph -s -n client.cinder --keyring /etc/ceph/ceph.client.cinder.keyring --conf /etc/ceph/ceph.conf
kubectl exec -n openstack "$CINDER_VOL_POD" -- rbd -p cinder.volumes ls --conf /etc/ceph/ceph.conf --keyring /etc/ceph/ceph.client.cinder.keyring -n client.cinder

sudo rbd -p cinder.volumes ls




# Neutron server (control-plane only, disable agents here)
cat > ~/osh/openstack-helm/overrides/neutron/neutron_control_only.yaml <<EOF
manifests:
  daemonset_ovs_agent: false
  daemonset_dhcp_agent: false
  daemonset_l3_agent: false
  daemonset_metadata_agent: false
  daemonset_lb_agent: false
  deployment_server: true
  deployment_rpc_server: true
  ingress_server: true
  service_server: true
  service_ingress_server: true
EOF

helm upgrade --install neutron openstack-helm/neutron \
  --namespace openstack \
  --wait --timeout=20m \
  --values /home/ubuntu/osh/openstack-helm/overrides/neutron/2025.1-ubuntu_noble.yaml \
  --values /home/ubuntu/osh/openstack-helm/overrides/neutron/neutron_control_only.yaml

# Nova control-plane (API, conductor, scheduler)
helm upgrade --install nova openstack-helm/nova \
  --namespace openstack \
  --wait --timeout=20m \
  $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c nova ${FEATURES})

# Horizon dashboard (optional)
helm upgrade --install horizon openstack-helm/horizon \
  --namespace openstack \
  --wait --timeout=15m \
  $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c horizon ${FEATURES})