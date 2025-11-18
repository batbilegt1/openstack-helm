export OPENSTACK_RELEASE=2025.1
export FEATURES="${OPENSTACK_RELEASE} ubuntu_noble"
export OVERRIDES_DIR=$(pwd)/overrides
OVERRIDES_URL=https://opendev.org/openstack/openstack-helm/raw/branch/master/values_overrides
for chart in rabbitmq mariadb memcached openvswitch libvirt keystone heat glance cinder placement nova neutron horizon; do
    helm osh get-values-overrides -d -u ${OVERRIDES_URL} -p ${OVERRIDES_DIR} -c ${chart} ${FEATURES}
done
kubectl get node --show-labels | grep openstack-control-plane
kubectl label nodes noble1 noble2 noble3 openstack-control-plane=enabled --overwrite


cat > ~/overrides/rabbitmq/rabbitmq.yaml << 'EOF'
---
labels:
  server:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
  prometheus_rabbitmq_exporter:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
  test:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
  jobs:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
images:
  tags:
    prometheus_rabbitmq_exporter_helm_tests: quay.io/airshipit/heat:2025.1-ubuntu_noble
    rabbitmq_init: quay.io/airshipit/heat:2025.1-ubuntu_noble
endpoints:
  oslo_messaging:
    auth:
      erlang_cookie: openstack-cookie
      user:
        username: rabbitmq
        password: RabbitMQPass
      guest:
        password: RabbitMQPass
    hosts:
      default: rabbitmq
      public: null
    host_fqdn_override:
      default: null
    path: /
    scheme: rabbit
    port:
      clustering:
        default: null
      amqp:
        default: 5672
      http:
        default: 15672
        public: 80
      metrics:
        default: 15692
...
EOF


cat ~/overrides/rabbitmq/rabbitmq.yaml
helm update

helm repo add openstack-helm https://opendev.org/openstack/openstack-helm/raw/branch/master/charts
helm repo update

helm upgrade --install rabbitmq openstack-helm/rabbitmq \
    --namespace=openstack \
    --set pod.replicas.server=1 \
    --timeout=600s \
    --values ~/overrides/rabbitmq/rabbitmq.yaml







kubectl get svc -n openstack rabbitmq
kubectl describe svc rabbitmq -n openstack | grep -A 10 "Port:"
kubectl logs -n openstack rabbitmq-rabbitmq-0 -f --tail=50
kubectl exec -it -n openstack rabbitmq-rabbitmq-0 -- rabbitmqctl status
kubectl get endpoints rabbitmq -n openstack
# Арга 3: Шинэ LoadBalancer Service үүсгэх (Аюулгүй)
cat > ~/rabbitmq-loadbalancer.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: rabbitmq-external
  namespace: openstack
  annotations:
    metallb.universe.tf/address-pool: public
spec:
  type: LoadBalancer
  loadBalancerIP: 10.4.0.33
  selector:
    application: rabbitmq
    component: server
  ports:
    - name: amqp
      port: 5672
      protocol: TCP
      targetPort: 5672
    - name: clustering
      port: 25672
      protocol: TCP
      targetPort: 25672
    - name: http
      port: 15672
      protocol: TCP
      targetPort: 15672
    - name: metrics
      port: 15692
      protocol: TCP
      targetPort: 15692
  sessionAffinity: ClientIP
EOF

kubectl apply -f ~/rabbitmq-loadbalancer.yaml

kubectl get svc rabbitmq-external -n openstack
# EXTERNAL-IP: 10.3.0.21 гарах ёстой

# Холболт шалгах
curl -v http://10.4.0.33:15672/
telnet 10.4.0.33 5672

# Service дэлгэрэнгүй
kubectl describe svc rabbitmq-external -n openstack
















kubectl logs -n openstack -l application=rabbitmq -f

# Events шалгах
kubectl get events -n openstack --sort-by='.lastTimestamp' | grep rabbitmq

# Endpoint шалгах
kubectl get endpoints rabbitmq-external -n openstack


# Cluster дотроос
kubectl run test-rabbitmq --rm -it --image=curlimages/curl -- sh
# Дотроос:
# curl -v http://10.3.0.21:15672/
# telnet 10.3.0.21 5672

# # Cluster гадна (CTR node-с)
# curl -v http://10.3.0.21:15672/
# nc -zv 10.3.0.21 5672


# RabbitMQ pod дотор
kubectl exec -it rabbitmq-rabbitmq-0 -n openstack -- bash

# Дотроос:
rabbitmqctl list_users
# openstack [administrator] гарах ёстой
rabbitmqctl list_connections
rabbitmqctl authenticate_user openstack AdminPassRabbit
# Success гарах ёстой

rabbitmqctl list_permissions
# openstack vhost "/" permission шалгах
# delete neutron user and create again and give permission
rabbitmqctl delete_user neutron
rabbitmqctl add_user neutron RabbitNeutronPass
rabbitmqctl set_permissions -p /neutron neutron ".*" ".*" ".*"
# show vhosts
rabbitmqctl list_vhosts
# delete neutron vhost and create again
rabbitmqctl delete_vhost /neutron
rabbitmqctl add_vhost /neutron



































