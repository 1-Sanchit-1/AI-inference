#!/usr/bin/env bash
# Phase 4: NVIDIA GPU Operator setup
# Installs the NVIDIA GPU Operator via Helm so pods can request nvidia.com/gpu
# resources. MicroK8s already ships the containerd runtime the operator needs.
set -euo pipefail

echo "==> Adding the NVIDIA Helm repo"
microk8s helm3 repo add nvidia https://helm.ngc.nvidia.com/nvidia || true
microk8s helm3 repo update

echo "==> Creating gpu-operator namespace"
microk8s kubectl create namespace gpu-operator --dry-run=client -o yaml | microk8s kubectl apply -f -

echo "==> Installing the GPU Operator"
microk8s helm3 upgrade --install gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator \
  --set driver.enabled=false \
  --set toolkit.env[0].name=CONTAINERD_CONFIG \
  --set toolkit.env[0].value=/var/snap/microk8s/current/args/containerd-template.toml \
  --set toolkit.env[1].name=CONTAINERD_SOCKET \
  --set toolkit.env[1].value=/var/snap/microk8s/common/run/containerd.sock \
  --set toolkit.env[2].name=CONTAINERD_RUNTIME_CLASS \
  --set toolkit.env[2].value=nvidia

echo "==> Waiting for GPU Operator pods"
microk8s kubectl -n gpu-operator wait --for=condition=Ready pod --all --timeout=300s

echo "==> GPU Operator pods"
microk8s kubectl -n gpu-operator get pods

echo "GPU Operator installed. Nodes should soon report an nvidia.com/gpu allocatable resource."
