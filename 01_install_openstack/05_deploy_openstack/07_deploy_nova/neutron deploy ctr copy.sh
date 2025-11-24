cat > ~/overrides/neutron/neutron.yaml << EOF
# CTR Cluster disable compute node services - only run control plane
labels:
  server:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
  rpc_server:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
images:
  tags:
    bootstrap: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    db_init: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    db_drop: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    ks_user: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    ks_service: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    ks_endpoints: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    neutron_db_sync: "quay.io/airshipit/neutron:2025.1-ubuntu_noble"
    neutron_dhcp: "quay.io/airshipit/neutron:2025.1-ubuntu_noble"
    neutron_l3: "quay.io/airshipit/neutron:2025.1-ubuntu_noble"
    neutron_l2gw: "quay.io/airshipit/neutron:2025.1-ubuntu_noble"
    neutron_linuxbridge_agent: "quay.io/airshipit/neutron:2025.1-ubuntu_noble"
    neutron_metadata: "quay.io/airshipit/neutron:2025.1-ubuntu_noble"
    neutron_ovn_metadata: "quay.io/airshipit/neutron:2025.1-ubuntu_noble"
    neutron_openvswitch_agent: "quay.io/airshipit/neutron:2025.1-ubuntu_noble"
    neutron_server: "quay.io/airshipit/neutron:2025.1-ubuntu_noble"
    neutron_rpc_server: "quay.io/airshipit/neutron:2025.1-ubuntu_noble"
    neutron_bagpipe_bgp: "quay.io/airshipit/neutron:2025.1-ubuntu_noble"
    neutron_netns_cleanup_cron: "quay.io/airshipit/neutron:2025.1-ubuntu_noble"
manifests:
  daemonset_dhcp_agent: false
  daemonset_l3_agent: false
  daemonset_metadata_agent: false
  daemonset_ovs_agent: false
  daemonset_sriov_agent: false
  deployment_server: true
  deployment_rpc_server: true

network:
  backend:
    - openvswitch
  interface:
    tunnel: bond1

conf:
  neutron:
    DEFAULT:
      debug: true
      core_plugin: ml2
      service_plugins: router
  plugins:
    ml2_conf:
      ml2:
        type_drivers: vlan,vxlan
        tenant_network_types: vxlan
        mechanism_drivers: openvswitch
        extension_drivers: port_security
      ml2_type_flat:
        flat_networks: public
      ml2_type_vxlan:
        vni_ranges: 1:1000
endpoints:
  cluster_domain_suffix: cluster.local
  oslo_db:
    auth:
      admin:
        username: root
        password: mariadbRootPass
        secret:
          tls:
            internal: mariadb-tls-direct
      neutron:
        username: neutron
        password: neutronDBPass
    hosts:
      default: mariadb
    host_fqdn_override:
      default: null
    path: /neutron
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
      neutron:
        username: neutron
        password: neutronRabbitPass
    statefulset:
      replicas: 2
      name: rabbitmq-rabbitmq
    hosts:
      default: rabbitmq
    host_fqdn_override:
      default: null
    path: /neutron
    scheme: rabbit
    port:
      amqp:
        default: 5672
      http:
        default: 15672
  compute_metadata:
    name: nova
    hosts:
      default: nova-metadata
      public: metadata
    host_fqdn_override:
      default: null
    path:
      default: /
    scheme:
      default: 'http'
    port:
      metadata:
        default: 8775
        public: 80
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
      neutron:
        role: admin,service
        region_name: RegionOne
        username: neutron
        password: neutronUserPass
        project_name: service
        user_domain_name: service
        project_domain_name: service
      nova:
        role: admin,service
        region_name: RegionOne
        project_name: service
        username: neutron_nova
        password: password
        user_domain_name: service
        project_domain_name: service
      placement:
        role: admin,service
        region_name: RegionOne
        project_name: service
        username: neutron_placement
        password: password
        user_domain_name: service
        project_domain_name: service
      designate:
        role: admin,service
        region_name: RegionOne
        project_name: service
        username: neutron_designate
        password: password
        user_domain_name: service
        project_domain_name: service
      ironic:
        role: admin,service
        region_name: RegionOne
        project_name: service
        username: neutron_ironic
        password: password
        user_domain_name: service
        project_domain_name: service
      test:
        role: admin
        region_name: RegionOne
        username: neutron-test
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
  network:
    name: neutron
    hosts:
      default: neutron-server
      public: neutron
    host_fqdn_override:
      default: neutron-server
      public: neutron
      # NOTE(portdirect): this chart supports TLS for fqdn over-ridden public
      # endpoints using the following format:
      # public:
      #   host: null
      #   tls:
      #     crt: null
      #     key: null
    path:
      default: null
    scheme:
      default: 'http'
      service: 'http'
    port:
      api:
        default: 9696
        public: 9696
        service: 9696
persistence:
  enabled: true
  storageClass: general
  size: 10Gi
dependencies:
  static:
    rpc_server:
      jobs:
        - neutron-db-sync
        - neutron-rabbit-init
bootstrap:
  enabled: true
EOF

helm upgrade --install neutron openstack-helm/neutron \
    --namespace=openstack \
    --values /home/ubuntu/overrides/neutron/neutron.yaml

helm osh wait-for-pods openstack



helm uninstall neutron -n openstack
kubectl delete pvc -n openstack -l application=neutron
kubectl delete job -n openstack -l application=neutron
kubectl delete pod -n openstack -l application=neutron


# Neutron RPC server логийг харах
kubectl logs -n openstack neutron-rpc-server-9dcf78488-rmrtc
kubectl logs -n openstack -l application=neutron,component=bootstrap -c init
# Хэрэв pod restart хийсэн бол өмнөх логийг харах
kubectl logs -n openstack neutron-rpc-server-9dcf78488-rmrtc --previous

# Бүх neutron pod-уудын статус
kubectl get pods -n openstack -l application=neutron

kubectl get svc -n openstack neutron-server -o yaml
cat > ~/neutron-server-external.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  annotations:
    meta.helm.sh/release-name: neutron
    meta.helm.sh/release-namespace: openstack
    metallb.universe.tf/address-pool: public
  name: neutron-server-external
  namespace: openstack
spec:
  type: LoadBalancer
  loadBalancerIP: 10.3.0.40
  ports:
  - name: q-api
    port: 9696
    protocol: TCP
    targetPort: 9696
  selector:
    app.kubernetes.io/component: server
    app.kubernetes.io/instance: neutron
    app.kubernetes.io/name: neutron
    application: neutron
    component: server
    release_group: neutron
EOF

kubectl apply -f ~/neutron-server-external.yaml

# on controller check network agents
