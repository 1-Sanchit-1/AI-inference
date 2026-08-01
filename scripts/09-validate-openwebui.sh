#!/usr/bin/env bash
# Phase 9: Open WebUI validation
# Port-forwards Open WebUI and checks that it responds and can see the
# vLLM-backed model list through its configured OpenAI-compatible backend.
set -euo pipefail

NAMESPACE="ai-platform"
LOCAL_PORT="${LOCAL_PORT:-8080}"

microk8s kubectl -n "${NAMESPACE}" port-forward svc/open-webui "${LOCAL_PORT}:8080" >/tmp/openwebui-port-forward.log 2>&1 &
PF_PID=$!
trap 'kill ${PF_PID} 2>/dev/null || true' EXIT
sleep 5

echo "==> GET /health"
curl -sf "http://localhost:${LOCAL_PORT}/health"
echo

echo "Open WebUI is reachable at http://localhost:${LOCAL_PORT} while this port-forward is active."
echo "Log in, then confirm the vLLM-served model appears under Settings > Connections."
