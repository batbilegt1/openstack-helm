


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

kubectl logs -n openstack -l application=libvirt -f
helm uninstall libvirt -n openstack
kubectl delete cm -n openstack -l application=libvirt
kubectl delete pvc -n openstack -l application=libvirt
kubectl delete pod -n openstack -l application=libvirt
kubectl delete job -n openstack -l application=libvirt
kubectl delete daemonset -n openstack -l application=libvirt
kubectl delete service -n openstack -l application=libvirt



helm osh get-values-overrides -p ${OVERRIDES_DIR} -c nova ${FEATURES}
--values /home/ubuntu/overrides/nova/2025.1-ubuntu_noble.yaml

cat > ~/overrides/nova/nova.yaml << EOF
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
      default: mariadb
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
      default: rabbitmq
    host_fqdn_override:
      default: mariadb
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
      default: rabbitmq
    host_fqdn_override:
      default: mariadb
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
      default: rabbitmq
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
  certificates: false
  compute_uuid_self_provisioning: true
  configmap_bin: true
  configmap_etc: true
  cron_job_cell_setup: false
  cron_job_service_cleaner: false
  cron_job_archive_deleted_rows: false
  daemonset_compute: true
  deployment_api_metadata: false
  deployment_api_osapi: false
  deployment_conductor: false
  deployment_novncproxy: false
  deployment_serialproxy: false
  deployment_spiceproxy: false
  deployment_scheduler: false
  ingress_metadata: false
  ingress_novncproxy: false
  ingress_serialproxy: false
  ingress_spiceproxy: false
  ingress_osapi: false
  job_bootstrap: false
  job_storage_init: false
  job_db_init: false
  job_db_sync: false
  job_db_drop: false
  job_image_repo_sync: false
  job_rabbit_init: false
  job_ks_endpoints: false
  job_ks_service: false
  job_ks_user: false
  job_cell_setup: false
  pdb_metadata: false
  pdb_osapi: false
  pod_rally_test: false
  network_policy: false
  secret_db_api: false
  secret_db_cell0: false
  secret_db: false
  secret_ingress_tls: true
  secret_keystone: true
  secret_ks_etc: true
  secret_rabbitmq: true
  secret_registry: true
  service_ingress_metadata: false
  service_ingress_novncproxy: false
  service_ingress_serialproxy: false
  service_ingress_spiceproxy: false
  service_ingress_osapi: false
  service_metadata: false
  service_novncproxy: false
  service_serialproxy: false
  service_spiceproxy: false
  service_osapi: false
  statefulset_compute_ironic: false
dependencies:
  static:
    compute:
      jobs: []
      services: []
      pod:
        - requireSameNode: true
          labels:
            application: libvirt
            component: libvirt
...
EOF


helm upgrade --install nova openstack-helm/nova \
    --namespace=openstack \
    --set bootstrap.wait_for_computes.enabled=false \
    --set conf.ceph.enabled=false \
    --values /home/ubuntu/overrides/nova/nova.yaml









kubectl logs -n openstack -l application=nova -f
helm osh wait-for-pods openstack
helm uninstall nova -n openstack
kubectl delete cm -n openstack -l application=nova
kubectl delete pvc -n openstack -l application=nova
kubectl delete job -n openstack -l application=nova
kubectl delete pod -n openstack -l application=nova
kubectl delete daemonset -n openstack -l application=nova
kubectl delete service -n openstack -l application=nova





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