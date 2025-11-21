cat > ~/osh/openstack-helm/roles/deploy-env/defaults/main.yaml << 'EOF'
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
---
kube_version_repo: "v1.32"
# the list of k8s package versions are available here
# https://pkgs.k8s.io/core:/stable:/{{ kube_version_repo }}/deb/Packages
kube_version: "1.32.5-1.1"
helm_version: "v3.18.1"
crictl_version: "v1.33.0"

calico_setup: true
calico_version: "v3.30.1"
calico_manifest_url: "https://raw.githubusercontent.com/projectcalico/calico/{{ calico_version }}/manifests/calico.yaml"

cilium_setup: false
cilium_version: "1.17.4"

flannel_setup: false
flannel_version: v0.26.7

ingress_setup: false
ingress_nginx_version: "4.12.2"
ingress_openstack_setup: true
ingress_ceph_setup: true
ingress_osh_infra_setup: false

kubectl:
  user: zuul
  group: zuul

osh_plugin_repo: "https://opendev.org/openstack/openstack-helm-plugin.git"

kubeadm:
  pod_network_cidr: "10.244.0.0/16"
  service_cidr: "10.96.0.0/16"
docker:
  root_path: /var/lib/docker
docker_users:
  - zuul
containerd:
  root_path: /var/lib/containerd
loopback_setup: false
loopback_device: /dev/loop100
loopback_image: /var/lib/openstack-helm/ceph-loop.img
loopback_image_size: 12G

coredns_resolver_setup: false

metallb_setup: true
metallb_version: "0.14.9"
metallb_pool_cidr: "10.5.0.0/24"
metallb_openstack_endpoint_cidr: "10.5.0.254/24"

client_cluster_ssh_setup: true
client_ssh_user: zuul
cluster_ssh_user: zuul

openstack_provider_gateway_setup: false
openstack_provider_network_cidr: "172.24.4.0/24"
openstack_provider_gateway_cidr: "172.24.4.1/24"

tunnel_network_cidr: "172.24.5.0/24"
tunnel_client_cidr: "172.24.5.2/24"
tunnel_cluster_cidr: "172.24.5.1/24"

dnsmasq_image: "quay.io/airshipit/neutron:2024.2-ubuntu_jammy"
nginx_image: "quay.io/airshipit/nginx:alpine3.18"

overlay_network_setup: true
overlay_network_prefix: "10.248.0."
overlay_network_vxlan_iface: vxlan42
overlay_network_vxlan_id: 42
# NOTE: This is to avoid conflicts with the vxlan overlay managed by Openstack
# which uses 4789 by default. Some alternative implementations used to
# leverage 8472, so let's use it.
overlay_network_vxlan_port: 8472
overlay_network_bridge_name: brvxlan
overlay_network_bridge_ip: "{{ overlay_network_prefix }}{{ (groups['all'] | sort).index(inventory_hostname) + 1 }}"
overlay_network_underlay_dev: "{{ hostvars[inventory_hostname]['ansible_default_ipv4']['interface'] }}"
...
EOF


cat > ~/osh/openstack-helm/roles/deploy-env/tasks/k8s_common.yaml << 'EOF'
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

---


- name: Kubeadm reset
  command: kubeadm reset -f
  ignore_errors: true

- name: Remove old CNI config
  command: sudo rm -rf /etc/cni/net.d
  ignore_errors: true

- name: Remove old kube config
  command: sudo rm -rf $HOME/.kube
  ignore_errors: true

- name: Load necessary modules
  modprobe:
    name: "{{ item }}"
    state: present
  with_items:
    - overlay
    - br_netfilter

- name: Configure sysctl
  sysctl:
    name: "{{ item }}"
    value: "1"
    state: present
  loop:
    - net.ipv6.conf.default.disable_ipv6
    - net.ipv6.conf.all.disable_ipv6
    - net.ipv6.conf.lo.disable_ipv6
    - net.bridge.bridge-nf-call-iptables
    - net.bridge.bridge-nf-call-ip6tables
    - net.ipv4.ip_forward
  ignore_errors: true

# This is necessary when we run dnsmasq.
# Otherwise, we get the error:
# failed to create inotify: Too many open files
- name: Configure number of inotify instances
  sysctl:
    name: "fs.inotify.max_user_instances"
    value: "256"
    state: present
  ignore_errors: true

- name: Configure number of inotify instances
  sysctl:
    name: "{{ item }}"
    value: "0"
    state: present
  loop:
    - net.ipv4.conf.all.rp_filter
    - net.ipv4.conf.default.rp_filter
  ignore_errors: true

- name: Remove swapfile from /etc/fstab
  mount:
    name: "{{ item }}"
    fstype: swap
    state: absent
  with_items:
    - swap
    - none

- name: Disable swap
  command: swapoff -a
  when: ansible_swaptotal_mb > 0

- name: Install Kubernetes binaries
  apt:
    state: present
    update_cache: true
    allow_downgrade: true
    pkg:
      - "kubelet={{ kube_version }}"
      - "kubeadm={{ kube_version }}"
      - "kubectl={{ kube_version }}"

- name: Restart kubelet
  service:
    name: kubelet
    daemon_reload: yes
    state: restarted

- name: Configure resolv.conf
  template:
    src: files/resolv.conf
    dest: /etc/resolv.conf
    owner: root
    group: root
    mode: 0644
  vars:
    nameserver_ip: "8.8.8.8"

- name: Disable systemd-resolved
  service:
    name: systemd-resolved
    enabled: false
    state: stopped
  ignore_errors: true

- name: Disable unbound
  service:
    name: unbound
    enabled: false
    state: stopped
  ignore_errors: true
...
EOF


cat > ~/osh/openstack-helm/roles/deploy-env/tasks/k8s_client.yaml << 'EOF'
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

---
- name: Install Kubectl
  apt:
    state: present
    update_cache: true
    allow_downgrade: true
    pkg:
      - "kubectl={{ kube_version }}"

- name: Set user home directory
  set_fact:
    user_home_directory: /home/{{ kubectl.user }}
  when: kubectl.user != "root"

- name: Set root home directory
  set_fact:
    user_home_directory: /root
  when: kubectl.user == "root"

- name: "Setup kubeconfig directory for {{ kubectl.user }} user"
  shell: |
    mkdir -p {{ user_home_directory }}/.kube

- name: "Copy kube_config file for {{ kubectl.user }} user"
  synchronize:
    src: /tmp/kube_config
    dest: "{{ user_home_directory }}/.kube/config"

- name: "Set kubconfig file ownership for {{ kubectl.user }} user"
  shell: |
    chown -R {{ kubectl.user }}:{{ kubectl.group }} {{ user_home_directory }}/.kube

- name: Deploy Helm
  block:
    - name: Install Helm
      shell: |
        TMP_DIR=$(mktemp -d)
        curl -sSL https://get.helm.sh/helm-{{ helm_version }}-linux-amd64.tar.gz | tar -zxv --strip-components=1 -C ${TMP_DIR}
        mv "${TMP_DIR}"/helm /usr/local/bin/helm
        rm -rf "${TMP_DIR}"
      args:
        executable: /bin/bash


        

    - name: Uninstall osh helm plugin
      become_user: "{{ kubectl.user }}"
      shell: |
        helm plugin uninstall osh
      ignore_errors: true




    - name: Install osh helm plugin
      become_user: "{{ kubectl.user }}"
      shell: |
        helm plugin install {{ osh_plugin_repo }}
      ignore_errors: true

    # This is to improve build time
    - name: Remove stable Helm repo
      become_user: "{{ kubectl.user }}"
      command: helm repo remove stable
      ignore_errors: true
...
EOF

cat > ~/osh/openstack-helm/roles/deploy-env/tasks/coredns_resolver.yaml << 'EOF'
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

---
- name: Enable recursive queries for coredns
  become: false
  shell: |
    tee > /tmp/coredns_configmap.yaml <<EOF
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: coredns
      namespace: kube-system
    data:
      Corefile: |
        .:53 {
            errors
            health {
              lameduck 5s
            }
            header {
                response set ra
            }
            ready
            kubernetes cluster.local in-addr.arpa ip6.arpa {
              pods insecure
              fallthrough in-addr.arpa ip6.arpa
              ttl 30
            }
            prometheus :9153
            forward . 8.8.8.8 {
              max_concurrent 1000
            }
            cache 30
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
    EOF
    kubectl apply -f /tmp/coredns_configmap.yaml
    kubectl rollout restart -n kube-system deployment/coredns
    kubectl rollout status -n kube-system deployment/coredns
  when: inventory_hostname in (groups['primary'] | default([]))

- name: Give coredns time to restart
  pause:
    seconds: 30
  when: inventory_hostname in (groups['primary'] | default([]))

- name: Get coredns rollout restart status
  become: false
  shell: |
    kubectl rollout status -n kube-system deployment/coredns
  when: inventory_hostname in (groups['primary'] | default([]))

- name: Use coredns as default DNS resolver
  copy:
    src: files/cluster_resolv.conf
    dest: /etc/resolv.conf
    owner: root
    group: root
    mode: 0644
  when: inventory_hostname in (groups['k8s_cluster'] | default([]))
...
EOF



