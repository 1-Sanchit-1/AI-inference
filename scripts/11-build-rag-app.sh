#!/usr/bin/env bash
# Phase 11: RAG application build
# Builds the RAG app image and imports it into MicroK8s's local image cache
# so the cluster can pull it without a registry.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="rag-app:latest"

echo "==> Building ${IMAGE}"
docker build -t "${IMAGE}" "${REPO_ROOT}/applications/rag-app"

echo "==> Importing image into MicroK8s"
docker save "${IMAGE}" | microk8s ctr image import -

echo "==> Verifying image is present in the cluster's image store"
microk8s ctr images ls | grep rag-app

echo "RAG application image built and imported."
