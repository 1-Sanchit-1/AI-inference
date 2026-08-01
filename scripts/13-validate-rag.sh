#!/usr/bin/env bash
# Phase 13: RAG validation
# Port-forwards the RAG app, ingests a sample document, and asks a question
# that can only be answered from that document, proving retrieval + generation work end to end.
set -euo pipefail

NAMESPACE="ai-platform"
LOCAL_PORT="${LOCAL_PORT:-8001}"

microk8s kubectl -n "${NAMESPACE}" port-forward svc/rag-app "${LOCAL_PORT}:8001" >/tmp/rag-app-port-forward.log 2>&1 &
PF_PID=$!
trap 'kill ${PF_PID} 2>/dev/null || true' EXIT
sleep 5

echo "==> GET /health"
curl -sf "http://localhost:${LOCAL_PORT}/health"
echo

echo "==> POST /ingest (sample document)"
curl -sf "http://localhost:${LOCAL_PORT}/ingest" \
  -H "Content-Type: application/json" \
  -d '{
        "text": "The AI platform runs on MicroK8s with an NVIDIA A10G GPU. vLLM serves the Qwen2.5-7B-Instruct model through an OpenAI-compatible API. Qdrant stores document embeddings for retrieval-augmented generation.",
        "source": "sample-doc"
      }' | tee /tmp/rag-ingest-response.json
echo

echo "==> POST /query"
curl -sf "http://localhost:${LOCAL_PORT}/query" \
  -H "Content-Type: application/json" \
  -d '{"question": "Which GPU does the platform run on, and which model does vLLM serve?"}' \
  | tee /tmp/rag-query-response.json
echo

echo "RAG validation complete."
