# ── Data Sources ──────────────────────────────────────────────────────────────
data "aws_ami" "debian" {
  count = var.ami_id == "" ? 1 : 0

  most_recent = true
  owners      = ["136693071363"] # Debian official

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ── Security Groups ──────────────────────────────────────────────────────────
resource "aws_security_group" "control_plane" {
  name_prefix = "${var.cluster_name}-cp-"
  vpc_id      = var.vpc_id
  description = "Kubernetes control plane security group"

  # API Server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Kubernetes API server"
  }

  # etcd
  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    self        = true
    description = "etcd server client API"
  }

  # Kubelet API
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    self        = true
    description = "Kubelet API"
  }

  # Kube-scheduler
  ingress {
    from_port   = 10259
    to_port     = 10259
    protocol    = "tcp"
    self        = true
    description = "kube-scheduler"
  }

  # Kube-controller-manager
  ingress {
    from_port   = 10257
    to_port     = 10257
    protocol    = "tcp"
    self        = true
    description = "kube-controller-manager"
  }

  # Cilium VXLAN
  ingress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    self        = true
    description = "Cilium VXLAN"
  }

  # Cilium health
  ingress {
    from_port   = 4240
    to_port     = 4240
    protocol    = "tcp"
    self        = true
    description = "Cilium health checks"
  }

  # Cilium Hubble
  ingress {
    from_port   = 4244
    to_port     = 4244
    protocol    = "tcp"
    self        = true
    description = "Cilium Hubble"
  }

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # All outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-control-plane"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "worker" {
  name_prefix = "${var.cluster_name}-worker-"
  vpc_id      = var.vpc_id
  description = "Kubernetes worker node security group"

  # Kubelet API
  ingress {
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = [aws_security_group.control_plane.id]
    description     = "Kubelet API from control plane"
  }

  # NodePort services
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "NodePort services"
  }

  # Cilium VXLAN
  ingress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    self        = true
    description = "Cilium VXLAN"
  }

  # Cilium health
  ingress {
    from_port   = 4240
    to_port     = 4240
    protocol    = "tcp"
    self        = true
    description = "Cilium health checks"
  }

  # Inter-worker communication
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Inter-worker communication"
  }

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # All outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-worker"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ── SSH Key Pair ─────────────────────────────────────────────────────────────
resource "aws_key_pair" "k8s" {
  count      = var.key_name == "" ? 1 : 0
  key_name   = "${var.cluster_name}-key"
  public_key = var.public_key

  tags = var.tags
}

locals {
  key_name = var.key_name != "" ? var.key_name : aws_key_pair.k8s[0].key_name
}

# ── Control Plane EC2 Instances ──────────────────────────────────────────────
resource "aws_instance" "control_plane" {
  count = var.control_plane_count

  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.debian[0].id
  instance_type          = var.instance_type
  key_name               = local.key_name
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = [aws_security_group.control_plane.id]

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/templates/user-data-master.sh.tpl", {
    k8s_version       = var.k8s_version
    pod_cidr          = var.pod_cidr
    service_cidr      = var.service_cidr
    cluster_name      = var.cluster_name
    master_index      = count.index
    master_private_ip = "" # Will be set after creation
    all_master_ips    = ""
    is_first_master   = count.index == 0 ? "true" : "false"
  }))

  tags = merge(var.tags, {
    Name                                        = "${var.cluster_name}-master-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    Role                                        = "control-plane"
  })

  lifecycle {
    ignore_changes = [user_data]
  }
}

# ── Worker EC2 Instances ─────────────────────────────────────────────────────
resource "aws_instance" "worker" {
  count = var.worker_count

  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.debian[0].id
  instance_type          = var.instance_type
  key_name               = local.key_name
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = [aws_security_group.worker.id]

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/templates/user-data-worker.sh.tpl", {
    k8s_version       = var.k8s_version
    cluster_name      = var.cluster_name
    worker_index      = count.index
    worker_private_ip = ""
    first_master_ip   = aws_instance.control_plane[0].private_ip
  }))

  tags = merge(var.tags, {
    Name                                        = "${var.cluster_name}-worker-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    Role                                        = "worker"
  })

  lifecycle {
    ignore_changes = [user_data]
  }

  depends_on = [aws_instance.control_plane]
}

# ── Network Load Balancer for API Server ─────────────────────────────────────
resource "aws_lb" "k8s_api" {
  name               = "${var.cluster_name}-api-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.subnet_ids

  enable_cross_zone_load_balancing = true

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-api-nlb"
  })
}

resource "aws_lb_target_group" "k8s_api" {
  name     = "${var.cluster_name}-api-tg"
  port     = 6443
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    protocol            = "HTTPS"
    path                = "/healthz"
    port                = 6443
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-api-tg"
  })
}

resource "aws_lb_target_group_attachment" "k8s_api" {
  count            = var.control_plane_count
  target_group_arn = aws_lb_target_group.k8s_api.arn
  target_id        = aws_instance.control_plane[count.index].id
  port             = 6443
}

resource "aws_lb_listener" "k8s_api" {
  load_balancer_arn = aws_lb.k8s_api.arn
  port              = 6443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s_api.arn
  }
}

# ── Cluster Initialization ──────────────────────────────────────────────────
resource "null_resource" "cluster_init" {
  # Wait for first master to be ready
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for user-data to complete...'",
      "timeout 600 bash -c 'until [ -f /var/lib/k8s-cluster-ready ] || [ -f /var/log/k8s-setup.log ]; do sleep 10; done'",
      "echo 'User-data completed'",
      "sudo cat /tmp/kubeadm-init.log || echo 'No init log yet'"
    ]

    connection {
      type        = "ssh"
      user        = "admin"
      private_key = var.private_key
      host        = aws_instance.control_plane[0].public_ip
    }
  }

  # Get join commands and execute on other nodes
  provisioner "local-exec" {
    command = <<-EOT
      # Wait for join commands to be generated
      sleep 30

      # Get worker join command
      ssh -o StrictHostKeyChecking=no -i <(echo "$PRIVATE_KEY") admin@${aws_instance.control_plane[0].public_ip} \
        "sudo cat /tmp/worker-join-command.sh" > /tmp/worker-join-command.sh
      
      # Get master join command
      ssh -o StrictHostKeyChecking=no -i <(echo "$PRIVATE_KEY") admin@${aws_instance.control_plane[0].public_ip} \
        "sudo cat /tmp/master-join-command.sh" > /tmp/master-join-command.sh

      chmod +x /tmp/worker-join-command.sh /tmp/master-join-command.sh
    EOT

    environment = {
      PRIVATE_KEY = var.private_key
    }
  }

  depends_on = [aws_instance.control_plane]
}

# ── Join Additional Control Planes ───────────────────────────────────────────
resource "null_resource" "join_master" {
  count = var.control_plane_count > 1 ? var.control_plane_count - 1 : 0

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for bootstrap to complete...'",
      "timeout 600 bash -c 'until [ -f /var/log/k8s-setup.log ]; do sleep 10; done'",
      "echo 'Joining control plane...'",
      "sudo $(cat /tmp/master-join-command.sh) || echo 'Join command may have already run'"
    ]

    connection {
      type        = "ssh"
      user        = "admin"
      private_key = var.private_key
      host        = aws_instance.control_plane[count.index + 1].public_ip
    }
  }

  depends_on = [null_resource.cluster_init]
}

# ── Join Workers ─────────────────────────────────────────────────────────────
resource "null_resource" "join_worker" {
  count = var.worker_count

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for bootstrap to complete...'",
      "timeout 600 bash -c 'until [ -f /var/lib/k8s-worker-ready ]; do sleep 10; done'",
      "echo 'Joining worker to cluster...'",
      "sudo $(cat /tmp/worker-join-command.sh) || echo 'Join command may have already run'"
    ]

    connection {
      type        = "ssh"
      user        = "admin"
      private_key = var.private_key
      host        = aws_instance.worker[count.index].public_ip
    }
  }

  depends_on = [null_resource.cluster_init]
}

# ── Retrieve Kubeconfig ──────────────────────────────────────────────────────
resource "null_resource" "get_kubeconfig" {
  provisioner "local-exec" {
    command = <<-EOT
      sleep 30
      ssh -o StrictHostKeyChecking=no -i <(echo "$PRIVATE_KEY") admin@${aws_instance.control_plane[0].public_ip} \
        "sudo cat /root/.kube/config" | sed "s|server: https://.*:6443|server: https://${aws_lb.k8s_api.dns_name}:6443|g" > ${path.module}/kubeconfig-${var.cluster_name}.yaml
      echo "Kubeconfig saved to ${path.module}/kubeconfig-${var.cluster_name}.yaml"
    EOT

    environment = {
      PRIVATE_KEY = var.private_key
    }
  }

  depends_on = [null_resource.cluster_init, aws_lb_listener.k8s_api]
}
