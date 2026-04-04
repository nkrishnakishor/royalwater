#!/bin/bash
set -euxo pipefail

# ── Variables from Terraform ──────────────────────────────────────────────────
K8S_VERSION="${k8s_version}"
CLUSTER_NAME="${cluster_name}"
WORKER_INDEX="${worker_index}"
WORKER_PRIVATE_IP="${worker_private_ip}"
FIRST_MASTER_IP="${first_master_ip}"

# ── System Setup ──────────────────────────────────────────────────────────────
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release socat conntrack ipvsadm

# Disable swap
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Load kernel modules
cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Set sysctl params
cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
net.ipv4.conf.all.rp_filter         = 0
EOF

sysctl --system

# ── Install containerd ────────────────────────────────────────────────────────
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y containerd.io

# Configure containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# ── Install kubeadm, kubelet, kubectl ─────────────────────────────────────────
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v$${K8S_VERSION%.*}/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$${K8S_VERSION%.*}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet="$K8S_VERSION-*" kubeadm="$K8S_VERSION-*" kubectl="$K8S_VERSION-*"
apt-mark hold kubelet kubeadm kubectl

systemctl enable kubelet

# ── Configure crictl ──────────────────────────────────────────────────────────
cat > /etc/crictl.yaml <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
EOF

# ── Wait for master and join cluster ──────────────────────────────────────────
echo "Waiting for master node to be ready..."
until curl -sk https://$FIRST_MASTER_IP:6443/healthz 2>/dev/null; do
  echo "Master not ready yet, waiting..."
  sleep 15
done

# Additional wait for join command to be generated
sleep 60

# Fetch join command from master (via SSM parameter or shared storage)
# For now, we use a pre-shared join command approach
# The join command will be executed via Terraform remote-exec provisioner

echo "Worker node $WORKER_INDEX bootstrap complete, ready to join cluster" > /var/log/k8s-worker-setup.log
touch /var/lib/k8s-worker-ready
</write_to_file>
<task_progress>
- [x] Review existing Terraform modules structure
- [x] Analyze current infrastructure code
- [x] Design new Debian + Kubernetes module architecture
- [x] Confirm module structure and paths
- [x] Create user-data templates
- [ ] Create terraform/modules/k8s-debian/ module files (main.tf, variables.tf, outputs.tf)
- [ ] Create terraform-k8s-debian/ root files
- [ ] Create terraform.tfvars
</task_progress>
</write_to_file>