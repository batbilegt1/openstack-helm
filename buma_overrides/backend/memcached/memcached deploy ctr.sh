helm upgrade --install memcached openstack-helm/memcached \
    --namespace=openstack



helm upgrade --install memcached openstack-helm/memcached \
  --namespace openstack \
  --create-namespace \
  -f ~/overrides/memcached/memcached.yaml \
  --values ~/overrides/mariadb/2025.1-ubuntu_noble.yaml
  helm osh wait-for-pods openstack
helm delete memcached -n openstack
kubectl get pvc -n openstack -l application=memcached
kubectl run -n openstack memcached-test --rm -it --image=busybox -- /bin/sh
# container дээр:
telnet memcached 11211
# эсвэл nc -vz memcached 11211


