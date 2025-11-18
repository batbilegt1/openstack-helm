
mkdir -p ~/osh/openstack-helm/overrides/glance
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


helm uninstall glance -n openstack 
# kubectl delete pvc -n openstack -l application=glance
kubectl delete pod -n openstack -l application=glance
kubectl delete job -n openstack -l application=glance
kubectl delete svc -n openstack -l application=glance
kubectl delete secret -n openstack -l application=glance
kubectl delete configmap -n openstack -l application=glance
kubectl delete ingress -n openstack -l application=glance
kubectl delete statefulset -n openstack -l application=glance
kubectl delete deployment -n openstack -l application=glance
kubectl delete daemonset -n openstack -l application=glance
kubectl delete pvc -n openstack -l application=glance
kubectl delete cronjob -n openstack -l application=glance
kubectl delete cmdb -n openstack -l application=glance

helm uninstall glance -n openstack
kubectl delete pvc -n openstack -l application=glance
kubectl delete pod -n openstack -l application=glance
kubectl delete job -n openstack -l application=glance
kubectl delete cronjob -n openstack -l application=glance
kubectl delete secret -n openstack -l application=glance
kubectl delete secret -n openstack $(kubectl get secret -n openstack | grep glance | awk '{print $1}')
kubectl delete deployment -n openstack -l application=glance
kubectl delete statefulset -n openstack -l application=glance
kubectl delete deployment glance -n openstack --force --grace-period=0

kubectl api-resources --verbs=list --namespaced -o name | xargs -n 1 kubectl get --show-kind --ignore-not-found -n openstack | grep glance

kubectl get pods -n openstack -l application=glance -w
POD=$(kubectl get pod -n openstack -l job-name=glance-storage-init -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n openstack $POD -c glance-storage-init
kubectl logs -n openstack $POD -c ceph-keyring-placement || true
kubectl delete pod -n openstack -l job-name=glance-storage-init || true
kubectl get pods -n openstack -l application=glance -w
# init pod логийг шалгах:
POD=$(kubectl get pod -n openstack -l job-name=glance-storage-init -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n openstack $POD -c glance-storage-init

cat > ~/overrides/glance/glance-api-external.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  annotations:
    meta.helm.sh/release-name: glance
    meta.helm.sh/release-namespace: openstack
    metallb.universe.tf/address-pool: public
  name: glance-api-external
  namespace: openstack
spec:
  type: LoadBalancer
  loadBalancerIP: 10.3.0.39
  ports:
  - name: g-api
    port: 9292
    protocol: TCP
    targetPort: 9292
  selector:
    app.kubernetes.io/component: api
    app.kubernetes.io/instance: glance
    app.kubernetes.io/name: glance
    application: glance
    component: api
    release_group: glance
EOF
kubectl apply -f ~/overrides/glance/glance-api-external.yaml

kubectl logs -n openstack -l application=glance -f
nc -zv 10.3.0.39 9292
curl http://10.3.0.39:9292/v2/images

