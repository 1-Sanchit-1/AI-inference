#!/usr/bin/env bash
# Phase 12: RAG application deployment
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Applying RAG app manifests"
microk8s kubectl apply -f "${REPO_ROOT}/manifests/rag-app/"

echo "==> Waiting for the RAG app deployment to become available"
microk8s kubectl -n ai-platform rollout status deployment/rag-app --timeout=300s

microk8s kubectl -n ai-platform get pods -l app=rag-app
echo "RAG application deployed."
