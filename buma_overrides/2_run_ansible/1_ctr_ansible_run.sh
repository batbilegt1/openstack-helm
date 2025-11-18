
mkdir ~/osh
cd ~/osh
git clone https://opendev.org/openstack/openstack-helm.git
git clone https://opendev.org/zuul/zuul-jobs.git

sudo apt install python3-pip -y
sudo apt install ansible -y
ssh-keygen -t rsa -N "" -f /home/ubuntu/.ssh/id_rsa
ssh-copy-id -i /home/ubuntu/.ssh/id_rsa.pub ubuntu@10.10.0.10
ssh-copy-id -i /home/ubuntu/.ssh/id_rsa.pub ubuntu@10.10.0.11
ssh-copy-id -i /home/ubuntu/.ssh/id_rsa.pub ubuntu@10.10.0.12
ssh-copy-id -i /home/ubuntu/.ssh/id_rsa.pub ubuntu@10.10.0.13
cat > ~/osh/inventory.yaml <<EOF
---
all:
  vars:
    ansible_port: 22
    ansible_user: ubuntu
    ansible_ssh_private_key_file: "/home/ubuntu/.ssh/id_rsa"
    ansible_ssh_extra_args: -o StrictHostKeyChecking=no
    # cilium_setup: false
    ingress_openstack_setup: false
    ingress_ceph_setup: false
    loopback_setup: false
    metallb_setup: true
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
          ansible_host: 10.10.0.10
          overlay_network_underlay_dev: "enp3s0"
          overlay_network_underlay_ip: "10.3.0.10"
          overlay_network_underlay_ip_with_prefix: "10.3.0.10/24"
    k8s_nodes:
      hosts:
        worker-node-1:
          ansible_host: 10.10.0.11
          overlay_network_underlay_dev: "enp3s0"
          overlay_network_underlay_ip: "10.3.0.11"
          overlay_network_underlay_ip_with_prefix: "10.3.0.11/24"
        worker-node-2:
          ansible_host: 10.10.0.12
          overlay_network_underlay_dev: "enp3s0"
          overlay_network_underlay_ip: "10.3.0.12"
          overlay_network_underlay_ip_with_prefix: "10.3.0.12/24"
        worker-node-3:
          ansible_host: 10.10.0.13
          overlay_network_underlay_dev: "enp3s0"
          overlay_network_underlay_ip: "10.3.0.13"
          overlay_network_underlay_ip_with_prefix: "10.3.0.13/24"

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

# Ajillaj baih yavtsad
# kubectl edit configmap calico-config -n kube-system
# deer veth_mtu=1450 bolgo

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
