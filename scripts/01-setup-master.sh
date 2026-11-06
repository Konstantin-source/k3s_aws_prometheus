#!/usr/bin/env bash
# ==============================================================================
# 01-setup-master.sh
# Führt die Installation von K3s auf der Master-Node (AWS EC2 Control Plane) durch.
# Traefik ist standardmäßig aktiviert.
# ==============================================================================
set -euo pipefail

echo "=========================================================="
echo " [1/3] K3s Master (Control Plane) Installation starten..."
echo "=========================================================="

# K3s mit integriertem Traefik Ingress Controller installieren
curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644 \
  --tls-san "$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || hostname -I | awk '{print $1}')"

echo "=========================================================="
echo " [2/3] K3s Service-Status prüfen..."
echo "=========================================================="
sudo systemctl status k3s --no-pager

# Kubeconfig für lokalen User verfügbar machen
mkdir -p "$HOME/.kube"
sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

echo "=========================================================="
echo " [3/3] Cluster-Token für Worker-Node:"
echo "=========================================================="
NODE_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)
MASTER_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 || hostname -I | awk '{print $1}')

echo ""
echo "Private Master-IP:  ${MASTER_IP}"
echo "Node-Token:         ${NODE_TOKEN}"
echo ""
echo "Führe auf der Worker-Node folgenden Befehl aus:"
echo "----------------------------------------------------------"
echo "curl -sfL https://get.k3s.io | K3S_URL=https://${MASTER_IP}:6443 K3S_TOKEN=${NODE_TOKEN} sh -"
echo "----------------------------------------------------------"
echo "Master-Setup erfolgreich abgeschlossen!"
