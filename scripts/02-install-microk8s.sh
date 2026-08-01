#!/usr/bin/env bash
# Phase 2: MicroK8s installation
# Installs MicroK8s via snap, adds the current user to the microk8s group,
# and waits for the cluster to report ready.
set -euo pipefail

MICROK8S_CHANNEL="${MICROK8S_CHANNEL:-1.30/stable}"

echo "==> Installing MicroK8s (channel: ${MICROK8S_CHANNEL})"
sudo snap install microk8s --classic --channel="${MICROK8S_CHANNEL}"

echo "==> Adding $(whoami) to the microk8s group"
sudo usermod -aG microk8s "$(whoami)"
sudo chown -R "$(whoami)" ~/.kube 2>/dev/null || mkdir -p ~/.kube

echo "==> Waiting for MicroK8s to become ready"
sudo microk8s status --wait-ready

echo "==> Writing kubeconfig to ~/.kube/config"
sudo microk8s config > ~/.kube/config
chmod 600 ~/.kube/config

echo "==> Creating kubectl alias helper"
sudo snap alias microk8s.kubectl kubectl 2>/dev/null || true

echo "MicroK8s installed. Log out/in (or 'newgrp microk8s') for group membership to take effect."
microk8s kubectl version --short || true
