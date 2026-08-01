#!/usr/bin/env bash
# Phase 8: Open WebUI installation
# Deploys Open WebUI pointed at the vLLM OpenAI-compatible endpoint.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Applying Open WebUI manifests"
microk8s kubectl apply -f "${REPO_ROOT}/manifests/openwebui/"

echo "==> Waiting for Open WebUI to become available"
microk8s kubectl -n ai-platform rollout status deployment/open-webui --timeout=300s

microk8s kubectl -n ai-platform get pods -l app=open-webui
echo "Open WebUI deployed."
