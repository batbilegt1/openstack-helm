export OPENSTACK_RELEASE=2025.1
export FEATURES="${OPENSTACK_RELEASE} ubuntu_noble"
export OVERRIDES_DIR=$(pwd)/overrides
OVERRIDES_URL=https://opendev.org/openstack/openstack-helm/raw/branch/master/values_overrides
for chart in rabbitmq mariadb memcached openvswitch libvirt keystone heat glance cinder placement nova neutron horizon; do
    helm osh get-values-overrides -d -u ${OVERRIDES_URL} -p ${OVERRIDES_DIR} -c ${chart} ${FEATURES}
done

helm upgrade --install openvswitch openstack-helm/openvswitch \
    --namespace=openstack \
    --values /home/ubuntu/overrides/openvswitch/ubuntu_noble.yaml

helm osh wait-for-pods openstack


helm uninstall openvswitch -n openstack











helm osh get-values-overrides -p ${OVERRIDES_DIR} -c neutron ${FEATURES}
--values /home/ubuntu/overrides/neutron/2025.1-ubuntu_noble.yaml

cat > ~/overrides/neutron/neutron.yaml << EOF
labels:
  agent:
    dhcp:
      node_selector_key: openstack-compute-node
      node_selector_value: enabled
    l3:
      node_selector_key: openstack-compute-node
      node_selector_value: enabled
    metadata:
      node_selector_key: openstack-compute-node
      node_selector_value: enabled
  ovs:
    node_selector_key: openstack-compute-node
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
# Удирдлагын түвшний бүрэлдэхүүн хэсгүүдийг идэвхгүй болгох
manifests:
  certificates: false
  cron_job_ovn_db_sync: false
  configmap_bin: true
  configmap_etc: true
  daemonset_dhcp_agent: true
  daemonset_l3_agent: true
  daemonset_lb_agent: false
  daemonset_metadata_agent: true
  daemonset_ovs_agent: true
  daemonset_sriov_agent: false
  daemonset_l2gw_agent: false
  daemonset_bagpipe_bgp: false
  daemonset_bgp_dragent: false
  daemonset_netns_cleanup_cron: true
  daemonset_ovn_metadata_agent: false
  daemonset_ovn_vpn_agent: false
  deployment_ironic_agent: false
  deployment_server: false
  deployment_rpc_server: false
  ingress_server: false
  job_bootstrap: false
  job_db_init: false
  job_db_sync: false
  job_db_drop: false
  job_image_repo_sync: false
  job_ks_endpoints: false
  job_ks_service: false
  job_ks_user: false
  job_rabbit_init: false
  pdb_server: false
  pod_rally_test: false
  network_policy: false
  secret_db: true
  secret_ingress_tls: true
  secret_keystone: true
  secret_ks_etc: true
  secret_rabbitmq: true
  secret_registry: true
  service_ingress_server: false
  service_server: false
network:
  backend:
    - openvswitch
  interface:
    tunnel: bond1  # AZ cluster-ийн VXLAN tunnel interface
  
  # External network bridge (L3 agent-д хэрэгтэй)
  auto_bridge_add:
    br-ex: bond1  # External network interface

conf:
  neutron:
    DEFAULT:
      debug: true
      core_plugin: ml2
  plugins:
    ml2_conf:
      ml2:
        type_drivers: flat,vlan,vxlan,local
        tenant_network_types: vxlan
        mechanism_drivers: openvswitch
        extension_drivers: port_security
      ml2_type_flat:
        flat_networks: public
      ml2_type_vxlan:
        vni_ranges: 1:1000
        
    # OVS Agent тохиргоо
    openvswitch_agent:
      ovs:
        bridge_mappings: public:br-ex  # External network mapping
      agent:
        tunnel_types: vxlan
        l2_population: true
        arp_responder: true
      securitygroup:
        firewall_driver: neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
        
    # L3 Agent тохиргоо
    l3_agent:
      DEFAULT:
        interface_driver: openvswitch
        external_network_bridge: ""  # Empty - ашиглахгүй (bridge_mappings ашиглана)
        agent_mode: legacy  # эсвэл dvr, dvr_snat
        
    # DHCP Agent тохиргоо
    dhcp_agent:
      DEFAULT:
        interface_driver: openvswitch
        dhcp_driver: neutron.agent.linux.dhcp.Dnsmasq
        enable_isolated_metadata: true
        force_metadata: true
        
    # Metadata Agent тохиргоо
  metadata_agent:
    DEFAULT:
      metadata_proxy_shared_secret: "password"

endpoints:
  cluster_domain_suffix: cluster.ctr
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
      default: mariadb
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
      default: rabbitmq
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
      default: metadata
      public: metadata
    host_fqdn_override:
      default: metadata
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
      internal: keystone-api
    host_fqdn_override:
      internal: keystone-api
    path:
      default: /v3
    scheme:
      default: http
    port:
      api:
        internal: 5000
persistence:
  enabled: false
bootstrap:
  enabled: false
dependencies:
  static:
    ovs_agent:
      services: []
      jobs: []
    dhcp:
      services: []
      jobs: []
    l3:
      services: []
      jobs: []
    metadata:
      services: []
      jobs: []
pod:
  replicas:
    server: 0 

EOF

helm upgrade --install neutron openstack-helm/neutron \
    --namespace=openstack \
    --values /home/ubuntu/overrides/neutron/neutron.yaml



helm osh wait-for-pods openstack


kubectl exec -n openstack -it neutron-ovs-agent-default-2xnkn -- bash
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
