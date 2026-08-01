#!/usr/bin/env bash
# Runs every phase script in order. Intended to be executed on the target
# EC2 host itself (phases 1-5 need root/host access); safe to re-run since
# every script is idempotent.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

phase_count=0
for script in "${SCRIPT_DIR}"/[0-9][0-9]-*.sh; do
  echo
  echo "############################################################"
  echo "# Running $(basename "${script}")"
  echo "############################################################"
  bash "${script}"
  phase_count=$((phase_count + 1))
done

echo
echo "All ${phase_count} phases completed successfully."
