#!/usr/bin/env bash
# ==============================================================================
# 02-join-worker.sh
# Verbindet eine zweite EC2-Instanz als Worker-Node mit dem Master.
# Nutzung: ./02-join-worker.sh <MASTER_PRIVATE_IP> <NODE_TOKEN>
# ==============================================================================
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Fehler: Parameter fehlen!"
  echo "Verwendung: $0 <MASTER_PRIVATE_IP> <NODE_TOKEN>"
  exit 1
fi

MASTER_IP="$1"
NODE_TOKEN="$2"

echo "=========================================================="
echo " Trete K3s-Cluster bei: https://${MASTER_IP}:6443..."
echo "=========================================================="

curl -sfL https://get.k3s.io | K3S_URL="https://${MASTER_IP}:6443" K3S_TOKEN="${NODE_TOKEN}" sh -

echo "=========================================================="
echo " Worker erfolgreich beigetreten! Status:"
echo "=========================================================="
sudo systemctl status k3s-agent --no-pager
