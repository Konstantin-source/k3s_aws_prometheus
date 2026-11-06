# ==============================================================================
# Terraform-Konfiguration fuer K3s-Cluster auf AWS EC2 (t3.small)
# ==============================================================================

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# 1. AWS Provider: Definiert die AWS-Region (Frankfurt)
provider "aws" {
  region = var.aws_region
}

# Variable fuer Region und SSH-Key-Namen
variable "aws_region" {
  description = "AWS Region fuer die Infrastruktur"
  type        = string
  default     = "eu-central-1" # Frankfurt
}

variable "key_name" {
  description = "Name deines vorhandenen AWS-Schluesselpaars (Key Pair) in der AWS Console"
  type        = string
  # Ersetze diesen Default-Wert durch den Namen deines AWS Key-Pairs (z. B. 'k8s-key')
  default     = "k8s-key"
}

# 2. Automatische Suche des neuesten offiziellen Ubuntu 24.04 LTS AMI von Canonical
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Offizieller Canonical-Account

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 3. Security Group (Firewall): Oeffnet alle benoetigten Ports fuer K3s und die App
resource "aws_security_group" "k3s_sg" {
  name        = "k3s-cluster-security-group"
  description = "Sicherheitsgruppe fuer K3s Master und Worker"

  # Port 22: SSH-Zugriff fuer die Administration
  ingress {
    description = "SSH Administration"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Port 80: HTTP-Traffic fuer Traefik Ingress (unsere Web-App)
  ingress {
    description = "HTTP Web Traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Port 443: HTTPS-Traffic
  ingress {
    description = "HTTPS Web Traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Port 6443: Kubernetes API Server (Worker verbindet sich hier mit Master)
  ingress {
    description = "Kubernetes API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Port 3000: Grafana Dashboard Web-Oberflaeche
  ingress {
    description = "Grafana Web Dashboard"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Interne Kommunikation: Erlaubt uneingeschraenkten Traffic zwischen den Nodes (fuer Flannel CNI Overlay)
  ingress {
    description = "Interner Cluster-Traffic zwischen Nodes (Flannel VXLAN)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Egress: Erlaubt den Instanzen ausgehenden Zugriff ins Internet (z. B. apt update, Docker Pull)
  egress {
    description = "Ausgehender Internet-Traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "k3s-security-group"
    Project = "Kubernetes-Praxistransferprojekt"
  }
}

# 4. Master Node (Control Plane) auf t3.small (2 GB RAM)
resource "aws_instance" "k3s_master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]

  root_block_device {
    volume_size = 20 # 20 GB SSD
    volume_type = "gp3"
  }

  tags = {
    Name    = "k3s-master"
    Role    = "master"
    Project = "Kubernetes-Praxistransferprojekt"
  }
}

# 5. Worker Node auf t3.small (2 GB RAM)
resource "aws_instance" "k3s_worker" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]

  root_block_device {
    volume_size = 20 # 20 GB SSD
    volume_type = "gp3"
  }

  tags = {
    Name    = "k3s-worker"
    Role    = "worker"
    Project = "Kubernetes-Praxistransferprojekt"
  }
}

# 6. Outputs: Gibt nach 'terraform apply' sofort alle IPs und SSH-Befehle aus
output "master_public_ip" {
  description = "Oeffentliche IP des Masters"
  value       = aws_instance.k3s_master.public_ip
}

output "master_private_ip" {
  description = "Private IP des Masters (fuer den Worker-Join benoetigt)"
  value       = aws_instance.k3s_master.private_ip
}

output "worker_public_ip" {
  description = "Oeffentliche IP des Workers"
  value       = aws_instance.k3s_worker.public_ip
}

output "ssh_command_master" {
  description = "Befehl zum Einloggen auf den Master"
  value       = "ssh -i ${var.key_name}.pem ubuntu@${aws_instance.k3s_master.public_ip}"
}

output "ssh_command_worker" {
  description = "Befehl zum Einloggen auf den Worker"
  value       = "ssh -i ${var.key_name}.pem ubuntu@${aws_instance.k3s_worker.public_ip}"
}
