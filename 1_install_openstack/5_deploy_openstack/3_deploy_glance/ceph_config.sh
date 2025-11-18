kubectl -n openstack get secret pvc-ceph-client-key -o jsonpath='{.data.key}' | base64 -d | sed -n '1,5p'


RAW=$(kubectl -n openstack get secret pvc-ceph-client-key -o jsonpath='{.data.key}' | base64 -d)

cat > ceph.client.admin.keyring <<EOF
[client.admin]
key = ${RAW}
EOF

cat > ceph.client.glance.keyring <<EOF
[client.admin]
key = ${RAW}
EOF
kubectl -n openstack create secret generic pvc-ceph-client-key --from-file=ceph.client.admin.keyring --dry-run=client -o yaml | kubectl apply -f -


tr -d '\r' < ceph.client.glance.keyring > tmp && mv tmp ceph.client.glance.keyring

kubectl -n openstack create secret generic pvc-ceph-client-key --from-file=ceph.client.admin.keyring=ceph.client.glance.keyring --dry-run=client -o yaml | kubectl apply -f -


# before
# ubuntu@ctr-m1:~$ kubectl -n openstack get secret pvc-ceph-client-key -o yaml
# apiVersion: v1
# data:
#   key: QVFCYVRmeG9ZY3h2SVJBQWZsWTdrQm5Eb3dSQ3VXbHlidUZMckE9PQ==
# kind: Secret
# metadata:
#   creationTimestamp: "2025-11-04T13:32:47Z"
#   name: pvc-ceph-client-key
#   namespace: openstack
#   resourceVersion: "5793"
#   uid: bf4a6dc0-6430-4665-a014-03a43e045313
# type: Opaque