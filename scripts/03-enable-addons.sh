#!/usr/bin/env bash
# Phase 3: Addon enablement
# Enables the MicroK8s addons the platform depends on: DNS, local storage,
# an ingress controller, the metrics server, and Helm 3.
set -euo pipefail

echo "==> Enabling core addons"
microk8s enable dns
microk8s enable hostpath-storage
microk8s enable ingress
microk8s enable metrics-server
microk8s enable helm3
microk8s enable dashboard 2>/dev/null || true

echo "==> Waiting for core addon pods to be ready"
microk8s kubectl -n kube-system rollout status deployment/coredns --timeout=180s
microk8s kubectl -n ingress rollout status daemonset/nginx-ingress-microk8s-controller --timeout=180s || true

echo "==> Cluster nodes"
microk8s kubectl get nodes -o wide

echo "==> Storage classes"
microk8s kubectl get storageclass

echo "Addons enabled."
