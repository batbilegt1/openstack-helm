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

helm upgrade --install horizon openstack-helm/horizon \
    --namespace=openstack \
    --values ~/overrides/horizon/horizon.yaml

sudo apt install nginx
sudo nano /etc/nginx/sites-enabled/default

server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html index.htm;

    server_name _;

    location / {
        # Use the horizon internal service IP
        proxy_pass http://10.244.176.182:80;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
        
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}

sudo nginx -t
sudo systemctl reload nginx
sudo systemctl status nginx

http://10.3.0.10/

helm uninstall horizon -n openstack || true
kubectl delete pvc -n openstack -l application=horizon
kubectl delete pod -n openstack -l application=horizon
kubectl delete job -n openstack -l application=horizon
kubectl delete cronjob -n openstack -l application=horizon
kubectl delete secret -n openstack -l application=horizon
    
cat > horizon_external.yaml << 'EOF'
---
apiVersion: v1
kind: Service
metadata:
  name: horizon
  namespace: openstack
  annotations:
    metallb.universe.tf/address-pool: default   # ← matches your current config
    # (optional) metallb.universe.tf/loadbalancerIPs: 10.4.0.200
  labels:
    app: horizon
spec:
  type: LoadBalancer
  loadBalancerIP: 10.4.0.200          # ← safe, unused IP in your real working range
  ports:
  - name: http
    port: 80
    targetPort: 80
    protocol: TCP
  - name: https
    port: 443
    targetPort: 443
    protocol: TCP
  selector:
    app: ingress-api                  # ← make sure this selector actually matches your horizon pod!
  externalTrafficPolicy: Local
EOF

kubectl apply -f horizon_external.yaml
curl http://10.3.0.45/v3/

curl -L --resolve horizon:80:10.4.0.254 http://horizon/
kubectl get svc horizon -n openstack


















