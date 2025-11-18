helm uninstall mariadb -n openstack
kubectl delete pvc -n openstack -l application=mariadb
kubectl delete pv -n openstack -l application=mariadb
kubectl delete job -n openstack -l application=mariadb
# force delete mariadb pods if stuck
kubectl delete pod -n openstack -l application=mariadb --force --grace-period=0
kubectl delete pod -n openstack -l application=mariadb
kubectl delete pod -n openstack -l application=mariadb
kubectl delete cronjob -n openstack -l application=mariadb
kubectl delete secret -n openstack -l application=mariadb
 kubectl delete configmap -n openstack mariadb-mariadb-state


kubectl delete pv pvc-1a66a62d-2659-4067-a7f7-7cff0358c83f --ignore-not-found --force --grace-period=0
kubectl delete pv pvc-49a211a4-931d-4565-94f5-683d59960ee1 --ignore-not-found --force --grace-period=0
kubectl delete pv pvc-5bef9db0-8de9-451a-b321-928011ae8e9f --ignore-not-found --force --grace-period=0
kubectl delete pv pvc-68fb7614-5dbf-4a4a-af1b-82e7562b31db --ignore-not-found --force --grace-period=0
kubectl delete pv pvc-87539980-4a99-4a51-835b-e91c7ce81033 --ignore-not-found --force --grace-period=0
kubectl delete pv pvc-a17482eb-fc5e-4b26-aaaf-5a5b654440c6 --ignore-not-found --force --grace-period=0
kubectl delete pv pvc-b07f92a3-ad61-40ee-a684-a9ab2d6a0859 --ignore-not-found --force --grace-period=0
kubectl delete pv pvc-c128136c-636a-4318-b8d6-0beb5709ceec --ignore-not-found --force --grace-period=0
kubectl delete pv pvc-e34b9ecd-68b2-4f6a-9264-6daf18e40124 --ignore-not-found --force --grace-period=0











kubectl get pods -n openstack -l component=mariadb
kubectl describe pod -n openstack <mariadb-pod>
kubectl logs -n openstack -l application=mariadb -f
kubectl get svc mariadb -n openstack -o wide
kubectl run -n openstack db-test --rm -it --image=mysql:8 -- mysql -h mariadb -u openstack -p'mariadbRootPass' -e "SHOW DATABASES;"
kubectl run -n openstack db-test --rm -it --image=mysql:8 -- mysql -h mariadb -u openstack -p'mariadbRootPass' -e "SHOW DATABASES;"
kubectl exec -n openstack db-test -- mysql -h mariadb -u
kubectl describe po -n openstack mariadb-server-0
kubectl logs -n openstack mariadb-server-0 -c mariadb
helm uninstall mariadb -n openstack
helm delete mariadb --namespace openstack
kubectl delete pvc -n openstack -l application=mariadb

# force uninstall mariadb deploymernt if stuck
# Бүх гацсан mariadb pod-уудыг устгах
kubectl delete pod mariadb-server-0 -n openstack --force --grace-period=0
kubectl delete pod mariadb-server-1 -n openstack --force --grace-period=0
kubectl delete pod mariadb-server-2 -n openstack --force --grace-period=0

# Эсвэл нэгийг нь устгах
# kubectl delete po <pod-ийн нэр> -n <namespace> --force --grace-period=0
kubectl delete deployment mariadb -n openstack --force --grace-period=0
kubectl get statefulset -n openstack
kubectl edit pv pvc-2ba9697e-12db-4094-b8b4-7babd29e6966
kubectl edit pv pvc-80a3ad2f-1bd7-40ce-8461-0d01fb7c0377
kubectl edit pv pvc-84955b48-9946-4d5b-9293-7c233d8fedaf
kubectl get storageclass general -o yaml
kubectl wait --for=condition=Ready pods -l application=mariadb -n openstack --timeout=600s








kubectl get svc -n openstack | grep -E "mariadb|rabbitmq|keystone|heat"
kubectl get pods -n openstack | grep -E "mariadb|rabbitmq|keystone|heat"
kubectl get sc

ubuntu@ctr-m1:~$ kubectl get sc

NAME      PROVISIONER        RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
general   rbd.csi.ceph.com   Delete          Immediate           true                   5h44m
ubuntu@ctr-m1:~$ 



cat > ~/osh/overrides/mariadb/mariadb.yaml << 'EOF'
---
labels:
  server:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
  prometheus_mysql_exporter:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
  job:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
  test:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
  controller:
    node_selector_key: openstack-control-plane
    node_selector_value: enabled
images:
  tags:
    prometheus_mysql_exporter_helm_tests: quay.io/airshipit/heat:2025.1-ubuntu_noble
    ks_user: quay.io/airshipit/heat:2025.1-ubuntu_noble
endpoints:
  oslo_db:
    namespace: null
    auth:
      admin:
        username: root
        password: mariadbRootPass
      sst:
        username: sst
        password: mariadbRootPass
      audit:
        username: audit
        password: mariadbRootPass
      exporter:
        username: exporter
        password: mariadbRootPass
    hosts:
      default: mariadb
      direct: mariadb-server
      discovery: mariadb-discovery
    host_fqdn_override:
      default: null
    path: null
    scheme: mysql+pymysql
    port:
      mysql:
        default: 3306
      wsrep:
        default: 4567
      ist:
        default: 4568
      sst:
        default: 4444
  identity:
    name: backup-storage-auth
    namespace: openstack
    auth:
      admin:
        # Auth URL of null indicates local authentication
        # HTK will form the URL unless specified here
        auth_url: null
        region_name: RegionOne
        username: admin
        password: KeystoneAdminPass
        project_name: admin
        user_domain_name: default
        project_domain_name: default
      mariadb:
        # Auth URL of null indicates local authentication
        # HTK will form the URL unless specified here
        auth_url: null
        role: admin
        region_name: RegionOne
        username: mariadb-backup-user
        password: password
        project_name: service
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
...
EOF




helm repo add openstack-helm https://opendev.org/openstack/openstack-helm/
helm repo add openstack-helm https://tarballs.opendev.org/openstack/openstack-helm/
helm repo update
helm upgrade --install mariadb openstack-helm/mariadb \
    --namespace=openstack \
    --set pod.replicas.server=1 \
    --values ~/osh/overrides/mariadb/mariadb.yaml


cat > ~/mariadb-loadbalancer.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: mariadb-external
  namespace: openstack
  annotations:
    metallb.universe.tf/address-pool: public
spec:
  type: LoadBalancer
  loadBalancerIP: 10.4.0.34
  selector:
    application: mariadb
    component: server
  ports:
    - name: mysql
      port: 3306
      protocol: TCP
      targetPort: 3306
  sessionAffinity: ClientIP
EOF

kubectl apply -f ~/mariadb-loadbalancer.yaml

kubectl get svc mariadb-external -n openstack


nc -zv 10.3.0.34 3306






cat << EOF | kubectl -n openstack apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: db-test
spec:
  containers:
  - name: mysql
    image: mysql:8.0
    command: ["sleep", "3600"]
EOF


kubectl exec -n openstack db-test -- mysql -h mariadb -u openstack -p'mariadbRootPass' -e "SHOW DATABASES;"
kubectl exec -n openstack db-test -- mysql -h mariadb -u root -p'mariadbRootPass' -e "SHOW DATABASES;"
kubectl exec -n openstack db-test -- mysql -h mariadb -u root -p'mariadbRootPass' -e "SHOW DATABASES;"
kubectl exec -n openstack db-test -- mysql -h mariadb -u keystone -p'password' -e "SHOW DATABASES;"
kubectl exec -n openstack db-test -- mysql -h mariadb -u root -p'mariadbRootPass' -e "select * from keystone;"
kubectl exec -n openstack -it db-test -- mysql -h mariadb -u root -p'mariadbRootPass'
select user, host from mysql.user;

# | cinder      | %         |
# | glance      | %         |
# | heat        | %         |
# | keystone    | %         |
# | neutron     | %         |
# | nova        | %         |
# | openstack   | %         |
# | placement   | %         |
drop user 'openstack'@'%';
drop user 'keystone'@'%';
drop database keystone;












