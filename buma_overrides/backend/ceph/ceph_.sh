kubectl -n openstack create configmap ceph-etc   --from-file=ceph.conf=/etc/ceph/ceph.conf   --dry-run=client -o yaml | kubectl apply -f -
helm repo add ceph-csi https://ceph.github.io/csi-charts
helm repo update
helm install ceph-csi-rbd ceph-csi/ceph-csi-rbd -n kube-system
kubectl get pods -n kube-system | grep csi
kubectl get csidrivers
OPENSTACK_NS="openstack"
KUBE_SYSTEM_NS="kube-system"
CEPH_SECRET_NAME="ceph-secret"
CEPH_KEY="AQBaTfxoYcxvIRAAflY7kBnDowRCuWlybuFLrA=="
CLUSTER_ID="5177a171-b158-11f0-9cce-905a08117d5a"
MONITOR_IP="10.10.0.12:6789"
kubectl create namespace $OPENSTACK_NS --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic $CEPH_SECRET_NAME   --namespace=$OPENSTACK_NS   --type="kubernetes.io/rbd"   --from-literal=key="$CEPH_KEY"   --dry-run=client -o yaml | kubectl apply -f -
# 1. StorageClass-ийг үүсгэх
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

# 2. Ceph CSI ConfigMap-ийг үүсгэх
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
kubectl -n openstack create secret generic pvc-ceph-client-key   --from-literal=key="$CEPH_KEY"
cd ~/osh/openstack-helm
kubectl -n openstack delete secret pvc-ceph-client-key
kubectl -n openstack create secret generic pvc-ceph-client-key   --from-literal=key="$CEPH_KEY"



































