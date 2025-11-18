cat > ~/overrides/horizon/horizon.yaml << 'EOF'
---
labels:
  dashboard:
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
    db_init: quay.io/airshipit/heat:2025.1-ubuntu_noble
    db_drop: quay.io/airshipit/heat:2025.1-ubuntu_noble
    horizon_db_sync: quay.io/airshipit/horizon:2025.1-ubuntu_noble
    horizon: quay.io/airshipit/horizon:2025.1-ubuntu_noble
endpoints:
  cluster_domain_suffix: cluster.local
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
    hosts:
      default: keystone
      internal: keystone-api
    host_fqdn_override:
      default: keystone
      internal: keystone-api
    path:
      default: /v3
    scheme:
      default: http
    port:
      api:
        default: 80
        internal: 5000
  oslo_db:
    auth:
      admin:
        username: root
        password: mariadbRootPass
        secret:
          tls:
            internal: mariadb-tls-direct
      horizon:
        username: horizon
        password: horizonDBPass
    hosts:
      default: mariadb
    host_fqdn_override:
      default: null
    path: /horizon
    scheme: mysql+pymysql
    port:
      mysql:
        default: 3306
...
EOF
helm uninstall horizon -n openstack || true
kubectl delete pvc -n openstack -l application=horizon
kubectl delete pod -n openstack -l application=horizon
kubectl delete job -n openstack -l application=horizon
kubectl delete cronjob -n openstack -l application=horizon
kubectl delete secret -n openstack -l application=horizon
helm upgrade --install horizon openstack-helm/horizon \
    --namespace=openstack \
    --values ~/overrides/horizon/horizon.yaml
    
cat > horizon_external.yaml << 'EOF'
---
apiVersion: v1
kind: Service
metadata:
  annotations:
    meta.helm.sh/release-name: horizon
    meta.helm.sh/release-namespace: openstack
    metallb.universe.tf/address-pool: public
  name: horizon
  namespace: openstack
spec:
  loadBalancerIP: 10.3.0.45
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
  type: LoadBalancer
EOF

kubectl apply -f horizon_external.yaml
curl http://10.3.0.45/v3/

curl http://horizon/
kubectl get svc horizon -n openstack

























