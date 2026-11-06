#!/usr/bin/env bash
# ==============================================================================
# 03-deploy.sh
# Bereitstellung von Monitoring und der Microservice-Anwendung mit Kustomize
# ==============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

echo "=========================================================="
echo " [1/3] Monitoring (Prometheus & Grafana) deployen..."
echo "=========================================================="
kubectl apply -f "$ROOT_DIR/monitoring/prometheus.yaml"
kubectl apply -f "$ROOT_DIR/monitoring/grafana.yaml"

echo "=========================================================="
echo " [2/3] Community Pulse Applikation mit Kustomize (Prod) deployen..."
echo "=========================================================="
kubectl apply -k "$ROOT_DIR/k8s/overlays/prod"

echo "=========================================================="
echo " [3/3] Rollout-Status überwachen..."
echo "=========================================================="
kubectl rollout status deployment/prod-postgres --timeout=120s
kubectl rollout status deployment/prod-backend --timeout=120s
kubectl rollout status deployment/prod-frontend --timeout=120s

echo ""
echo "Erfolgreich bereitgestellt!"
echo "Cluster-Übersicht:"
kubectl get pods,services,ingress,hpa -o wide
