# === USER CONFIGURATION ===
NODES=(
  "ctr-m1 10.10.0.4"
  "ctr-w1 10.10.0.5"
  "ctr-w2 10.10.0.6"
  "ctr-w3 10.10.0.7"
)
CONTROL_PLANE_HOSTNAME="ctr-m1"
USER="ubuntu"
SSH_KEY="$HOME/.ssh/id_rsa"
PUB_KEY="${SSH_KEY}.pub"

# === OpenStack-Helm / Kubernetes Variables ===
export OPENSTACK_RELEASE=2025.1
export FEATURES="${OPENSTACK_RELEASE} ubuntu_noble"
export OVERRIDES_DIR="$HOME/osh/openstack-helm/overrides"
export OVERRIDES_URL="https://raw.githubusercontent.com/batbilegt1/openstack-helm/main/overrides"

OPENSTACK_NS="openstack"
KUBE_SYSTEM_NS="kube-system"
CEPH_SECRET_NAME="ceph-secret"
CEPH_KEY="AQBaTfxoYcxvIRAAflY7kBnDowRCuWlybuFLrA=="
CLUSTER_ID="5177a171-b158-11f0-9cce-905a08117d5a"
MONITOR_IP="10.10.0.12:6789"

# === Install Helm ===
curl -fsSL https://get.helm.sh/helm-v3.15.3-linux-amd64.tar.gz -o helm.tar.gz
tar -xvf helm.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
helm version

helm repo add openstack-helm https://tarballs.opendev.org/openstack/openstack-helm
helm plugin install https://opendev.org/openstack/openstack-helm-plugin

# === Clone Required Repos ===
mkdir -p ~/osh && cd ~/osh
git clone https://opendev.org/openstack/openstack-helm.git
git clone https://opendev.org/zuul/zuul-jobs.git

sudo apt update
sudo apt install -y python3-pip ansible
pip install --user ansible

export ANSIBLE_ROLES_PATH=~/osh/openstack-helm/roles:~/osh/zuul-jobs/roles

# === Generate Dynamic Inventory ===
cat > ~/osh/inventory.yaml <<EOF
all:
  vars:
    ansible_user: $USER
    ansible_port: 707
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

# === Kubernetes Namespaces & Ingress ===
kubectl create namespace $OPENSTACK_NS --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace metallb-system --dry-run=client -o yaml | kubectl apply -f -

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --version="4.8.3" \
  --namespace=$OPENSTACK_NS \
  --create-namespace \
  --set controller.kind=Deployment \
  --set controller.admissionWebhooks.enabled=false \
  --set controller.scope.enabled=true \
  --set controller.service.enabled=false \
  --set controller.ingressClassResource.name=nginx \
  --set controller.ingressClassResource.controllerValue="k8s.io/ingress-nginx" \
  --set controller.ingressClass=nginx \
  --set controller.labels.app=ingress-api

# === MetalLB Installation ===
helm repo add metallb https://metallb.github.io/metallb
helm install metallb metallb/metallb -n metallb-system

cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: public
  namespace: metallb-system
spec:
  addresses:
  - "172.24.128.0/24"
EOF

cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: public
  namespace: metallb-system
spec:
  ipAddressPools:
  - public
EOF

cat <<EOF | kubectl apply -f -
kind: Service
apiVersion: v1
metadata:
  name: public-openstack
  namespace: $OPENSTACK_NS
  annotations:
    metallb.universe.tf/loadBalancerIPs: "172.24.128.100"
spec:
  externalTrafficPolicy: Cluster
  type: LoadBalancer
  selector:
    app: ingress-api
  ports:
    - name: http
      port: 80
    - name: https
      port: 443
EOF

kubectl label --overwrite nodes --all openstack-control-plane=enabled

# === Ceph Setup ===
sudo apt install -y ceph-common
sudo mkdir -p /etc/ceph
sudo mv /home/ubuntu/ceph.conf /etc/ceph/
sudo mv /home/ubuntu/ceph.client.*.keyring /etc/ceph/
sudo chown root:root /etc/ceph/ceph.conf /etc/ceph/ceph.client.*.keyring
sudo chmod 644 /etc/ceph/ceph.conf
sudo chmod 600 /etc/ceph/ceph.client.*.keyring
sudo ceph -s --conf /etc/ceph/ceph.conf --keyring /etc/ceph/ceph.client.admin.keyring

kubectl -n $OPENSTACK_NS create configmap ceph-etc \
  --from-file=ceph.conf=/etc/ceph/ceph.conf \
  --dry-run=client -o yaml | kubectl apply -f -

helm repo add ceph-csi https://ceph.github.io/csi-charts
helm repo update
helm install ceph-csi-rbd ceph-csi/ceph-csi-rbd --namespace $KUBE_SYSTEM_NS

kubectl -n $OPENSTACK_NS create secret generic $CEPH_SECRET_NAME \
  --type="kubernetes.io/rbd" \
  --from-literal=key="$CEPH_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

# === StorageClass & Ceph CSI Config ===
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

kubectl -n $OPENSTACK_NS create secret generic pvc-ceph-client-key \
  --from-literal=key="$CEPH_KEY"

# === Download Helm Overrides & Deploy OpenStack Services ===
cd ~/osh/openstack-helm
for chart in rabbitmq mariadb memcached openvswitch libvirt keystone heat glance cinder placement nova neutron horizon; do
    helm osh get-values-overrides -d -u ${OVERRIDES_URL} -p ${OVERRIDES_DIR} -c ${chart} ${FEATURES}
done

helm upgrade --install rabbitmq openstack-helm/rabbitmq \
    --namespace=$OPENSTACK_NS \
    --set pod.replicas.server=1 \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c rabbitmq ${FEATURES})

helm upgrade --install mariadb openstack-helm/mariadb \
    --namespace=$OPENSTACK_NS \
    --set pod.replicas.server=1 \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c mariadb ${FEATURES})

helm upgrade --install memcached openstack-helm/memcached \
    --namespace=$OPENSTACK_NS \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c memcached ${FEATURES})

helm upgrade --install keystone openstack-helm/keystone \
    --namespace=$OPENSTACK_NS \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c keystone ${FEATURES})

helm upgrade --install heat openstack-helm/heat \
    --namespace=$OPENSTACK_NS \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c heat ${FEATURES})

helm upgrade --install glance openstack-helm/glance \
    --namespace=$OPENSTACK_NS \
    --values $OVERRIDES_DIR/glance/2025.1-ubuntu_noble.yaml \
    --values $OVERRIDES_DIR/glance/glance_ceph.yaml

helm upgrade --install cinder openstack-helm/cinder \
    --namespace=$OPENSTACK_NS \
    --values $OVERRIDES_DIR/cinder/2025.1-ubuntu_noble.yaml \
    --values $OVERRIDES_DIR/cinder/cinder_ceph.yaml
