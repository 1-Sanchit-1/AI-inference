#!/usr/bin/env bash
# Bulk-ingest every supported file (.txt, .md, .pdf, .docx) in a directory
# into the RAG app via POST /ingest/file. Works against either the
# docker-compose stack or a port-forwarded k8s deployment.
#
# Usage: ./scripts/ingest-directory.sh <directory> [rag-app-url]
set -euo pipefail

DIR="${1:?Usage: $0 <directory> [rag-app-url]}"
RAG_APP_URL="${2:-http://localhost:8001}"

if [ ! -d "${DIR}" ]; then
  echo "ERROR: ${DIR} is not a directory" >&2
  exit 1
fi

shopt -s nullglob nocaseglob
files=("${DIR}"/*.txt "${DIR}"/*.md "${DIR}"/*.pdf "${DIR}"/*.docx)
shopt -u nullglob nocaseglob

if [ ${#files[@]} -eq 0 ]; then
  echo "No .txt/.md/.pdf/.docx files found in ${DIR}"
  exit 0
fi

failures=0
for f in "${files[@]}"; do
  echo "==> Ingesting $(basename "${f}")"
  if ! curl -sf -X POST "${RAG_APP_URL}/ingest/file" -F "file=@${f}"; then
    echo "FAILED: ${f}" >&2
    failures=$((failures + 1))
  fi
  echo
done

if [ "${failures}" -gt 0 ]; then
  echo "Done with ${failures} failure(s)." >&2
  exit 1
fi

echo "Done."
