#!/usr/bin/env bash
# ==============================================================================
# 01-setup-master.sh
# Führt die Installation von K3s auf der Master-Node (AWS EC2 Control Plane) durch.
# ==============================================================================
set -euo pipefail

echo "=========================================================="
echo " [1/3] Ermittle IP-Adressen der AWS EC2 Instanz..."
echo "=========================================================="

# Sicheres Auslesen der AWS-IP-Adressen via IMDSv2 oder Fallback auf lokale IP
IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null || true)

if [ -n "$IMDS_TOKEN" ] && [ "${#IMDS_TOKEN}" -gt 10 ]; then
  PUBLIC_IP=$(curl -sf -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || hostname -I | awk '{print $1}')
  MASTER_IP=$(curl -sf -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null || hostname -I | awk '{print $1}')
else
  PUBLIC_IP=$(hostname -I | awk '{print $1}')
  MASTER_IP=$(hostname -I | awk '{print $1}')
fi

echo "Master Private IP: ${MASTER_IP}"
echo "Master Public IP:  ${PUBLIC_IP}"

echo "=========================================================="
echo " [2/3] K3s Master (Control Plane) Installation starten..."
echo "=========================================================="

curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644 \
  --tls-san "${MASTER_IP}" \
  --tls-san "${PUBLIC_IP}"

# Kubeconfig fuer den lokalen User bereitstellen
mkdir -p "$HOME/.kube"
sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

echo "=========================================================="
echo " [3/3] Cluster-Token fuer Worker-Node:"
echo "=========================================================="
NODE_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)

echo ""
echo "Private Master-IP:  ${MASTER_IP}"
echo "Node-Token:         ${NODE_TOKEN}"
echo ""
echo "Führe auf der Worker-Node folgenden Befehl aus:"
echo "----------------------------------------------------------"
echo "curl -sfL https://get.k3s.io | K3S_URL=https://${MASTER_IP}:6443 K3S_TOKEN=${NODE_TOKEN} sh -"
echo "----------------------------------------------------------"
echo "Master-Setup erfolgreich abgeschlossen!"
