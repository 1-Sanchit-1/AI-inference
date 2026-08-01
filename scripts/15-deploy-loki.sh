#!/usr/bin/env bash
# Phase 15: Loki setup
# Deploys Loki for centralized log aggregation, storing chunks on a PVC.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Applying Loki manifests"
microk8s kubectl apply -f "${REPO_ROOT}/manifests/observability/loki/"

echo "==> Waiting for Loki to become available"
microk8s kubectl -n observability rollout status deployment/loki --timeout=180s

microk8s kubectl -n observability get pods -l app=loki
echo "Loki deployed."
