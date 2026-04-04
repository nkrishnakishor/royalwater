#!/bin/bash
set -euxo pipefail

# ── Variables from Terraform ──────────────────────────────────────────────────
K8S_VERSION="${k8s_version}"
POD_CIDR="${pod_cidr}"
SERVICE_CIDR="${service_cidr}"
CLUSTER_NAME="${cluster_name}"
MASTER_INDEX="${master_index}"
MASTER_PRIVATE_IP="${master_private_ip}"
ALL_MASTER_IPS="${all_master_ips}"
IS_FIRST_MASTER="${is_first_master}"

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

# ── Cluster Initialization ────────────────────────────────────────────────────
if [ "$IS_FIRST_MASTER" = "true" ]; then
  # Create kubeadm config
  cat > /tmp/kubeadm-config.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: $MASTER_PRIVATE_IP
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
  kubeletExtraArgs:
    node-ip: $MASTER_PRIVATE_IP
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: v$K8S_VERSION
clusterName: $CLUSTER_NAME
networking:
  podSubnet: $POD_CIDR
  serviceSubnet: $SERVICE_CIDR
controlPlaneEndpoint: "$MASTER_PRIVATE_IP:6443"
apiServer:
  certSANs:
    - "$MASTER_PRIVATE_IP"
    - "127.0.0.1"
    - "localhost"
controllerManager:
  extraArgs:
    - name: bind-address
      value: "0.0.0.0"
scheduler:
  extraArgs:
    - name: bind-address
      value: "0.0.0.0"
EOF

  kubeadm init --config /tmp/kubeadm-config.yaml --upload-certs | tee /tmp/kubeadm-init.log

  # Setup kubeconfig for root
  mkdir -p /root/.kube
  cp /etc/kubernetes/admin.conf /root/.kube/config

  # Generate join command for workers
  kubeadm token create --print-join-command > /tmp/worker-join-command.sh
  chmod +x /tmp/worker-join-command.sh

  # Generate join command for control planes
  kubeadm init phase upload-certs --upload-certs 2>/dev/null | tail -1 > /tmp/certificate-key
  CERT_KEY=$(cat /tmp/certificate-key)
  WORKER_CMD=$(cat /tmp/worker-join-command.sh)
  echo "$WORKER_CMD --control-plane --certificate-key $CERT_KEY" > /tmp/master-join-command.sh
  chmod +x /tmp/master-join-command.sh

  # Install Cilium CNI
  CILIUM_CLI_VERSION="v0.16.24"
  curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/$CILIUM_CLI_VERSION/cilium-linux-amd64.tar.gz{,.sha256sum}
  sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
  tar xzf cilium-linux-amd64.tar.gz
  mv cilium /usr/local/bin/
  rm -f cilium-linux-amd64.tar.gz*

  cilium install --version 1.16.5 \
    --set ipam.operator.clusterPoolIPv4PodCIDRList="$POD_CIDR" \
    --set kubeProxyReplacement=true \
    --set k8sServiceHost="$MASTER_PRIVATE_IP" \
    --set k8sServicePort=6443

  # Wait for Cilium to be ready
  cilium status --wait --wait-duration=5m

  # Install Helm
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

  # Install AWS Load Balancer Controller
  kubectl apply -f https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml

  helm repo add eks https://aws.github.io/eks-charts
  helm repo update

  helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName="$CLUSTER_NAME" \
    --set serviceAccount.create=true \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set region=$(curl -s http://169.254.169.254/latest/meta-data/placement/region) \
    --set vpcId=$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/$(cat /sys/class/net/eth0/address)/vpc-id)

  # Mark cluster ready
  touch /var/lib/k8s-cluster-ready

else
  # Wait for first master to be ready
  until [ -f /tmp/master-join-command.sh ] || curl -sk https://$FIRST_MASTER_IP:6443/healthz; do
    echo "Waiting for first master..."
    sleep 10
  done
  sleep 30
fi

echo "Master node $MASTER_INDEX setup complete" > /var/log/k8s-setup.log
