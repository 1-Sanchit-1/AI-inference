#!/usr/bin/env bash
# Phase 16: Promtail configuration
# Deploys Promtail as a DaemonSet that tails pod logs on every node and
# ships them to Loki.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Applying Promtail manifests"
microk8s kubectl apply -f "${REPO_ROOT}/manifests/observability/promtail/"

echo "==> Waiting for Promtail DaemonSet rollout"
microk8s kubectl -n observability rollout status daemonset/promtail --timeout=180s

microk8s kubectl -n observability get pods -l app=promtail
echo "Promtail deployed."
