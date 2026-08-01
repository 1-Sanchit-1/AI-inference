#!/usr/bin/env bash
# Phase 10: Qdrant deployment
# Deploys the Qdrant vector database used for RAG retrieval.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Applying Qdrant manifests"
microk8s kubectl apply -f "${REPO_ROOT}/manifests/qdrant/"

echo "==> Waiting for the Qdrant StatefulSet to become ready"
microk8s kubectl -n ai-platform rollout status statefulset/qdrant --timeout=180s

microk8s kubectl -n ai-platform get pods -l app=qdrant
echo "Qdrant deployed."
