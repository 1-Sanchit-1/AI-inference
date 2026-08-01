#!/usr/bin/env bash
# Phase 7: vLLM validation
# Port-forwards the vLLM service and exercises the OpenAI-compatible API.
set -euo pipefail

NAMESPACE="ai-platform"
LOCAL_PORT="${LOCAL_PORT:-8000}"

microk8s kubectl -n "${NAMESPACE}" port-forward svc/vllm "${LOCAL_PORT}:8000" >/tmp/vllm-port-forward.log 2>&1 &
PF_PID=$!
trap 'kill ${PF_PID} 2>/dev/null || true' EXIT
sleep 5

echo "==> GET /v1/models"
curl -sf "http://localhost:${LOCAL_PORT}/v1/models" | tee /tmp/vllm-models.json
echo

echo "==> POST /v1/chat/completions"
curl -sf "http://localhost:${LOCAL_PORT}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
        "model": "Qwen/Qwen2.5-7B-Instruct",
        "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
        "max_tokens": 64
      }' | tee /tmp/vllm-chat-response.json
echo

echo "==> GET /metrics (Prometheus exposition format)"
curl -sf "http://localhost:${LOCAL_PORT}/metrics" | head -n 20

echo "vLLM validation complete."
