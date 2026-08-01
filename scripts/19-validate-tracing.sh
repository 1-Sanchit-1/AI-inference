#!/usr/bin/env bash
# Phase 19: Trace validation
# Sends a request through the RAG app to generate a trace, then queries
# Tempo directly to confirm the trace landed.
set -euo pipefail

APP_NAMESPACE="ai-platform"
OBS_NAMESPACE="observability"
RAG_PORT="${RAG_PORT:-8001}"
TEMPO_PORT="${TEMPO_PORT:-3200}"

microk8s kubectl -n "${APP_NAMESPACE}" port-forward svc/rag-app "${RAG_PORT}:8001" >/tmp/rag-app-port-forward.log 2>&1 &
RAG_PF_PID=$!
microk8s kubectl -n "${OBS_NAMESPACE}" port-forward svc/tempo "${TEMPO_PORT}:3200" >/tmp/tempo-port-forward.log 2>&1 &
TEMPO_PF_PID=$!
trap 'kill ${RAG_PF_PID} ${TEMPO_PF_PID} 2>/dev/null || true' EXIT
sleep 5

echo "==> Generating a trace via /health"
curl -sf "http://localhost:${RAG_PORT}/health" >/dev/null
echo "Request sent."

echo "==> Waiting for the span to be flushed and ingested by Tempo"
sleep 10

echo "==> Querying Tempo for recent traces from rag-app"
curl -sf "http://localhost:${TEMPO_PORT}/api/search?tags=service.name%3Drag-app&limit=5" | tee /tmp/tempo-search.json
echo

echo "Trace validation complete. Inspect /tmp/tempo-search.json for trace IDs."
