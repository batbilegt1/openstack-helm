
cat > ~/overrides/glance/glance.yaml <<EOF
---
storage: rbd
conf:
  ceph:
    enabled: true
    monitors: ["10.3.0.18:6789"]
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
images:
  tags:
    bootstrap: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    db_init: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    db_drop: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    ks_user: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    ks_service: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    ks_endpoints: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    glance_db_sync: "quay.io/airshipit/glance:2025.1-ubuntu_noble"
    glance_api: "quay.io/airshipit/glance:2025.1-ubuntu_noble"
    glance_metadefs_load: "quay.io/airshipit/glance:2025.1-ubuntu_noble"
    glance_storage_init: "docker.io/openstackhelm/ceph-config-helper:latest-ubuntu_jammy"
endpoints:
  cluster_domain_suffix: cluster.local
  identity:
    name: keystone
    auth:
      admin:
        region_name: RegionOne
        username: admin
        password: KeystoneAdminPass
        project_name: admin
        user_domain_name: default
        project_domain_name: default
      glance:
        role: admin
        region_name: RegionOne
        username: glance
        password: KeystoneGlancePass
        project_name: service
        user_domain_name: service
        project_domain_name: service
      test:
        role: admin
        region_name: RegionOne
        username: glance-test
        password: password
        project_name: test
        user_domain_name: service
        project_domain_name: service
    hosts:
      default: keystone
      internal: keystone-api
    host_fqdn_override:
      default: keystone
      internal: keystone-api
    path:
      default: /v3
    scheme:
      default: http
    port:
      api:
        default: 80
        internal: 5000
  image:
    name: glance
    hosts:
      default: glance-api
      public: glance
    host_fqdn_override:
      default: glance-api
      public: glance
    path:
      default: null
      healthcheck: /healthcheck
    scheme:
      default: http
      service: http
    port:
      api:
        default: 9292
        public: 9292
  oslo_db:
    auth:
      admin:
        username: root
        password: mariadbRootPass
        secret:
          tls:
            internal: mariadb-tls-direct
      glance:
        username: glance
        password: glanceDBPass
    hosts:
      default: mariadb
    host_fqdn_override:
      default: null
    path: /glance
    scheme: mysql+pymysql
    port:
      mysql:
        default: 3306
  oslo_messaging:
    auth:
      admin:
        username: rabbitmq
        password: RabbitMQPass
        secret:
          tls:
            internal: rabbitmq-tls-direct
      glance:
        username: glance
        password: glanceRabbitMQPass
    statefulset:
      replicas: 2
      name: rabbitmq-rabbitmq
    hosts:
      default: rabbitmq
    host_fqdn_override:
      default: null
    path: /glance
    scheme: rabbit
    port:
      amqp:
        default: 5672
      http:
        default: 15672
...
EOF

kubectl -n openstack delete secret images-rbd-keyring --ignore-not-found

helm upgrade --install glance openstack-helm/glance \
    --namespace=openstack \
    --values ~/overrides/glance/glance.yaml

# Wait and verify Ceph connectivity from inside the Glance API pod
GLANCE_API_POD=$(kubectl get pods -n openstack -l app.kubernetes.io/name=glance,app.kubernetes.io/component=api -o jsonpath='{.items[0].metadata.name}')
kubectl wait -n openstack --for=condition=ContainersReady pod/$GLANCE_API_POD --timeout=180s || true
kubectl exec -n openstack "$GLANCE_API_POD" -- ceph -s -n client.glance || true
kubectl exec -n openstack "$GLANCE_API_POD" -- ceph -s --id glance --keyring /etc/ceph/ceph.client.glance.keyring || true

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

