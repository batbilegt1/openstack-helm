
mkdir -p ~/overrides/heat
cat > ~/overrides/heat/heat.yaml <<EOF
---
labels:
  api:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
  cfn:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
  engine:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
  job:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
  test:
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
    heat_db_sync: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    heat_api: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    heat_cfn: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    heat_engine: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    heat_engine_cleaner: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    heat_purge_deleted: "quay.io/airshipit/heat:2025.1-ubuntu_noble"

endpoints:
  cluster_domain_suffix: cluster.local
  local_image_registry:
    name: docker-registry
    namespace: docker-registry
    hosts:
      default: localhost
      internal: docker-registry
      node: localhost
    host_fqdn_override:
      default: null
    port:
      registry:
        node: 5000
  oci_image_registry:
    name: oci-image-registry
    namespace: oci-image-registry
    auth:
      enabled: false
      heat:
        username: heat
        password: password
    hosts:
      default: localhost
    host_fqdn_override:
      default: null
    port:
      registry:
        default: null
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
      heat:
        role: admin
        region_name: RegionOne
        username: heat
        password: password
        project_name: service
        user_domain_name: service
        project_domain_name: service
      heat_trustee:
        role: admin
        region_name: RegionOne
        username: heat-trust
        password: password
        project_name: service
        user_domain_name: service
        project_domain_name: service
      heat_stack_user:
        role: admin
        region_name: RegionOne
        username: heat-domain
        password: password
        domain_name: heat
      test:
        role: admin
        region_name: RegionOne
        username: heat-test
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
      default: 'http'
    port:
      api:
        default: 80
        internal: 5000
  orchestration:
    name: heat
    hosts:
      default: heat-api
      public: heat
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
      default: '/v1/%(project_id)s'
    scheme:
      default: 'http'
      service: 'http'
    port:
      api:
        default: 8004
        public: 80
        service: 8004
  cloudformation:
    name: heat-cfn
    hosts:
      default: heat-cfn
      public: cloudformation
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
      default: /v1
    scheme:
      default: 'http'
      service: 'http'
    port:
      api:
        default: 8000
        public: 80
        service: 8000
  oslo_db:
    auth:
      admin:
        username: root
        password: mariadbRootPass
        secret:
          tls:
            internal: mariadb-tls-direct
      heat:
        username: heat
        password: mariadbHeatPass
    hosts:
      default: mariadb
    host_fqdn_override:
      default: null
    path: /heat
    scheme: mysql+pymysql
    port:
      mysql:
        default: 3306
  oslo_cache:
    auth:
      # NOTE(portdirect): this is used to define the value for keystone
      # authtoken cache encryption key, if not set it will be populated
      # automatically with a random value, but to take advantage of
      # this feature all services should be set to use the same key,
      # and memcache service.
      memcache_secret_key: null
    hosts:
      default: memcached
    host_fqdn_override:
      default: null
    port:
      memcache:
        default: 11211
  oslo_messaging:
    auth:
      admin:
        username: rabbitmq
        password: RabbitMQPass
        secret:
          tls:
            internal: rabbitmq-tls-direct
      heat:
        username: heat
        password: heatRabbitMQPass
    statefulset:
      replicas: 2
      name: rabbitmq-rabbitmq
    hosts:
      default: rabbitmq
    host_fqdn_override:
      default: null
    path: /heat
    scheme: rabbit
    port:
      amqp:
        default: 5672
      http:
        default: 15672
  fluentd:
    namespace: null
    name: fluentd
    hosts:
      default: fluentd-logging
    host_fqdn_override:
      default: null
    path:
      default: null
    scheme: 'http'
    port:
      service:
        default: 24224
      metrics:
        default: 24220
  # NOTE(tp6510): these endpoints allow for things like DNS lookups and ingress
  # They are using to enable the Egress K8s network policy.
  kube_dns:
    namespace: kube-system
    name: kubernetes-dns
    hosts:
      default: kube-dns
    host_fqdn_override:
      default: null
    path:
      default: null
    scheme: http
    port:
      dns:
        default: 53
        protocol: UDP
  ingress:
    namespace: null
    name: ingress
    hosts:
      default: ingress
    port:
      ingress:
        default: 80
...
EOF

helm osh get-values-overrides -p ${OVERRIDES_DIR} -c heat ${FEATURES}
--values /home/ubuntu/overrides/heat/2025.1-ubuntu_noble.yaml



helm upgrade --install heat openstack-helm/heat \
    --namespace=openstack \
    --values ~/overrides/heat/heat.yaml 
helm osh wait-for-pods openstack



helm uninstall heat -n openstack
kubectl delete pvc -n openstack -l application=heat
kubectl delete pod -n openstack -l application=heat
kubectl delete job -n openstack -l application=heat





kubectl get pods -n openstack -l application=heat
kubectl get jobs -n openstack
kubectl get svc -n openstack | grep heat


kubectl run -n openstack curl-test --rm -it --image=curlimages/curl -- /bin/sh
# контейнер дээр:
curl -sS http://heat-api:8004/


kubectl get jobs -n openstack | grep heat
kubectl logs -n openstack heat-db-sync

kubectl get ingress -n openstack
kubectl describe ingress keystone -n openstack

kubectl run -n openstack os-client --rm -it --image=openstackclient/python-openstackclient -- /bin/sh
# контейнер дотор орж:
export OS_AUTH_URL=http://keystone:5000/v3/
export OS_USERNAME=admin
export OS_PASSWORD='your_admin_password'
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
# токен шалгах:
openstack token issue
# heat endpoint-ийг шалгах:
openstack endpoint list | grep -i heat
# heat API version шалгах:
curl -sS http://heat-api:8004/ | jq .



