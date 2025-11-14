


helm upgrade --install openvswitch openstack-helm/openvswitch \
    --namespace=openstack \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c openvswitch ${FEATURES})

helm osh wait-for-pods openstack


helm uninstall openvswitch -n openstack




















helm osh get-values-overrides -p ${OVERRIDES_DIR} -c neutron ${FEATURES}
--values /home/ubuntu/overrides/neutron/2025.1-ubuntu_noble.yaml

cat > ~/overrides/neutron/neutron.yaml << EOF
# Зөвхөн тооцоололтой холбоотой агентуудыг ажиллуулах
labels:
  agent:
    dhcp:
      node_selector_key: openstack-compute-disabled # Удирдлагын агентуудыг worker дээр идэвхгүй болгох
      node_selector_value: enabled
    l3:
      node_selector_key: openstack-compute-disabled
      node_selector_value: enabled
    metadata:
      node_selector_key: openstack-compute-disabled
      node_selector_value: enabled
    ovs:
      node_selector_key: openstack-compute-node # Зөвхөн OVS агентийг compute зангилаа дээр ажиллуулах
      node_selector_value: enabled
  server:
    node_selector_key: openstack-compute-disabled
    node_selector_value: enabled

# Удирдлагын түвшний бүрэлдэхүүн хэсгүүдийг идэвхгүй болгох
manifests:
  daemonset_dhcp_agent: false
  daemonset_l3_agent: false
  daemonset_metadata_agent: false
  daemonset_ovs_agent: true  # Зөвхөн OVS агентийг ажиллуулах
  deployment_server: false  # Compute дээр neutron-server байхгүй
  job_db_init: false
  job_db_sync: false
  # ... (Бусад Job-уудыг идэвхгүй болгох)
  job_ks_endpoints: false
  # ...
  service_server: false

# Сүлжээний тохиргоо
network:
  backend:
    - openvswitch
  interface:
    tunnel: eth0  # Таны compute зангилаануудын туннелийн интерфэйсд тааруулж тохируулна

conf:
  neutron:
    DEFAULT:
      debug: false
      transport_url: "rabbit://openstack:AdminPassRabbit@10.3.0.21:5672/" # management1-ийн RabbitMQ LB IP
      
    keystone_authtoken:
      auth_url: "http://10.3.0.23:5000/v3"
      www_authenticate_uri: "http://10.3.0.23:5000/v3"
      memcached_servers: "10.3.0.22:11211"  # MariaDB LB IP-ийн оронд Memcached-ийн LB IP байх ёстой. Хэрэв Memcached-д LB өгөөгүй бол ClusterIP (memcached:11211) ашиглах нь найдвартай биш тул үүнийг 10.3.0.22:11211 гэж өгөх боломжгүй. **Хэрэв та Memcached-д LoadBalancer IP өгөөгүй бол 'keystone:11211' гэж ашиглах эсвэл Memcached-д LB IP өгөх шаардлагатай.**
      auth_type: password
      project_domain_name: Default
      user_domain_name: Default
      project_name: service
      username: neutron
      password: NeutronPass123
      
  plugins:
    openvswitch_agent:
      ovs:
        bridge_mappings: public:br-ex
        local_ip: ""  # Зангилаа бүрт автоматаар илэрнэ
      agent:
        tunnel_types: vxlan
        l2_population: true
      securitygroup:
        firewall_driver: openvswitch

# Compute зангилаанууд дээр persistence шаардлагагүй
persistence:
  enabled: false

bootstrap:
  enabled: false
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















mkdir -p ~/.config/openstack
tee ~/.config/openstack/clouds.yaml << EOF
clouds:
  openstack_helm:
    region_name: RegionOne
    identity_api_version: 3
    auth:
      username: 'admin'
      password: 'password'
      project_name: 'admin'
      project_domain_name: 'default'
      user_domain_name: 'default'
      auth_url: 'http://10.3.0.35:5000/v3'
EOF


openstack --os-cloud openstack_helm endpoint list






