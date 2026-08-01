#!/usr/bin/env bash
# Phase 17: Tempo tracing
# Deploys Tempo to receive and store OTLP traces from the OpenTelemetry Collector.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Applying Tempo manifests"
microk8s kubectl apply -f "${REPO_ROOT}/manifests/observability/tempo/"

echo "==> Waiting for Tempo to become available"
microk8s kubectl -n observability rollout status deployment/tempo --timeout=180s

microk8s kubectl -n observability get pods -l app=tempo
echo "Tempo deployed."
