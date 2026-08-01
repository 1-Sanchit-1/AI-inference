#!/usr/bin/env bash
# Phase 5: CUDA validation
# Runs a throwaway pod that requests one GPU and executes nvidia-smi inside
# the cluster, proving the device plugin and container runtime are wired up.
set -euo pipefail

NAMESPACE="default"
POD_NAME="cuda-validate"

cat <<'EOF' | microk8s kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: cuda-validate
  namespace: default
  labels:
    app: cuda-validate
spec:
  restartPolicy: Never
  containers:
    - name: cuda-validate
      image: nvidia/cuda:12.4.1-base-ubuntu22.04
      command: ["nvidia-smi"]
      resources:
        limits:
          nvidia.com/gpu: 1
EOF

cleanup() {
  microk8s kubectl delete pod "${POD_NAME}" -n "${NAMESPACE}" --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "==> Waiting for pod to complete"
microk8s kubectl wait --for=condition=Initialized "pod/${POD_NAME}" -n "${NAMESPACE}" --timeout=120s

if ! microk8s kubectl wait --for=jsonpath='{.status.phase}'=Succeeded "pod/${POD_NAME}" -n "${NAMESPACE}" --timeout=120s; then
  echo "ERROR: cuda-validate pod did not reach Succeeded. Current status:" >&2
  microk8s kubectl get "pod/${POD_NAME}" -n "${NAMESPACE}" -o wide >&2
  microk8s kubectl logs "pod/${POD_NAME}" -n "${NAMESPACE}" >&2 || true
  exit 1
fi

echo "==> nvidia-smi output from inside the cluster"
microk8s kubectl logs "pod/${POD_NAME}" -n "${NAMESPACE}"

echo "==> Allocatable GPUs per node"
microk8s kubectl get nodes -o jsonpath="{range .items[*]}{.metadata.name}{'\t'}{.status.allocatable['nvidia\.com/gpu']}{'\n'}{end}"

echo "CUDA validation complete."
