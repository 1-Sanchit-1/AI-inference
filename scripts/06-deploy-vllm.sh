#!/usr/bin/env bash
# Phase 6: vLLM deployment
# Applies the ai-platform namespace and the vLLM Deployment/Service, which
# expose an OpenAI-compatible inference API backed by the GPU.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Applying namespaces"
microk8s kubectl apply -f "${REPO_ROOT}/manifests/namespace.yaml"

echo "==> Applying vLLM manifests"
microk8s kubectl apply -f "${REPO_ROOT}/manifests/vllm/"

echo "==> Waiting for the vLLM deployment to become available (this pulls model weights, can take several minutes)"
microk8s kubectl -n ai-platform rollout status deployment/vllm --timeout=900s

microk8s kubectl -n ai-platform get pods -l app=vllm
echo "vLLM deployed."
