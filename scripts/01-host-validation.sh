#!/usr/bin/env bash
# Phase 1: Host validation
# Confirms the target host meets the minimum requirements for the platform:
# Ubuntu 24.04 LTS, an NVIDIA GPU, and a working NVIDIA driver.
set -euo pipefail

echo "==> Checking OS release"
if ! grep -q 'Ubuntu 24.04' /etc/os-release; then
  echo "WARNING: this runbook was validated on Ubuntu 24.04 LTS." >&2
fi
cat /etc/os-release

echo "==> Checking CPU / memory"
lscpu | grep -E '^CPU\(s\)|Model name'
free -h

echo "==> Checking for an NVIDIA GPU"
if ! command -v lspci >/dev/null 2>&1; then
  sudo apt-get update -y && sudo apt-get install -y pciutils
fi
lspci | grep -i nvidia || { echo "ERROR: no NVIDIA GPU detected" >&2; exit 1; }

echo "==> Checking NVIDIA driver"
if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "ERROR: nvidia-smi not found. Install the NVIDIA driver before continuing." >&2
  exit 1
fi
nvidia-smi

echo "==> Checking disk space (need >= 100GB free for model weights)"
df -h / | awk 'NR==2 {print "Available:", $4}'

echo "Host validation complete."
