kubectl get IPAddressPools -A
tee > /tmp/metallb_ipaddresspool.yaml <<EOF
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
    name: pool-ctr
    namespace: metallb-system
spec:
    addresses:
    - 10.3.0.21-10.3.0.40
EOF

kubectl apply -f /tmp/metallb_ipaddresspool.yaml

tee > /tmp/metallb_l2advertisement.yaml <<EOF
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
    name: pool-ctr
    namespace: metallb-system
spec:
    ipAddressPools:
    - pool-ctr
EOF

tee > /tmp/metallb_l2advertisement.yaml <<EOF
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
    name: public
    namespace: metallb-system
spec:
    ipAddressPools:
    - public
EOF
kubectl apply -f /tmp/metallb_l2advertisement.yaml
kubectl get IPAddressPools -A
kubectl get L2Advertisements -A
ip route add 10.3.0.32/28 via 10.3.0.4 dev ens85f1
ip route del 10.3.0.32/28 dev ens85f1











# MetalLB controller ажиллаж байгаа эсэх
kubectl get pods -n metallb-system
kubectl logs -n metallb-system -l app=metallb,component=controller --tail=50

# IP хуваарилалт
kubectl get svc -A | grep LoadBalancer




# loadblancer on az

kubectl get IPAddressPools -A
tee > /tmp/metallb_ipaddresspool.yaml <<EOF
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
    name: pool-az
    namespace: metallb-system
spec:
    addresses:
    - 10.3.0.41-10.3.0.60
EOF

kubectl apply -f /tmp/metallb_ipaddresspool.yaml

tee > /tmp/metallb_l2advertisement.yaml <<EOF
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
    name: pool-az
    namespace: metallb-system
spec:
    ipAddressPools:
    - pool-az
EOF

kubectl apply -f /tmp/metallb_l2advertisement.yaml
kubectl get IPAddressPools -A
kubectl get L2Advertisements -A
