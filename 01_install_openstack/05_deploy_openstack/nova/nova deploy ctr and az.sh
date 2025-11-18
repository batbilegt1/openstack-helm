
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

# Disable compute daemonset on control plane
manifests:
  daemonset_compute: false
  statefulset_compute_ironic: false

# Network backend
network:
  backend:
    - neutron
  novncproxy:
    type: LoadBalancer
    loadBalancerIP: 10.3.0.30

conf:
  nova:
    DEFAULT:
      debug: false
      transport_url: "rabbit://nova:NovaPassRabbit@10.3.0.21:5672/nova"
      my_ip: ""  # Will be set per compute node
    api_database:
      connection: "mysql+pymysql://openstack:OpenstackDBPass123@10.3.0.22:3306/nova_api"
      
    database:
      connection: "mysql+pymysql://openstack:OpenstackDBPass123@10.3.0.22:3306/nova"
      
    cell0_database:
      connection: "mysql+pymysql://openstack:OpenstackDBPass123@10.3.0.22:3306/nova_cell0"
      
    keystone_authtoken:
      auth_url: "http://10.3.0.35:5000/v3"
      www_authenticate_uri: "http://10.3.0.35:5000/v3"
      memcached_servers: "memcached:11211"
      auth_type: password
      project_domain_name: Default
      user_domain_name: Default
      project_name: service
      username: nova
      password: NovaPass123
      
    placement:
      auth_url: "http://10.3.0.35:5000/v3"
      auth_type: password
      project_domain_name: Default
      user_domain_name: Default
      project_name: service
      username: placement
      password: PlacementPass123
      region_name: RegionOne
      
    neutron:
      auth_url: "http://10.3.0.35:5000/v3"
      auth_type: password
      project_domain_name: Default
      user_domain_name: Default
      project_name: service
      username: neutron
      password: NeutronPass123
      region_name: RegionOne
      metadata_proxy_shared_secret: MetadataSecret123
      service_metadata_proxy: true
      
    vnc:
      enabled: false
    #   novncproxy_base_url: "http://10.3.0.30:6080/vnc_auto.html"
      server_listen: "0.0.0.0"
    #   server_proxyclient_address: "10.3.0.8"
      
    # glance:
    #   api_servers: "http://glance-api.openstack.svc.cluster.local:9292"
      
    # cinder:
    #   catalog_info: volumev3:cinderv3:internalURL
      
    scheduler:
      discover_hosts_in_cells_interval: 60
      
    # conductor:
    #   workers: 4

#   ceph:
#     enabled: true
#     admin_keyring: <YOUR_CEPH_ADMIN_KEYRING>
#     cinder:
#       keyring: <YOUR_CEPH_CINDER_KEYRING>
#       user: cinder

persistence:
  enabled: true
  storageClass: general
  size: 10Gi

dependencies:
  static:
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
        - endpoint: internal
          service: compute
      # pod: null
bootstrap:
  enabled: true
#   pacement config
endpoints:
  compute:
    port:
      novncproxy:
        default: 6088
  compute_novnc_proxy:
    port:
      novnc_proxy:
        default: 6088
        public: 80
  oslo_messaging:
    auth:
      nova:
        username: nova
        password: NovaPassRabbit
    host_fqdn_override:
      default: 10.3.0.21
    path: /nova
#   placement:
#     name: placement
#     host_fqdn_override:
#       default: 10.3.0.25
#   identity:
#     auth:
#       placement:
#         role: admin,service
#         region_name: RegionOne
#         username: placement
#         password: PlacementPass123
#         project_name: service
#         user_domain_name: service
#         project_domain_name: service
EOF

helm osh get-values-overrides -p ${OVERRIDES_DIR} -c nova ${FEATURES}
--values /home/ubuntu/overrides/nova/2025.1-ubuntu_noble.yaml


helm upgrade --install nova openstack-helm/nova \
    --namespace=openstack \
    --set conf.ceph.enabled=true \
    --values /home/ubuntu/overrides/nova/2025.1-ubuntu_noble.yaml \
    --values /home/ubuntu/overrides/nova/nova.yaml


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

















































































































































































# on compute node deploy nova
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

# Service configuration
service:
  type: LoadBalancer
  loadBalancerIP: 10.3.0.27
  metadata:
    type: LoadBalancer
    loadBalancerIP: 10.3.0.28

# Disable compute daemonset on control plane
manifests:
  daemonset_compute: false
  statefulset_compute_ironic: false

# Network backend
network:
  backend:
    - neutron
  novncproxy:
    type: LoadBalancer
    loadBalancerIP: 10.3.0.30

conf:
  nova:
    DEFAULT:
      debug: false
      transport_url: "rabbit://nova:NovaPassRabbit@10.3.0.21:5672/nova"
      my_ip: ""  # Will be set per compute node
    api_database:
      connection: "mysql+pymysql://openstack:OpenstackDBPass123@10.3.0.22:3306/nova_api"
      
    database:
      connection: "mysql+pymysql://openstack:OpenstackDBPass123@10.3.0.22:3306/nova"
      
    cell0_database:
      connection: "mysql+pymysql://openstack:OpenstackDBPass123@10.3.0.22:3306/nova_cell0"
      
    keystone_authtoken:
      auth_url: "http://10.3.0.35:5000/v3"
      www_authenticate_uri: "http://10.3.0.35:5000/v3"
      memcached_servers: "memcached:11211"
      auth_type: password
      project_domain_name: Default
      user_domain_name: Default
      project_name: service
      username: nova
      password: NovaPass123
      
    placement:
      auth_url: "http://10.3.0.35:5000/v3"
      auth_type: password
      project_domain_name: Default
      user_domain_name: Default
      project_name: service
      username: placement
      password: PlacementPass123
      region_name: RegionOne
      
    neutron:
      auth_url: "http://10.3.0.35:5000/v3"
      auth_type: password
      project_domain_name: Default
      user_domain_name: Default
      project_name: service
      username: neutron
      password: NeutronPass123
      region_name: RegionOne
      metadata_proxy_shared_secret: MetadataSecret123
      service_metadata_proxy: true
      
    vnc:
      enabled: false
    #   novncproxy_base_url: "http://10.3.0.30:6080/vnc_auto.html"
      server_listen: "0.0.0.0"
    #   server_proxyclient_address: "10.3.0.8"
      
    # glance:
    #   api_servers: "http://glance-api.openstack.svc.cluster.local:9292"
      
    # cinder:
    #   catalog_info: volumev3:cinderv3:internalURL
      
    scheduler:
      discover_hosts_in_cells_interval: 60
      
    # conductor:
    #   workers: 4

#   ceph:
#     enabled: true
#     admin_keyring: <YOUR_CEPH_ADMIN_KEYRING>
#     cinder:
#       keyring: <YOUR_CEPH_CINDER_KEYRING>
#       user: cinder

persistence:
  enabled: true
  storageClass: general
  size: 10Gi

bootstrap:
  enabled: true
#   pacement config
endpoints:
  compute:
    port:
      novncproxy:
        default: 6088
  compute_novnc_proxy:
    port:
      novnc_proxy:
        default: 6088
        public: 80
  oslo_messaging:
    auth:
      nova:
        username: nova
        password: NovaPassRabbit
    host_fqdn_override:
      default: 10.3.0.21
    path: /nova
#   placement:
#     name: placement
#     host_fqdn_override:
#       default: 10.3.0.25
#   identity:
#     auth:
#       placement:
#         role: admin,service
#         region_name: RegionOne
#         username: placement
#         password: PlacementPass123
#         project_name: service
#         user_domain_name: service
#         project_domain_name: service
EOF




















































































