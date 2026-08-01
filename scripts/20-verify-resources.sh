#!/usr/bin/env bash
# Phase 20: Resource verification
# Final sanity sweep across both namespaces: confirms every workload is
# ready, prints GPU allocation, and surfaces anything not Running/Ready.
set -euo pipefail

echo "==> Nodes"
microk8s kubectl get nodes -o wide

echo
echo "==> Allocatable GPUs per node"
microk8s kubectl get nodes -o jsonpath="{range .items[*]}{.metadata.name}{'\t'}{.status.allocatable['nvidia\.com/gpu']}{'\n'}{end}"

echo
echo "==> ai-platform namespace"
microk8s kubectl -n ai-platform get deployments,statefulsets,pods,pvc

echo
echo "==> observability namespace"
microk8s kubectl -n observability get deployments,daemonsets,pods,pvc

echo
echo "==> Checking for non-ready pods"
NOT_READY=$(microk8s kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded -o json | python3 -c '
import json, sys
data = json.load(sys.stdin)
for item in data.get("items", []):
    print(f"{item[\"metadata\"][\"namespace\"]}/{item[\"metadata\"][\"name\"]}: {item[\"status\"].get(\"phase\")}")
')

if [ -n "${NOT_READY}" ]; then
  echo "WARNING: pods not in a healthy phase:" >&2
  echo "${NOT_READY}" >&2
  exit 1
fi

echo "All pods are Running or Succeeded."
echo "Resource verification complete."
