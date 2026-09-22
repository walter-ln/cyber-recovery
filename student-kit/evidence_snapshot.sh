#!/usr/bin/env bash
set -euo pipefail

BUCKET="${1:-${BUCKET:-}}"
PREFIX="${2:-}"
WORK="${LAB_WORK:-}"

if [[ -z "$WORK" ]]; then
  echo "LAB_WORK nao definido. Execute: source ~/cyber-recovery-a/.lab.env ou source ~/cyber-recovery-b/.lab.env" >&2
  exit 2
fi
if [[ -z "$BUCKET" ]]; then
  echo "Uso: $0 <bucket> [prefix]" >&2
  exit 2
fi

mkdir -p "$WORK/evidencias"
TS="$(date -u +%Y%m%dT%H%M%SZ)"

aws sts get-caller-identity > "$WORK/evidencias/${TS}-identity.json"
aws s3api get-bucket-versioning --bucket "$BUCKET" \
  > "$WORK/evidencias/${TS}-versioning.json" 2>&1 || true
aws s3api get-bucket-policy --bucket "$BUCKET" \
  > "$WORK/evidencias/${TS}-policy.json" 2>&1 || true

if [[ -n "$PREFIX" ]]; then
  aws s3api list-object-versions --bucket "$BUCKET" --prefix "$PREFIX" \
    > "$WORK/evidencias/${TS}-versions.json" 2>&1 || true
else
  aws s3api list-object-versions --bucket "$BUCKET" \
    > "$WORK/evidencias/${TS}-versions.json" 2>&1 || true
fi

echo "Snapshot de evidencias salvo com prefixo $TS em $WORK/evidencias"
