#!/usr/bin/env bash
# ==============================================================================
# 04-load-test.sh
# Erzeugt kontrollierte Last auf dem Backend, um HPA-Skalierung zu demonstrieren.
# ==============================================================================
set -euo pipefail

TARGET_URL="${1:-http://localhost/api/v1/work?iterations=600000}"
CONCURRENCY=10
REQUESTS=100

echo "=========================================================="
echo " Starte HPA-Lasttest..."
echo " Ziel:       ${TARGET_URL}"
echo " Parallel:   ${CONCURRENCY} Anfragen"
echo " Gesamt:     ${REQUESTS} Anfragen"
echo "=========================================================="

echo "Aktueller HPA-Status vor dem Test:"
kubectl get hpa prod-backend-hpa

echo ""
echo "Sende Anfragen zur Erzeugung von CPU-Last..."
for i in $(seq 1 $REQUESTS); do
  curl -s "${TARGET_URL}" > /dev/null &
  if (( i % CONCURRENCY == 0 )); then
    wait
    echo -n "."
  fi
done
wait

echo ""
echo "Last erfolgreich generiert!"
echo "Überwache HPA-Skalierung für 60 Sekunden (Strg+C zum Abbrechen)..."
kubectl get hpa prod-backend-hpa -w
