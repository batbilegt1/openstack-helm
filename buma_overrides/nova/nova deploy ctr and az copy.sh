
# nova control deployment in controller cluster
cat > ~/overrides/nova/nova.yaml << EOF
# Disable compute nodes - only control plane
labels:
  agent:
    compute:
      node_selector_key: openstack-compute-node
      node_selector_value: enabled
  conductor:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
  scheduler:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
images:
  tags:
    bootstrap: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    db_drop: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    db_init: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    ks_user: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    ks_service: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    ks_endpoints: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    nova_api: "quay.io/airshipit/nova:2025.1-ubuntu_noble"
    nova_cell_setup: "quay.io/airshipit/nova:2025.1-ubuntu_noble"
    nova_cell_setup_init: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    nova_compute: "quay.io/airshipit/nova:2025.1-ubuntu_noble"
    nova_compute_ssh: "quay.io/airshipit/nova:2025.1-ubuntu_noble"
    nova_conductor: "quay.io/airshipit/nova:2025.1-ubuntu_noble"
    nova_db_sync: "quay.io/airshipit/nova:2025.1-ubuntu_noble"
    nova_novncproxy: "quay.io/airshipit/nova:2025.1-ubuntu_noble"
    nova_novncproxy_assets: "quay.io/airshipit/nova:2025.1-ubuntu_noble"
    nova_scheduler: "quay.io/airshipit/nova:2025.1-ubuntu_noble"
    nova_spiceproxy: "quay.io/airshipit/nova:2025.1-ubuntu_noble"
    nova_spiceproxy_assets: "quay.io/airshipit/nova:2025.1-ubuntu_noble"
    nova_service_cleaner: "docker.io/openstackhelm/ceph-config-helper:latest-ubuntu_jammy"
endpoints:
  oslo_db:
    auth:
      admin:
        username: root
        password: mariadbRootPass
        secret:
          tls:
            internal: mariadb-tls-direct
      nova:
        username: nova
        password: novaDBPass
    hosts:
      default: mariadb
    host_fqdn_override:
      default: null
    path: /nova
    scheme: mysql+pymysql
    port:
      mysql:
        default: 3306
  oslo_db_api:
    auth:
      admin:
        username: root
        password: mariadbRootPass
      nova:
        username: nova
        password: novaDBPass
    hosts:
      default: mariadb
    host_fqdn_override:
      default: null
    path: /nova_api
    scheme: mysql+pymysql
    port:
      mysql:
        default: 3306
  oslo_db_cell0:
    auth:
      admin:
        username: root
        password: mariadbRootPass
      nova:
        username: nova
        password: novaDBPass
    hosts:
      default: mariadb
    host_fqdn_override:
      default: null
    path: /nova_cell0
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
      nova:
        username: nova
        password: novaRabbitMQPass
    statefulset:
      replicas: 2
      name: rabbitmq-rabbitmq
    hosts:
      default: rabbitmq
    host_fqdn_override:
      default: null
    path: /nova
    scheme: rabbit
    port:
      amqp:
        default: 5672
      http:
        default: 15672
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
      nova:
        role: admin,service
        region_name: RegionOne
        username: nova
        password: NovaUserPass
        project_name: service
        user_domain_name: service
        project_domain_name: service
      service:
        role: admin,service
        region_name: RegionOne
        username: nova_service_user
        password: NovaServiceUserPass
        project_name: service
        user_domain_name: service
        project_domain_name: service
      # NOTE(portdirect): the neutron user is not managed by the nova chart
      # these values should match those set in the neutron chart.
      neutron:
        role: admin,service
        region_name: RegionOne
        project_name: service
        user_domain_name: service
        project_domain_name: service
        username: nova_neutron
        password: password
      # NOTE(portdirect): the ironic user is not managed by the nova chart
      # these values should match those set in the ironic chart.
      ironic:
        role: admin,service
        auth_type: password
        auth_version: v3
        region_name: RegionOne
        project_name: service
        user_domain_name: service
        project_domain_name: service
        username: nova_ironic
        password: password
      placement:
        role: admin,service
        region_name: RegionOne
        username: nova_placement
        password: PlacementServicePass
        project_name: service
        user_domain_name: service
        project_domain_name: service
      cinder:
        role: admin,service
        region_name: RegionOne
        username: nova_cinder
        password: password
        project_name: service
        user_domain_name: service
        project_domain_name: service
      test:
        role: admin
        region_name: RegionOne
        username: nova-test
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
  compute:
    name: nova
    hosts:
      default: nova-api
      public: nova
    host_fqdn_override:
      default: null
      # NOTE(portdirect): this chart supports TLS for fqdn over-ridden public
      # endpoints using the following format:
      # public:
      #   host: null
      #   tls:
      #     crt: null
      #     key: null
    path:
      default: "/v2.1/"
    scheme:
      default: 'http'
      service: 'http'
    port:
      api:
        default: 8774
        public: 80
        service: 8774
      novncproxy:
        default: 6081
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
    scheme:
      default: http
    port:
      api:
        default: 9292
        public: 9292
  network:
    name: neutron
    hosts:
      default: neutron-server
      public: neutron
    host_fqdn_override:
      default: neutron-server
      public: neutron
    path:
      default: null
    scheme:
      default: 'http'
    port:
      api:
        default: 9696
        public: 9696
manifests:
  daemonset_compute: false
  statefulset_compute_ironic: false

dependencies:
  dynamic:
    common:
      local_image_registry:
        jobs:
          - nova-image-repo-sync
        services:
          - endpoint: node
            service: local_image_registry
    targeted:
      ovn:
        compute:
          pod:
            - requireSameNode: true
              labels:
                application: ovn
                component: ovn-controller
      openvswitch:
        compute:
          pod:
            - requireSameNode: true
              labels:
                application: neutron
                component: neutron-ovs-agent
      linuxbridge:
        compute:
          pod:
            - requireSameNode: true
              labels:
                application: neutron
                component: neutron-lb-agent
      sriov:
        compute:
          pod:
            - requireSameNode: true
              labels:
                application: neutron
                component: neutron-sriov-agent
  static:
    api:
      jobs:
        - nova-db-sync
        - nova-ks-user
        - nova-ks-endpoints
        - nova-rabbit-init
      services:
        - endpoint: internal
          service: oslo_messaging
        - endpoint: internal
          service: oslo_db
        - endpoint: internal
          service: identity
    api_metadata:
      jobs:
        - nova-db-sync
        - nova-ks-user
        - nova-ks-endpoints
        - nova-rabbit-init
      services:
        - endpoint: internal
          service: oslo_messaging
        - endpoint: internal
          service: oslo_db
        - endpoint: internal
          service: identity
    bootstrap:
      services:
        - endpoint: internal
          service: identity
        - endpoint: internal
          service: compute
    cell_setup:
      jobs:
        - nova-db-sync
        - nova-rabbit-init
      services:
        - endpoint: internal
          service: oslo_messaging
        - endpoint: internal
          service: oslo_db
        - endpoint: internal
          service: identity
      pod:
        - requireSameNode: false
          labels:
            application: nova
            component: conductor
    service_cleaner:
      jobs:
        - nova-db-sync
        - nova-rabbit-init
      services: []
    compute:
      pod:
        - requireSameNode: true
          labels:
            application: libvirt
            component: libvirt
      jobs:
        - nova-db-sync
        - nova-rabbit-init
      services:
        - endpoint: internal
          service: oslo_messaging
        - endpoint: internal
          service: image
        - endpoint: internal
          service: compute
        - endpoint: internal
          service: network
        - endpoint: internal
          service: compute_metadata
    compute_ironic:
      jobs:
        - nova-db-sync
        - nova-rabbit-init
      services:
        - endpoint: internal
          service: oslo_messaging
        - endpoint: internal
          service: image
        - endpoint: internal
          service: compute
        - endpoint: internal
          service: network
        - endpoint: internal
          service: baremetal
    conductor:
      jobs:
        - nova-db-sync
        - nova-rabbit-init
      services:
        - endpoint: internal
          service: oslo_messaging
        - endpoint: internal
          service: oslo_db
        - endpoint: internal
          service: identity
        - endpoint: internal
          service: compute
    db_drop:
      services:
        - endpoint: internal
          service: oslo_db
    archive_deleted_rows:
      jobs:
        - nova-db-init
        - nova-db-sync
    db_init:
      services:
        - endpoint: internal
          service: oslo_db
    db_sync:
      jobs:
        - nova-db-init
      services:
        - endpoint: internal
          service: oslo_db
    ks_endpoints:
      jobs:
        - nova-ks-service
      services:
        - endpoint: internal
          service: identity
    ks_service:
      services:
        - endpoint: internal
          service: identity
    ks_user:
      services:
        - endpoint: internal
          service: identity
    rabbit_init:
      services:
        - service: oslo_messaging
          endpoint: internal
    novncproxy:
      jobs:
        - nova-db-sync
      services:
        - endpoint: internal
          service: oslo_db
    serialproxy:
      jobs:
        - nova-db-sync
      services:
        - endpoint: internal
          service: oslo_db
    spiceproxy:
      jobs:
        - nova-db-sync
      services:
        - endpoint: internal
          service: oslo_db
    scheduler:
      jobs:
        - nova-db-sync
        - nova-rabbit-init
      services:
        - endpoint: internal
          service: oslo_messaging
        - endpoint: internal
          service: oslo_db
        - endpoint: internal
          service: identity
        - endpoint: internal
          service: compute
    tests:
      services:
        - endpoint: internal
          service: image
        - endpoint: internal
          service: compute
        - endpoint: internal
          service: network
        - endpoint: internal
          service: compute_metadata
    image_repo_sync:
      services:
        - endpoint: internal
          service: local_image_registry
...
EOF
# nova metadata loadblancer (metallb)
cat > nova-metadata-lb.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  annotations:
    meta.helm.sh/release-name: nova
    meta.helm.sh/release-namespace: openstack
    metallb.universe.tf/address-pool: public
  name: nova-metadata
  namespace: openstack
spec:
  type: LoadBalancer
  loadBalancerIP: 10.3.0.36
  ports:
  - name: n-meta
    port: 8775
    protocol: TCP
    targetPort: 8775
  selector:
    app.kubernetes.io/component: metadata
    app.kubernetes.io/instance: nova
    app.kubernetes.io/name: nova
    application: nova
    component: metadata
    release_group: nova
  sessionAffinity: None
EOF
kubectl apply -f nova-metadata-lb.yaml
kubectl get svc nova-metadata -n openstack
nc -zv 10.3.0.36 8775

helm osh get-values-overrides -p ${OVERRIDES_DIR} -c nova ${FEATURES}
--values /home/ubuntu/overrides/nova/2025.1-ubuntu_noble.yaml


helm upgrade --install nova openstack-helm/nova \
    --namespace=openstack \
    --set conf.ceph.enabled=true \
    --values /home/ubuntu/overrides/nova/nova.yaml
kubectl delete job -n openstack -l application=nova,component=cell-setup
kubectl delete pod -n openstack -l application=nova,component=cell-setup


 kubectl exec -it nova-conductor-57ffcc6f9-hz9rr -n openstack -- nova-manage cell_v2 list_hosts
kubectl logs  -n openstack -l application=nova
kubectl logs  -n openstack -l application=nova,component=cell-setup -c init
# edite config nova
kubectl edit configmap nova-bin -n openstack

    # --set bootstrap.wait_for_computes.enabled=true \
helm uninstall nova -n openstack
kubectl delete pvc -n openstack -l application=nova
kubectl delete pod -n openstack -l application=nova
kubectl delete job -n openstack -l application=nova

kubectl delete svc -n openstack -l application=nova






kubectl logs -n openstack -l application=nova --tail=50 -f
# show nova proxy logs
kubectl logs -n openstack -l component=proxy -l application=nova --tail=50 -f
# show nova all log
kubectl logs -n openstack nova-novncproxy-6bbd6d8477-zckq6 -f