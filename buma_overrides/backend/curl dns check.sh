cat <<EOF | kubectl -n openstack apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: dns-debug
  labels:
    app: dns-debug
spec:
  restartPolicy: Never
  containers:
  - name: dnstools
    image: infoblox/dnstools:latest
    command: ["sleep","36000"]
  - name: curl-debug
    image: curlimages/curl:latest
    command: ["sleep","36000"]
  - name: netcat-debug
    image: appropriate/nc:latest
    command: ["sleep","36000"]
EOF
kubectl delete po dns-debug curl-debug --ignore-not-found -n openstack 
kubectl -n openstack exec -it dns-debug -- nc -vz rabbitmq 5672 || true
kubectl -n openstack exec -it dns-debug -- nc -vz mariadb 3306 || true
kubectl -n openstack exec -it dns-debug -- nc -vz keystone-api 5000 || true
kubectl -n openstack exec -it dns-debug -- nc -vz keystone 5000 || true
kubectl -n openstack exec -it dns-debug -- nc -vz keystone 80 || true
kubectl -n openstack exec -it dns-debug -- nc -vz placement-api 8778 || true
kubectl -n openstack exec -it dns-debug -- curl http://placement-api:8778 || true

kubectl -n openstack exec -it dns-debug -- dig @10.96.0.10 glance-api
kubectl -n openstack exec -it dns-debug -- curl http://glance:9292 || true
kubectl -n openstack exec -it dns-debug -- curl http://glance-api:9292 || true
curl http://10.3.0.39:9292
curl http://glance-api:9292
# check neuteron server connection
kubectl -n openstack exec -it dns-debug -- nc -vz neutron-server 9696 || true
kubectl -n openstack exec -it dns-debug -- curl http://neutron-server/v2.0:9696 || true
kubectl -n openstack exec -it dns-debug -- curl http://10.3.0.40:9696 || true
curl http://10.3.0.40:9696
curl http://neutron-server:9696
kubectl -n openstack exec -it dns-debug -- dig @10.96.0.10 neutron-server

kubectl -n openstack exec -it dns-debug -- nc -vz placement-api 8778 || true

kubectl -n openstack exec -it dns-debug -- curl -sS http://keystone-api:5000/v3/  | jq .
kubectl -n openstack exec -it check-openstack -- openstack token issue -f value -c id

kubectl -n openstack run curl-debug --image=curlimages/curl:latest --restart=Never -- sleep 3600
kubectl -n openstack exec -it dns-debug -- cat /etc/resolv.conf
kubectl -n openstack exec -it dns-debug -- dig @10.96.0.10 kubernetes.default.svc.cluster.local
kubectl -n openstack exec -it dns-debug -- dig @10.96.0.10 placement-api
kubectl -n openstack exec -it dns-debug -- curl http://10.3.0.37:8778
kubectl -n openstack exec -it dns-debug -- dig @10.96.0.10 google.com
kubectl -n openstack exec -it dns-debug -- dig @10.96.0.10 mariadb.openstack.svc.cluster.local
kubectl -n openstack exec -it dns-debug -- dig @10.96.0.10 rabbitmq.openstack.svc.cluster.local
kubectl -n openstack exec -it dns-debug -- dig @10.96.0.10 rabbitmq
kubectl -n openstack exec -it dns-debug -- dig @10.96.0.10 rabbitmq.openstack.svc.cluster.ctr
kubectl -n openstack exec -it dns-debug -- dig @10.96.0.10 keystone.openstack.svc.cluster.ctr
kubectl -n openstack exec -it dns-debug -- dig @10.96.0.10 keystone-api
kubectl -n openstack exec -it dns-debug -- dig @10.96.0.10 mariadb
kubectl -n openstack exec -it dns-debug -- dig @10.96.0.10 keystone.openstack.svc.cluster.local
kubectl -n openstack exec -it curl-debug -- cat /etc/resolv.conf
kubectl -n openstack exec -it dns-debug -- dig +short kubernetes.default.svc.cluster.local
kubectl -n openstack exec -it dns-debug -- nslookup kubernetes.default
kubectl -n openstack exec -it curl-debug -- getent hosts kubernetes.default || true
kubectl -n openstack exec -it curl-debug -- curl -k --max-time 5 https://kubernetes.default:443/ -I || true
kubectl -n openstack exec -it curl-debug -- nc -vz kubernetes.default 443 || true
kubectl -n openstack delete pod dns-debug curl-debug --ignore-not-found
