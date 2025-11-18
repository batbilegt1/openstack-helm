

helm osh get-values-overrides -p ${OVERRIDES_DIR} -c neutron ${FEATURES}
--values /home/ubuntu/overrides/neutron/2025.1-ubuntu_noble.yaml

cat > ~/overrides/neutron/neutron.yaml << EOF
# CTR Cluster disable compute node services - only run control plane
labels:
  server:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled

service:
  type: LoadBalancer
  loadBalancerIP: 10.3.0.22

manifests:
  daemonset_dhcp_agent: false
  daemonset_l3_agent: false
  daemonset_metadata_agent: false
  daemonset_ovs_agent: false
  daemonset_sriov_agent: false
  deployment_server: true

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
      # LoadBalancer IP ашиглах
      transport_url: "rabbit://neutron:RabbitNeutronPass@10.3.0.21:5672/neutron"
      
    database:
      connection: "mysql+pymysql://openstack:OpenstackDBPass123@mariadb:3306/neutron"
      
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
  oslo_messaging:
    path: /neutron
    auth:
      neutron:
        username: neutron
        password: RabbitNeutronPass
    hosts:
      default: rabbitmq
    host_fqdn_override:
      default:
        host: 10.3.0.21
    port:
      amqp:
        default: 5672
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
    --values /home/ubuntu/overrides/neutron/2025.1-ubuntu_noble.yaml \
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






# on controller check network agents
