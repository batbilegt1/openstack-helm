kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: osc-client
  namespace: openstack
  labels:
    app: osc-client
    application: openstack
    component: client
spec:
  restartPolicy: Never
  containers:
  - name: client
    image: python:3.11-slim
    command: ["bash","-c","sleep 7200"]
    resources: {}
EOF

kubectl wait -n openstack pod/osc-client --for=condition=Ready --timeout=120s
kubectl exec -n openstack -it osc-client -- bash

apt update
apt install -y python3-venv python3-pip
python3 -m venv /venv
source /venv/bin/activate
pip install python-openstackclient
export OS_AUTH_URL=http://keystone-api.openstack.svc.cluster.local:5000/v3
export OS_USERNAME=admin
export OS_PASSWORD=KeystoneAdminPass
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_REGION_NAME=RegionOne
export OS_INTERFACE=public
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
openstack token issue

export OS_IMAGE_ENDPOINT=http://glance-api.openstack.svc.cluster.local:9292
export OS_VOLUME_ENDPOINT=http://cinder-api.openstack.svc.cluster.local:8776/v3

openstack image list
openstack volume list

apt install -y wget

wget -q https://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img
openstack image create test-cirros --disk-format qcow2 --container-format bare --file cirros-0.6.2-x86_64-disk.img --public
openstack image list | grep test-cirros

openstack volume create --size 1 test-rbd-vol
openstack volume list | grep test-rbd-vol
openstack volume show test-rbd-vol -f yaml

rbd ls images
rbd ls cinder.volumes