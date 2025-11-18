sudo su
mkdir ~/osh
cd ~/osh
git clone https://opendev.org/openstack/openstack-helm.git
git clone https://opendev.org/zuul/zuul-jobs.git

sudo apt install python3-pip -y
sudo apt install ansible -y
ssh-keygen -t rsa -N "" -f /home/ubuntu/.ssh/id_rsa
ssh-copy-id -i /home/ubuntu/.ssh/id_rsa.pub ubuntu@10.10.0.14
ssh-copy-id -i /home/ubuntu/.ssh/id_rsa.pub ubuntu@10.10.0.15
ssh-copy-id -i /home/ubuntu/.ssh/id_rsa.pub ubuntu@10.10.0.16
ssh-copy-id -i /home/ubuntu/.ssh/id_rsa.pub ubuntu@10.10.0.17
ssh-copy-id -i /home/ubuntu/.ssh/id_rsa.pub ubuntu@10.10.0.18
cat > ~/osh/inventory.yaml <<EOF
---
all:
  vars:
    ansible_port: 707
    ansible_user: ubuntu
    ansible_ssh_private_key_file: "/home/ubuntu/.ssh/id_rsa"
    ansible_ssh_extra_args: -o StrictHostKeyChecking=no
    # cilium_setup: false
    ingress_openstack_setup: false
    ingress_ceph_setup: false
    loopback_setup: false
    metallb_setup: false
    calico_setup: true
    overlay_network_setup: true
    kubectl:
      user: ubuntu
      group: ubuntu
    docker_users:
      - ubuntu
    client_ssh_user: ubuntu
    cluster_ssh_user: ubuntu
    metallb_setup: true
  children:
    k8s_control_plane:
      hosts:
        control-plane:
          ansible_host: 10.10.0.14
          overlay_network_underlay_dev: "enp3s0"
          overlay_network_underlay_ip: "10.3.0.14"
          overlay_network_underlay_ip_with_prefix: "10.3.0.14/24"
    k8s_nodes:
      hosts:
        worker-node-1:
          ansible_host: 10.10.0.15
          overlay_network_underlay_dev: "enp3s0"
          overlay_network_underlay_ip: "10.3.0.15"
          overlay_network_underlay_ip_with_prefix: "10.3.0.15/24"
        worker-node-2:
          ansible_host: 10.10.0.16
          overlay_network_underlay_dev: "enp3s0"
          overlay_network_underlay_ip: "10.3.0.16"
          overlay_network_underlay_ip_with_prefix: "10.3.0.16/24"
        worker-node-3:
          ansible_host: 10.10.0.17
          overlay_network_underlay_dev: "enp3s0"
          overlay_network_underlay_ip: "10.3.0.17"
          overlay_network_underlay_ip_with_prefix: "10.3.0.17/24"

    k8s_cluster:
      children:
        k8s_control_plane:
        k8s_nodes:
    
    primary:
      hosts:
        control-plane:
EOF
cat > ~/osh/deploy-env.yaml <<EOF
---
- hosts: all
  become: true
  gather_facts: true
  roles:
    - ensure-python
    - ensure-pip
    - clear-firewall
    # - deploy-env
EOF
export ANSIBLE_ROLES_PATH=~/osh/openstack-helm/roles:~/osh/zuul-jobs/roles
ansible-playbook -i inventory.yaml deploy-env.yaml

cat > ~/osh/deploy-env.yaml <<EOF
---
- hosts: all
  become: true
  gather_facts: true
  roles:
    - deploy-env
EOF

export ANSIBLE_ROLES_PATH=~/osh/openstack-helm/roles:~/osh/zuul-jobs/roles
ansible-playbook -i inventory.yaml deploy-env.yaml
ansible-playbook -i inventory.yaml deploy-env.yaml --start-at-task 'Include Metallb tasks'
cat > ~/osh/pre_task.yaml <<EOF
---
- hosts: all
  become: true
  gather_facts: true
  tasks:
    - name: create /etc/containerd folder
      file:
        path: /etc/containerd
        state: directory
        owner: root
        group: root
        mode: 0700
      ignore_errors: true
    - name: generate default containerd config
      command: containerd config default
      register: containerd_default_config
      ignore_errors: true
    - name: write default containerd config to /etc/containerd/config.toml
      copy:
        content: "{{ containerd_default_config.stdout }}"
        dest: /etc/containerd/config.toml
        owner: root
        group: root
        mode: 0644
      ignore_errors: true
    - name: set SystemdCgroup to true in /etc/containerd/config.toml
      replace:
        path: /etc/containerd/config.toml
        regexp: '^(.*SystemdCgroup\s*=\s*).*'
        replace: '\1true'
      ignore_errors: true
    - name: restart containerd
      service:
        name: containerd
        state: restarted
      ignore_errors: true
    - name: enable containerd
      service:
        name: containerd
        enabled: true
      ignore_errors: true
EOF

ansible-playbook -i inventory.yaml pre_task.yaml



cat > ~/osh/openstack-helm/roles/deploy-env/tasks/overlay.yaml <<EOF
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
- name: Down and delete brvxlan, vxlan42 interfaces
  shell: |
    ip link set dev {{ overlay_network_bridge_name }} down
    ip link set dev {{ overlay_network_vxlan_iface }} down
    ip link delete {{ overlay_network_vxlan_iface }}
    ip link delete {{ overlay_network_bridge_name }}
  ignore_errors: true

- name: Create vxlan bridge
  shell: |
    ip link add name {{ overlay_network_bridge_name }} type bridge
    ip link set dev {{ overlay_network_bridge_name }} up
    ip addr add {{ overlay_network_bridge_ip }}/24 dev {{ overlay_network_bridge_name }}
  args:
    creates: "/sys/class/net/{{ overlay_network_bridge_name }}"

- name: Create vxlan interface
  shell: |
    ip link add {{ overlay_network_vxlan_iface }} \
      type vxlan \
      id {{ overlay_network_vxlan_id }} \
      dev {{ overlay_network_underlay_dev }} \
      dstport {{ overlay_network_vxlan_port }} \
      local {{ hostvars[inventory_hostname]['ansible_default_ipv4']['address'] }}
    ip link set {{ overlay_network_vxlan_iface }} up
    ip link set {{ overlay_network_vxlan_iface }} master {{ overlay_network_bridge_name }}
  args:
    creates: "/sys/class/net/{{ overlay_network_vxlan_iface }}"

- name: Populate FDB
  shell: |
    bridge fdb append 00:00:00:00:00:00 \
      dev {{ overlay_network_vxlan_iface }} \
      dst {{ hostvars[item]['ansible_host'] }}
  loop: "{{ groups['all'] | sort }}"
  when: item != inventory_hostname
...
EOF




cat > ~/osh/openstack-helm/roles/deploy-env/tasks/k8s_common.yaml <<EOF
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
  command: sudo rm -rf \$HOME/.kube
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

cat > ~/osh/openstack-helm/roles/deploy-env/tasks/k8s_client.yaml <<EOF
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
        TMP_DIR=\$(mktemp -d)
        curl -sSL https://get.helm.sh/helm-{{ helm_version }}-linux-amd64.tar.gz | tar -zxv --strip-components=1 -C \${TMP_DIR}
        mv "\${TMP_DIR}"/helm /usr/local/bin/helm
        rm -rf "\${TMP_DIR}"
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