


kubectl label node az-w1 az-w2 az-w3 openstack-compute-node=enabled
kubectl label node az-w1 az-w2 az-w3 openvswitch=enabled
kubectl label node az-w1 az-w2 az-w3 linuxbridge=enabled
export OPENSTACK_RELEASE=2025.1
# Features enabled for the deployment. This is used to look up values overrides.
export FEATURES="${OPENSTACK_RELEASE} ubuntu_noble"
# Directory where values overrides are looked up or downloaded to.
export OVERRIDES_DIR=$(pwd)/overrides

OVERRIDES_URL=https://opendev.org/openstack/openstack-helm/raw/branch/master/values_overrides
for chart in rabbitmq mariadb memcached openvswitch libvirt keystone heat glance cinder placement nova neutron horizon; do
    helm osh get-values-overrides -d -u ${OVERRIDES_URL} -p ${OVERRIDES_DIR} -c ${chart} ${FEATURES}
done





helm osh get-values-overrides -p ${OVERRIDES_DIR} -c openvswitch ${FEATURES}

helm upgrade --install openvswitch openstack-helm/openvswitch \
    --namespace=openstack \
    --values /home/ubuntu/overrides/openvswitch/ubuntu_noble.yaml 

helm osh wait-for-pods openstack


helm uninstall openvswitch -n openstack








cat > ~/overrides/libvirt/libvirt.yaml << EOF
# Ceph ашиглах тохиргоо
conf:
  ceph:
    enabled: false
EOF











helm osh get-values-overrides -p ${OVERRIDES_DIR} -c libvirt ${FEATURES}

helm upgrade --install libvirt openstack-helm/libvirt \
    --namespace=openstack \
    --set conf.ceph.enabled=false \
    --values /home/ubuntu/overrides/libvirt/2025.1-ubuntu_noble.yaml















helm osh get-values-overrides -p ${OVERRIDES_DIR} -c neutron ${FEATURES}
--values /home/ubuntu/overrides/neutron/2025.1-ubuntu_noble.yaml

cat > ~/overrides/neutron/neutron.yaml << EOF
# AZ Cluster - Зөвхөн Neutron Agent-ууд ажиллуулах
# Бүх agent-ууд compute node дээр ажиллана

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

# Service тохиргоо (Agent-уудад LoadBalancer хэрэггүй)
# service:
#   type: ClusterIP

# Зөвхөн Agent-уудыг ажиллуулах, Server болон Job-ууд идэвхгүй
manifests:
  daemonset_dhcp_agent: true  
  daemonset_l3_agent: true        
  daemonset_metadata_agent: true  
  daemonset_ovs_agent: true      
  daemonset_sriov_agent: false
  deployment_rpc_server: false
  
  # Control plane компонентууд идэвхгүй
  deployment_server: false      
  job_db_init: false            
  job_db_sync: false             
  job_db_drop: false             
  job_ks_endpoints: false         
  job_ks_service: false          
  job_ks_user: false             
  job_rabbit_init: false          
  service_ingress_server: false
  service_server: false
  
  # Service болон Ingress идэвхгүй
  service_ingress_server: false
  service_server: false
  
  # Secret-ууд (agent-уудад Keystone credentials хэрэгтэй)
  secret_db: false        
  secret_rabbitmq: false                 
  secret_keystone: true         

# Network тохиргоо
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
      
      # CTR cluster-ийн RabbitMQ-д холбогдох
      transport_url: "rabbit://neutron:RabbitNeutronPass@10.3.0.21:5672/neutron"
      
    # Database холболт хэрэггүй (agent-ууд зөвхөн RabbitMQ ашиглана)
    # Гэхдээ некоторые агентууд метаданаас уншдаг тул бага зэрэг config-д байх
    database:
      connection: "mysql+pymysql://openstack:OpenstackDBPass123@10.3.0.22:3306/neutron"
      
    # Keystone authentication (agent-ууд Neutron Server API-д хандахад хэрэгтэй)
    keystone_authtoken:
      # CTR cluster-ийн Keystone
      auth_url: "http://10.3.0.35:5000/v3"
      www_authenticate_uri: "http://10.3.0.35:5000/v3"
    #   memcached_servers: "10.3.0.22:11211"  # CTR Memcached (эсвэл хасах)
      auth_type: password
      project_domain_name: Default
      user_domain_name: Default
      project_name: service
      username: neutron
      password: NeutronPass123
      region_name: RegionOne
      
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
        # CTR cluster-ийн Nova metadata service
        nova_metadata_host: 10.3.0.28
        nova_metadata_port: 8775
        metadata_proxy_shared_secret: MetadataSecret123

# Endpoints - CTR cluster-ийн сервисүүд рүү холбогдох
endpoints:
  # RabbitMQ endpoint
  oslo_messaging:
    path: /neutron
    auth:
      neutron:
        username: neutron
        password: RabbitNeutronPass
    hosts:
      default: rabbitmq
    host_fqdn_override:
      default: 10.3.0.21  # CTR RabbitMQ LoadBalancer
    port:
      amqp:
        default: 5672
        
  # Database endpoint
  oslo_db:
    hosts:
      default: mariadb
    host_fqdn_override:
      default: 10.3.0.22  # CTR MariaDB LoadBalancer
    port:
      mysql:
        default: 3306
        
  # Keystone endpoint
  identity:
    auth:
      neutron:
        username: neutron
        password: NeutronPass123
        project_name: service
    hosts:
      default: keystone
    host_fqdn_override:
      default: 10.3.0.35  # CTR Keystone LoadBalancer
    port:
      api:
        default: 5000
        
  # Neutron Server endpoint (agent-ууд API-д хандана)
#   network:
#     hosts:
#       default: neutron-server
#     host_fqdn_override:
#       default:
#         host: 10.3.0.27  # CTR Neutron Server LoadBalancer (таны өмнөх тохиргооноос)
#     port:
#       api:
#         default: 9696

# Persistence идэвхгүй (agent-уудад хэрэггүй)
persistence:
  enabled: false

# Bootstrap идэвхгүй (CTR дээр хийгдсэн)
bootstrap:
  enabled: false

# ✅ ЧУХАЛ: Dependencies бүрэн идэвхгүй болгох (multi-cluster)
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
    --values /home/ubuntu/overrides/neutron/2025.1-ubuntu_noble.yaml \
    --values /home/ubuntu/overrides/neutron/neutron.yaml

helm osh wait-for-pods openstack



helm uninstall neutron -n openstack
kubectl delete pvc -n openstack -l application=neutron
kubectl delete job -n openstack -l application=neutron
kubectl delete pod -n openstack -l application=neutron





kubectl get daemonsets -n openstack -l application=neutron

# Pod лог шалгах
kubectl logs -n openstack -l application=neutron,component=dhcp-agent --tail=50
kubectl logs -n openstack -l application=neutron,component=l3-agent --tail=50
kubectl logs -n openstack -l application=neutron,component=metadata-agent --tail=50
kubectl logs -n openstack -l application=neutron,component=ovs-agent --tail=50

# Neutron RPC server логийг харах
kubectl logs -n openstack neutron-rpc-server-9dcf78488-rmrtc
kubectl logs -n openstack -l application=neutron,component=ovs -c init
# Хэрэв pod restart хийсэн бол өмнөх логийг харах
kubectl logs -n openstack neutron-ovs-agent-default-djg6m --previous


# check all connection to ctr
nc -zv 10.3.0.21 5672
nc -zv 10.3.0.22 3306
nc -zv 10.3.0.25 8778
nc -zv 10.3.0.35 5000
nc -zv 10.3.0.27 9696
nc -zv 10.3.0.28 8775










kubectl edit configmap coredns -n kube-system
kubectl rollout restart deployment  coredns -n kube-system
kubectl delete pods -n kube-system -l k8s-app=coredns
kubectl get configmap coredns -n kube-system  -o yaml > coredns_config.yaml
cat > coredns_config.yaml << EOF
apiVersion: v1
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30 {
           disable success cluster.local
           disable denial cluster.local
        }
        hosts {
          10.3.0.21 rabbitmq
          10.3.0.22 mariadb
          10.3.0.23 keystone
          10.3.0.24 placement
        }
        loop
        reload
        loadbalance
    }
kind: ConfigMap
metadata:
  creationTimestamp: "2025-10-06T13:45:11Z"
  name: coredns
  namespace: kube-system
  resourceVersion: "1307176"
  uid: 12cdc6c8-7f96-45d1-836e-e73a2c15f573
EOF