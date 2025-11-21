cat > ~/overrides/placement/placement.yaml <<EOF
---
labels:
  api:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
  job:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
images:
  pull_policy: IfNotPresent
  tags:
    placement: "quay.io/airshipit/placement:2025.1-ubuntu_noble"
    ks_user: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    ks_service: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    ks_endpoints: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    db_init: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    db_drop: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    placement_db_sync: "quay.io/airshipit/placement:2025.1-ubuntu_noble"
    dep_check: "quay.io/airshipit/kubernetes-entrypoint:latest-ubuntu_focal"
    image_repo_sync: "docker.io/docker:17.07.0"
# conf:
#   placement:
#     placement:
#       auth_strategy: keystone
#     api:
#       auth_strategy: keystone
#   wsgi_placement: |
#     Listen 0.0.0.0:8778
    
#     <VirtualHost *:8778>
#       ServerName placement-api.openstack.svc.cluster.local:8778
#       ServerAlias placement.openstack.svc.cluster.local:8778
      
#       WSGIScriptAlias / /var/www/cgi-bin/placement/placement-api
#       WSGIDaemonProcess placement-api processes=2 threads=10 user=placement group=placement display-name=%{GROUP}
#       WSGIProcessGroup placement-api
#       WSGIApplicationGroup %{GLOBAL}
#       WSGIPassAuthorization On
      
#       # Set the proper scheme for URL generation
#       SetEnvIf X-Forwarded-Proto https HTTPS=1
      
#       ErrorLog /dev/stdout
#       CustomLog /dev/stdout combined
      
#       <Directory /var/www/cgi-bin/placement>
#         Require all granted
#       </Directory>
#     </VirtualHost>

# dependencies:
#   static:
#     db_sync:
#       jobs:
#         - placement-db-init
endpoints:
  oslo_db:
    auth:
      admin:
        username: root
        password: mariadbRootPass
        secret:
          tls:
            internal: mariadb-tls-direct
      placement:
        username: placement
        password: placementDBPass
      nova_api:
        username: nova
        password: novaDBPass
    hosts:
      default: mariadb
    host_fqdn_override:
      default: null
    path: /placement
    scheme: mysql+pymysql
    port:
      mysql:
        default: 3306
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
      placement:
        role: admin
        region_name: RegionOne
        username: placement
        password: PlacementServicePass
        project_name: service
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
  placement:
    name: placement
    hosts:
      default: placement-api
      public: placement-api
      internal: placement-api
    host_fqdn_override:
      default: placement-api
      public: placement-api
      internal: placement-api
    path:
      default: /
    scheme:
      default: 'http'
      service: 'http'
      public: 'http'
    port:
      api:
        default: 8778
        public: 8778
        service: 8778
        internal: 8778
network:
  api:
    port: 8778
    ingress:
      public: true
      classes:
        namespace: "nginx"
        cluster: "nginx-cluster"
    node_port:
      enabled: false
manifests:
  certificates: false
  configmap_bin: true
  configmap_etc: true
  deployment: true
  job_image_repo_sync: true
  job_db_init: true
  job_db_sync: true
  job_db_drop: false
  job_ks_endpoints: true
  job_ks_service: true
  job_ks_user: true
  network_policy: false
  secret_db: true
  secret_ingress_tls: true
  secret_registry: true
  pdb: true
  ingress: true
  secret_keystone: true
  service_ingress: false
  service: false
...
EOF

helm upgrade --install placement openstack-helm/placement \
    --namespace=openstack \
    --values ~/overrides/placement/placement.yaml


helm uninstall placement -n openstack
kubectl delete pvc -n openstack -l application=placement
kubectl delete pod -n openstack -l application=placement
kubectl delete job -n openstack -l application=placement
kubectl delete cronjob -n openstack -l application=placement
kubectl delete secret -n openstack -l application=placement
kubectl delete secret -n openstack $(kubectl get secret -n openstack | grep placement | awk '{print $1}')
kubectl delete deployment -n openstack -l application=placement
kubectl delete statefulset -n openstack -l application=placement
kubectl delete deployment placement -n openstack --force --grace-period=0





kubectl exec -n openstack -it placement-api-8598c5d4f7-22lk2 -- placement-status upgrade check
export OPENSTACK_RELEASE=2025.1
# Features enabled for the deployment. This is used to look up values overrides.
export FEATURES="${OPENSTACK_RELEASE} ubuntu_noble"
# Directory where values overrides are looked up or downloaded to.
export OVERRIDES_DIR=$(pwd)/overrides
helm osh get-values-overrides -p ${OVERRIDES_DIR} -c placement ${FEATURES}
helm upgrade --install placement openstack-helm/placement \
    --namespace=openstack \
    --values ~/overrides/placement/placement.yaml \
    --set rabbitmq.username=rabbitmq \
    --set persistence.storageClass=general \
    --set rabbitmq.password='RabbitMQPass' \
    --set service.type=LoadBalancer \
    --set service.loadBalancerIP=10.3.0.36 \
    --wait \
    --timeout 10m


kubectl -n openstack get pods -l app=placement -o wide
cat > placement-api.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  annotations:
    meta.helm.sh/release-name: placement
    meta.helm.sh/release-namespace: openstack
  labels:
    app.kubernetes.io/managed-by: Helm
  name: placement-api
  namespace: openstack
spec:
  clusterIP: 10.96.154.130
  clusterIPs:
  - 10.96.154.130
  internalTrafficPolicy: Cluster
  ipFamilies:
  - IPv4
  ipFamilyPolicy: SingleStack
  ports:
  - name: p-api
    port: 8778
    protocol: TCP
    targetPort: 8778
  selector:
    app.kubernetes.io/component: api
    app.kubernetes.io/instance: placement
    app.kubernetes.io/name: placement
    application: placement
    component: api
    release_group: placement
  sessionAffinity: None
  type: ClusterIP
status:
  loadBalancer: {}
EOF
kubectl apply -f placement-api.yaml
kubectl get svc -n openstack placement-api

cat > ~placement-api.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  annotations:
    meta.helm.sh/release-name: placement
    meta.helm.sh/release-namespace: openstack
    metallb.universe.tf/address-pool: public
  name: placement-api
  namespace: openstack
spec:
  type: LoadBalancer
  loadBalancerIP: 10.3.0.37
  ports:
  - name: p-api
    port: 8778
    protocol: TCP
    targetPort: 8778
  selector:
    app.kubernetes.io/component: api
    app.kubernetes.io/instance: placement
    app.kubernetes.io/name: placement
    application: placement
    component: api
    release_group: placement
EOF


kubectl apply -f ~placement-api.yaml
kubectl get svc -n openstack 

nc -zv 10.3.0.37 8778
curl http://10.3.0.37:8778


helm uninstall placement -n openstack
kubectl delete pvc -n openstack -l application=placement
kubectl delete pod -n openstack -l application=placement
kubectl delete job -n openstack -l application=placement