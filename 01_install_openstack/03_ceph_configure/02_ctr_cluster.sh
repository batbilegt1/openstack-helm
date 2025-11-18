echo "deb https://download.ceph.com/debian-reef/ noble main" | sudo tee /etc/apt/sources.list.d/ceph.list
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