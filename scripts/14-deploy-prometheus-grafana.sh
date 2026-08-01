#!/usr/bin/env bash
# Phase 14: Prometheus / Grafana deployment
# Applies Prometheus (with RBAC for service discovery) and Grafana
# (pre-provisioned with Prometheus/Loki/Tempo datasources and a starter
# dashboard). The Grafana admin password is generated at deploy time and
# never committed to the repo.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Applying namespaces"
microk8s kubectl apply -f "${REPO_ROOT}/manifests/namespace.yaml"

if ! microk8s kubectl -n observability get secret grafana-admin >/dev/null 2>&1; then
  echo "==> Generating Grafana admin secret"
  GRAFANA_PASSWORD="$(openssl rand -base64 24)"
  microk8s kubectl -n observability create secret generic grafana-admin \
    --from-literal=password="${GRAFANA_PASSWORD}"
  echo "Grafana admin password (save this, it will not be shown again): ${GRAFANA_PASSWORD}"
else
  echo "==> Grafana admin secret already exists, leaving it untouched"
fi

echo "==> Applying Prometheus manifests"
microk8s kubectl apply -f "${REPO_ROOT}/manifests/observability/prometheus/"

echo "==> Applying Grafana manifests"
microk8s kubectl apply -f "${REPO_ROOT}/manifests/observability/grafana/"

echo "==> Waiting for rollouts"
microk8s kubectl -n observability rollout status deployment/prometheus --timeout=180s
microk8s kubectl -n observability rollout status deployment/grafana --timeout=180s

echo "Prometheus and Grafana deployed."
