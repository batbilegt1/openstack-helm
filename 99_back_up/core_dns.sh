

kubectl get configmap coredns -n kube-system  -o yaml > coredns_config.yaml
kubectl edit configmap coredns -n kube-system
kubectl rollout restart deployment  coredns -n kube-system
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
           10.4.0.33 rabbitmq
           10.4.0.36 metadata
           10.4.0.35 keystone-api
           10.4.0.38 keystone
           10.4.0.39 glance-api glance
           10.4.0.40 neutron-server neutron
           10.4.0.41 cinder-api cinder
           10.3.0.18 ceph-mon
           fallthrough
        }
        loop
        reload
        loadbalance
    }
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
EOF
kubectl edit configmap coredns -n kube-system
kubectl rollout restart deployment  coredns -n kube-system

kubectl -n kube-system rollout restart deployment coredns
kubectl -n kube-system rollout status deployment coredns
kubectl logs -n kube-system -l k8s-app=kube-dns -f