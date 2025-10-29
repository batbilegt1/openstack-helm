# --- Environment variables ---
export OPENSTACK_RELEASE=2025.1
export FEATURES="${OPENSTACK_RELEASE} ubuntu_noble"
export OVERRIDES_DIR=$(pwd)/overrides

# --- Use your own GitHub repo for overrides ---
OVERRIDES_URL=https://raw.githubusercontent.com/batbilegt1/openstack-helm/main/overrides

# --- Download overrides for all charts ---
for chart in rabbitmq mariadb memcached openvswitch libvirt keystone heat glance cinder placement nova neutron horizon; do
    helm osh get-values-overrides -d -u ${OVERRIDES_URL} -p ${OVERRIDES_DIR} -c ${chart} ${FEATURES}
done

# --- Deploy RabbitMQ ---
helm upgrade --install rabbitmq openstack-helm/rabbitmq \
    --namespace=openstack \
    --set pod.replicas.server=1 \
    --timeout=600s \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c rabbitmq ${FEATURES})

# --- Deploy MariaDB ---
helm upgrade --install mariadb openstack-helm/mariadb \
    --namespace=openstack \
    --set pod.replicas.server=1 \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c mariadb ${FEATURES})

# --- Deploy Memcached ---
helm upgrade --install memcached openstack-helm/memcached \
    --namespace=openstack \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c memcached ${FEATURES})

# --- Deploy Keystone ---
helm upgrade --install keystone openstack-helm/keystone \
    --namespace=openstack \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c keystone ${FEATURES})

# --- Deploy Heat ---
helm upgrade --install heat openstack-helm/heat \
    --namespace=openstack \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c heat ${FEATURES})

# --- Deploy Glance (with Ceph) ---
helm upgrade --install glance openstack-helm/glance \
  --namespace openstack \
  --values overrides/glance/2025.1-ubuntu_noble.yaml \
  --values overrides/glance/glance_ceph.yaml

# --- Deploy Cinder (with Ceph) ---
helm upgrade --install cinder openstack-helm/cinder \
  --namespace openstack \
  --values overrides/cinder/2025.1-ubuntu_noble.yaml \
  --values overrides/cinder/cinder_ceph.yaml
