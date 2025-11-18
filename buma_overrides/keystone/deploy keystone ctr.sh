cat > ~/overrides/keystone/keystone-api.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: keystone-api
  namespace: openstack
  annotations:
    meta.helm.sh/release-name: keystone
    meta.helm.sh/release-namespace: openstack
    metallb.universe.tf/address-pool: public
spec:
  type: LoadBalancer
  loadBalancerIP: 10.4.0.35
  selector:
    app.kubernetes.io/component: api
    app.kubernetes.io/instance: keystone
    app.kubernetes.io/name: keystone
    application: keystone
    component: api
    release_group: keystone
  ports:
  - name: ks-pub
    port: 5000
    protocol: TCP
    targetPort: 5000
  # - name: http
  #   port: 80
  #   protocol: TCP
  #   targetPort: 80
  # - name: https
  #   port: 443
  #   protocol: TCP
  #   targetPort: 443
EOF
kubectl apply -f ~/overrides/keystone/keystone-api.yaml

cat > keystone-external.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  annotations:
    meta.helm.sh/release-name: keystone
    meta.helm.sh/release-namespace: openstack
  name: keystone
  namespace: openstack
spec:
  type: LoadBalancer
  loadBalancerIP: 10.4.0.38
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: 80
  - name: https
    port: 443
    protocol: TCP
    targetPort: 443
  selector:
    app: ingress-api
EOF
kubectl apply -f keystone-external.yaml

cat > ~/overrides/keystone/keystone.yaml <<EOF
---
labels:
  api:
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
    keystone_api: "quay.io/airshipit/keystone:2025.1-ubuntu_noble"
    keystone_bootstrap: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
    keystone_credential_rotate: "quay.io/airshipit/keystone:2025.1-ubuntu_noble"
    keystone_credential_setup: "quay.io/airshipit/keystone:2025.1-ubuntu_noble"
    keystone_db_sync: "quay.io/airshipit/keystone:2025.1-ubuntu_noble"
    keystone_domain_manage: "quay.io/airshipit/keystone:2025.1-ubuntu_noble"
    keystone_fernet_rotate: "quay.io/airshipit/keystone:2025.1-ubuntu_noble"
    keystone_fernet_setup: "quay.io/airshipit/keystone:2025.1-ubuntu_noble"
    ks_user: "quay.io/airshipit/heat:2025.1-ubuntu_noble"
conf:
  wsgi_script_name: wsgi.py
endpoints:
  identity:
    namespace: null
    name: keystone
    auth:
      admin:
        region_name: RegionOne
        username: admin
        password: KeystoneAdminPass
        project_name: admin
        user_domain_name: default
        project_domain_name: default
        default_domain_id: default
      test:
        role: admin
        region_name: RegionOne
        username: keystone-test
        password: KeystoneTestPass
        project_name: test
        user_domain_name: default
        project_domain_name: default
        default_domain_id: default
    hosts:
      default: keystone
      internal: keystone-api
    host_fqdn_override:
      internal: keystone-api
    path:
      default: /v3
      healthcheck: /healthcheck
    scheme:
      default: http
      service: http
    port:
      api:
        default: 80
        internal: 5000
        service: 5000
  oslo_db:
    namespace: null
    auth:
      admin:
        username: root
        password: mariadbRootPass
        secret:
          tls:
            internal: mariadb-tls-direct
      keystone:
        username: keystone
        password: KeystoneDBPass
    hosts:
      default: mariadb
    host_fqdn_override:
      default: null
    path: /keystone
    scheme: mysql+pymysql
    port:
      mysql:
        default: 3306
  oslo_messaging:
    namespace: null
    auth:
      admin:
        username: rabbitmq
        password: RabbitMQPass
        secret:
          tls:
            internal: rabbitmq-tls-direct
      keystone:
        username: keystone
        password: keystoneRabbitMQPass
    statefulset:
      replicas: 2
      name: rabbitmq-rabbitmq
    hosts:
      default: rabbitmq
    host_fqdn_override:
      default: null
    path: /keystone
    scheme: rabbit
    port:
      amqp:
        default: 5672
      http:
        default: 15672
manifests:
  certificates: false
  configmap_bin: true
  configmap_etc: true
  cron_credential_rotate: true
  cron_fernet_rotate: true
  deployment_api: true
  ingress_api: true
  job_bootstrap: true
  job_credential_cleanup: true
  job_credential_setup: true
  job_db_init: true
  job_db_sync: true
  job_db_drop: false
  job_domain_manage: true
  job_fernet_setup: true
  job_image_repo_sync: true
  job_rabbit_init: true
  pdb_api: true
  pod_rally_test: true
  network_policy: false
  secret_credential_keys: true
  secret_db: true
  secret_fernet_keys: true
  secret_ingress_tls: true
  secret_keystone: true
  secret_rabbitmq: true
  secret_registry: true
  service_ingress_api: false
  service_api: false
...
EOF

helm upgrade --install keystone openstack-helm/keystone \
  --namespace openstack \
  --values ~/overrides/keystone/keystone.yaml

# manifests:
#   certificates: false
#   configmap_bin: true
#   configmap_etc: true
#   cron_credential_rotate: true
#   cron_fernet_rotate: true
#   deployment_api: true
#   ingress_api: true
#   job_bootstrap: true
#   job_credential_cleanup: true
#   job_credential_setup: true
#   job_db_init: true
#   job_db_sync: true
#   job_db_drop: false
#   job_domain_manage: true
#   job_fernet_setup: true
#   job_image_repo_sync: true
#   job_rabbit_init: true
#   pdb_api: true
#   pod_rally_test: true
#   network_policy: false
#   secret_credential_keys: true
#   secret_db: true
#   secret_fernet_keys: true
#   secret_ingress_tls: true
#   secret_keystone: true
#   secret_rabbitmq: true
#   secret_registry: true
#   service_ingress_api: false
#   service_api: false

# Health and root endpoint via MetalLB IP
curl -vk http://10.4.0.35:5000/healthcheck
curl -vk http://10.4.0.35:5000/v3/

# Cleanup previous deployment
helm uninstall keystone -n openstack
kubectl delete pvc -n openstack -l application=keystone
kubectl delete pod -n openstack -l application=keystone
kubectl delete job -n openstack -l application=keystone
kubectl delete cronjob -n openstack -l application=keystone
kubectl delete secret -n openstack -l application=keystone
kubectl delete secret -n openstack $(kubectl get secret -n openstack | grep keystone | awk '{print $1}')
kubectl delete deployment -n openstack -l application=keystone
kubectl delete statefulset -n openstack -l application=keystone



helm repo add openstack-helm https://opendev.org/openstack/openstack-helm/raw/branch/master/charts
helm repo update




curl -sS http://10.3.0.35:5000/v3/
curl -sS http://10.3.0.38:80/v3/
curl -vk http://10.3.0.35:5000/v3/
curl -vk http://10.3.0.35:80/v3/
curl -vk http://10.3.0.38:80/v3/
curl -vk http://10.3.0.35/v3/

helm upgrade --install


# openstack test pod create and access keystone 
kubectl run -n openstack os-client --rm -it --image=openstackclient/python-openstackclient -- /bin/sh
# контейнер дотор орж:
cat > admin-rc << EOF
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=admin
export OS_AUTH_URL=http://keystone-api:5000/v3
export OS_USERNAME=keystone-test
export OS_PASSWORD=KeystoneTestPass
export OS_PROJECT_NAME=test
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_DOMAIN_NAME=default
EOF

cat > check-openstack.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: check-openstack
  namespace: openstack
spec:
  containers:
  - name: check-openstack
    image: quay.io/airshipit/openstack-client:2025.1-ubuntu_jammy
    command: ["/bin/sh", "-c", "sleep 3600"]
EOF

kubectl apply -f check-openstack.yaml

kubectl exec -n openstack -it check-openstack -- /bin/bash
cat > admin-rc << EOF
export OS_PROJECT_NAME=admin
export OS_AUTH_URL=http://keystone-api:5000/v3
export OS_USERNAME=admin
export OS_PASSWORD=KeystoneAdminPass
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_DOMAIN_NAME=default
EOF
openstack token issue -f value -c id
TOKEN=gAAAAABpCvPTgpRiJCX0obOhjcgbEb4vE-ySgVOY6MhkzwxuU-vNOO3dV5oN9K7EFAuLdOy8QdNOkQJDgktatOkaK2zLX6DZpwclqNOqOhIaIWS9Kr-r35SVF28AN49lgWHDAJsh0pgN0HtQ6lAjKZyzqGSY07Aa__ox0I00ymYcCMxk3KpMkiY
curl -sS -H "X-Auth-Token: $TOKEN" "http://keystone-api:5000/v3/auth/catalog" | jq '.catalog[] | select(.name=="placement")'
source admin-rc
openstack token issue
openstack project list
openstack user list
openstack role list
openstack service list
openstack endpoint list


kubectl logs -n openstack -l application=keystone -f
kubectl get pods -n openstack -l application=keystone
kubectl get svc keystone -n openstack -o wide

kubectl get svc -n openstack
kubectl get svc keystone -n openstack -o yaml

helm list -n openstack
helm get values keystone -n openstack --all | grep 10.3


kubectl describe svc keystone -n openstack
kubectl get events -n openstack --sort-by='.metadata.creationTimestamp' | tail -n 



kubectl patch svc keystone -n openstack -p '{"spec":{"type":"LoadBalancer","loadBalancerIP":"10.3.0.35"}}'
kubectl get svc keystone -n openstack -o wide




ingress_api:
  service:
    type: LoadBalancer
    loadBalancerIP: 10.3.0.35


helm upgrade --install keystone openstack-helm/keystone \
  --namespace openstack \
  -f ~/overrides/keystone/keystone.yaml \
  --values /home/ubuntu/overrides/keystone/2025.1-ubuntu_noble.yaml


ingress:
  enabled: true
  hosts:
    - host: keystone.example.local
      paths:
        - /


kubectl get svc keystone -n openstack -o wide

kubectl run -n openstack tmp --rm -it --image=curlimages/curl -- /bin/sh
# контейнер дээр:

# 1) Шууд Service -> LoadBalancer болгох (түр, хурдан)
kubectl patch svc keystone -n openstack -p '{"spec":{"type":"LoadBalancer","loadBalancerIP":"10.3.0.35"}}'
kubectl get svc keystone -n openstack -o wide




# 2) Ingress-ийг LoadBalancer-ээр ил гаргах (зөв, тогтвортой)

network:
  api:
    ingress:
      public: true
      classes:
        namespace: "nginx"
        cluster: "nginx-cluster"


controller:
  service:
    type: LoadBalancer
    loadBalancerIP: 10.3.0.24



kubectl patch svc ingress-nginx-controller -n ingress-nginx -p '{"spec":{"type":"LoadBalancer","loadBalancerIP":"10.3.0.24"}}'
kubectl get svc -n ingress-nginx

kubectl get ingress -n openstack
# гаднаас:



ingress_api:
  service:
    type: LoadBalancer
    loadBalancerIP: 10.3.0.35


# эсвэл хэрвээ keystone өөрөө ingress ашигладаг байдлаар:
network:
  api:
    ingress:
      public: true



kubectl get svc -n openstack
kubectl get ingress -n openstack
kubectl get svc -n ingress-nginx

kubectl patch svc keystone -n openstack -p '{"spec":{"type":"LoadBalancer","loadBalancerIP":"10.3.0.35"}}'


kubectl get svc -n openstack -o wide
kubectl get svc -n ingress-nginx -o wide
kubectl get ingress -n openstack
kubectl describe ingress -n openstack


kubectl run -n openstack curl-test --rm -it --image=curlimages/curl -- /bin/sh
# container-д:


kubectl get svc keystone -n openstack -o yaml



# Ingress controller pod эсвэл service-ийг хайх
kubectl get pods --all-namespaces -l app.kubernetes.io/name=ingress-nginx
kubectl get svc --all-namespaces -o wide | grep -i ingress
# эсвэл тодорхой namespace-ийг шалгах (тухайн controller-ийн namespace өөр байж болно)
kubectl get svc -A | grep -E "ingress|nginx"



helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.loadBalancerIP=10.3.0.24
kubectl get svc -n ingress-nginx -o wide




# жагсаалт/засах команд (Linux)
sudo -- sh -c 'echo "10.3.0.24 keystone keystone.openstack" >> /etc/hosts'
# эсвэл curl туршилт
curl -vk http://keystone/v3/



# Ingress resource-ын статус шалгах
kubectl get ingress -n openstack -o wide
kubectl describe ingress keystone -n openstack

# Ingress controller service EXTERNAL-IP-ийг шалгах
kubectl get svc -n <INGRESS_NAMESPACE> -o wide

# keystone API-г гаднаас шалгах (host тохируулсан тохиолдолд)
curl -vk http://keystone/v3/
# эсвэл IP шууд ашиглан (хост header шаардлагатай бол)
curl -vk -H "Host: keystone" http://10.3.0.24/v3/

kubectl delete clusterrole ingress-nginx
kubectl delete clusterrolebinding ingress-nginx  # байвал
kubectl get ingressclass nginx -o yaml
helm list -A | grep -i nginx || true
helm uninstall ingress-nginx -n openstack
kubectl delete ingressclass nginx
kubectl annotate ingressclass nginx meta.helm.sh/release-name=ingress-nginx --overwrite
kubectl annotate ingressclass nginx meta.helm.sh/release-namespace=ingress-nginx --overwrite

kubectl get clusterrole,clusterrolebinding | grep ingress-nginx || true
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.service.loadBalancerIP=10.3.0.24


kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx -o wide
kubectl get ingress -n openstack -o wide

curl -vk -H "Host: keystone" http://10.3.0.24/v3/


sudo -- sh -c 'echo "10.3.0.24 keystone keystone.openstack" >> /etc/hosts'
curl -vk http://keystone/v3/
kubectl run -n openstack curl-test --rm -it --image=curlimages/curl -- /bin/sh
# контейнер дээр:
curl -sS http://keystone-api:5000/v3/

kubectl get pods -n openstack -l application=keystone
kubectl logs -n openstack keystone-api-7c7f94749d-wxp58

# RabbitMQ management интерфэйс шалгах
curl -vk -H "Host: rabbitmq-mgr-7b1733" http://10.3.0.24/
# эсвэл браузераас http://10.3.0.24/ болон Host header тохируулсан виртуал host ашиглан нэвтрэх

# Хэрэв алдаа гарвал түргэн шалгах командууд

kubectl describe ingress keystone -n openstack
kubectl describe svc keystone -n openstack
kubectl logs -n ingress-nginx $(kubectl get pod -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -o name | head -n1)
kubectl get pods -n openstack -o wide


sudo -- sh -c 'echo "10.3.0.24 keystone rabbitmq-mgr-7b1733 keystone.openstack" >> /etc/hosts'