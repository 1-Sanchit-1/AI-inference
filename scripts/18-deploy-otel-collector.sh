#!/usr/bin/env bash
# Phase 18: OpenTelemetry Collector
# Deploys the OTel Collector, which receives OTLP traces from the RAG app
# and forwards them to Tempo, while also exposing an OTLP-derived metrics
# endpoint for Prometheus.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Applying OTel Collector manifests"
microk8s kubectl apply -f "${REPO_ROOT}/manifests/observability/otel-collector/"

echo "==> Waiting for the OTel Collector to become available"
microk8s kubectl -n observability rollout status deployment/otel-collector --timeout=180s

microk8s kubectl -n observability get pods -l app=otel-collector
echo "OpenTelemetry Collector deployed."
