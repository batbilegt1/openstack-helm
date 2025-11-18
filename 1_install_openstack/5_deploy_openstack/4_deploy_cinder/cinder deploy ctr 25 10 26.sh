
cat > ~/overrides/cinder/cinder.yaml <<EOF
---
storage: ceph

labels:
  api:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
  backup:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
  job:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
  scheduler:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
  test:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
  volume:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
conf:
  rbd:
    volume_driver: cinder.volume.drivers.rbd.RBDDriver
    rbd_pool: volumes
    rbd_ceph_conf: /etc/ceph/ceph.conf
    rbd_user: volumes
    rbd_secret_uuid: "ce-drivers-not-needed" # optional for Helm
    rbd_flatten_volume_from_snapshot: false
    rbd_max_clone_depth: 5
    rbd_store_chunk_size: 4
    rados_connect_timeout: -1
    glance_api_version: 2
  # backends:
  #   rbd1:
  #     volume_driver: cinder.volume.drivers.rbd.RBDDriver
  #     volume_backend_name: rbd1
  #     rbd_pool: volumes
  #     rbd_user: volumes
  #     rbd_ceph_conf: "/etc/ceph/ceph.conf"
  #     rbd_secret_uuid: 457eb676-33da-42ec-9a8c-9293d545c337
  #     rbd_flatten_volume_from_snapshot: false
  #     rbd_max_clone_depth: 5
  #     rbd_store_chunk_size: 4
  #     rados_connect_timeout: -1
  #     image_volume_cache_enabled: true
  #     image_volume_cache_max_size_gb: 200
  #     image_volume_cache_max_count: 50
  #     report_discard_supported: true
extra_mounts:
  - name: ceph-conf
    mountPath: /etc/ceph
    hostPath: /etc/ceph
images:
  tags:
    db_init: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    cinder_db_sync: "quay.io/airshipit/cinder:2025.1-ubuntu_noble"
    db_drop: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    ks_user: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    ks_service: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    ks_endpoints: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    cinder_api: "quay.io/airshipit/cinder:2025.1-ubuntu_noble"
    bootstrap: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    cinder_scheduler: "quay.io/airshipit/cinder:2025.1-ubuntu_noble"
    cinder_volume: "quay.io/airshipit/cinder:2025.1-ubuntu_noble"
    cinder_volume_usage_audit: "quay.io/airshipit/cinder:2025.1-ubuntu_noble"
    cinder_db_purge: "quay.io/airshipit/cinder:2025.1-ubuntu_noble"
    cinder_storage_init: "docker.io/openstackhelm/ceph-config-helper:latest-ubuntu_jammy"
    cinder_backup: "quay.io/airshipit/cinder:2025.1-ubuntu_noble"
    cinder_backup_storage_init: "docker.io/openstackhelm/ceph-config-helper:latest-ubuntu_jammy"
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
      cinder:
        role: admin,service
        region_name: RegionOne
        username: cinder
        password: keystoneCinderPass
        project_name: service
        user_domain_name: service
        project_domain_name: service
      nova:
        role: admin,service
        region_name: RegionOne
        project_name: service
        username: cinder_nova
        password: password
        user_domain_name: service
        project_domain_name: service
      swift:
        role: admin,service
        region_name: RegionOne
        project_name: service
        username: cinder_swift
        password: password
        user_domain_name: service
        project_domain_name: service
      service:
        role: admin,service
        region_name: RegionOne
        project_name: service
        username: cinder_service_user
        password: password
        user_domain_name: service
        project_domain_name: service
      test:
        role: admin
        region_name: RegionOne
        username: cinder-test
        password: password
        project_name: test
        user_domain_name: service
        project_domain_name: service
    hosts:
      default: keystone
      internal: keystone-api
    host_fqdn_override:
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
      default: null
    path:
      default: null
    scheme:
      default: http
    port:
      api:
        default: 9292
        public: 80
  volume:
    name: cinder
    hosts:
      default: cinder-api
      public: cinder
    host_fqdn_override:
      default: cinder-api
      public: cinder
    path:
      default: '/v1/%(tenant_id)s'
      healthcheck: /healthcheck
    scheme:
      default: 'http'
    port:
      api:
        default: 8776
        public: 8776
  volumev2:
    name: cinderv2
    hosts:
      default: cinder-api
      public: cinder
    host_fqdn_override:
      default: cinder-api
      public: cinder
    path:
      default: '/v2/%(tenant_id)s'
      healthcheck: /healthcheck
    scheme:
      default: 'http'
    port:
      api:
        default: 8776
        public: 8776
  volumev3:
    name: cinderv3
    hosts:
      default: cinder-api
      public: cinder
    host_fqdn_override:
      default: cinder-api
      public: cinder
    path:
      default: '/v3'
      healthcheck: /healthcheck
    scheme:
      default: 'http'
    port:
      api:
        default: 8776
        public: 8776
  oslo_db:
    auth:
      admin:
        username: root
        password: mariadbRootPass
        secret:
          tls:
            internal: mariadb-tls-direct
      cinder:
        username: cinder
        password: cinderDBPass
    hosts:
      default: mariadb
    host_fqdn_override:
      default: null
    path: /cinder
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
      cinder:
        username: cinder
        password: cinderRabbitMQPass
    statefulset:
      replicas: 2
      name: rabbitmq-rabbitmq
    hosts:
      default: rabbitmq
    host_fqdn_override:
      default: null
    path: /cinder
    scheme: rabbit
    port:
      amqp:
        default: 5672
      http:
        default: 15672
...
EOF
helm upgrade --install cinder openstack-helm/cinder \
    --namespace=openstack \
    --timeout=600s \
    --values ~/overrides/cinder/cinder.yaml



helm uninstall cinder -n openstack
kubectl delete pvc -n openstack -l application=cinder
kubectl delete pod -n openstack -l application=cinder
kubectl delete job -n openstack -l application=cinder
kubectl delete svc -n openstack -l application=cinder






cat > ~/overrides/cinder/cinder-api-external.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  annotations:
    meta.helm.sh/release-name: cinder
    meta.helm.sh/release-namespace: openstack
    metallb.universe.tf/address-pool: public
  name: cinder-api-external
  namespace: openstack
spec:
  type: LoadBalancer
  loadBalancerIP: 10.3.0.41
  ports:
  - name: c-api
    port: 8776
    protocol: TCP
    targetPort: 8776
  selector:
    app.kubernetes.io/component: api
    app.kubernetes.io/instance: cinder
    app.kubernetes.io/name: cinder
    application: cinder
    component: api
    release_group: cinder
EOF
kubectl apply -f ~/overrides/cinder/cinder-api-external.yaml