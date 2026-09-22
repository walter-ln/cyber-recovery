#!/usr/bin/env bash
set -euo pipefail

BUCKET="${1:-}"
PREFIX="${2:-vault}"
WORK="${LAB_WORK:-}"

if [[ -z "$BUCKET" || -z "$WORK" ]]; then
  echo "Uso: source .lab.env e depois: $0 <bucket> [prefix]" >&2
  exit 2
fi

if [[ ! "$BUCKET" =~ ^cr-a-${LAB_ACCOUNT}- ]]; then
  echo "Recusado: bucket nao corresponde ao Grupo A/conta atual." >&2
  exit 2
fi

mkdir -p "$WORK/evidencias"
OUT="$WORK/evidencias/recovery-points.csv"
echo "recovery_point,timestamp,arquivo,version_id,pedidos,total" > "$OUT"

make_state() {
  local rp="$1"
  local pedidos="$2"
  local total="$3"
  local note="$4"

  python3 - "$WORK/producao/pedidos.json" "$pedidos" "$total" "$rp" "$note" <<'PY'
import json, sys
path, count, total, rp, note = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4], sys.argv[5]
base = [
    {"id": 9001, "cliente": 1001, "valor": 1250},
    {"id": 9002, "cliente": 1002, "valor": 830},
    {"id": 9003, "cliente": 1003, "valor": 420},
    {"id": 9004, "cliente": 1001, "valor": 300},
    {"id": 9005, "cliente": 1002, "valor": 500},
    {"id": 9006, "cliente": 1003, "valor": 700},
]
chosen = base[:count]
# Ajusta o último valor para obter o total didático esperado.
if chosen:
    current = sum(x["valor"] for x in chosen)
    chosen[-1]["valor"] += total-current
obj = {"recovery_point": rp, "note": note, "pedidos": chosen}
open(path,"w").write(json.dumps(obj, indent=2) + "\n")
PY

  python3 - "$WORK/producao/config.ini" "$rp" <<'PY'
import sys
path, rp = sys.argv[1], sys.argv[2]
open(path,"w").write(
f"""[SISTEMA]
nome=ERP-ACME
ambiente=producao
versao=2.4
database=db.internal
auth=identity
recovery_point={rp}
"""
)
PY

  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  for f in identity.json dns.json config.ini clientes.csv pedidos.json recovery-metadata.json; do
    vid="$(aws s3api put-object \
      --bucket "$BUCKET" \
      --key "$PREFIX/$f" \
      --body "$WORK/producao/$f" \
      --metadata recovery-point="$rp" \
      --query VersionId --output text)"
    echo "$rp,$ts,$f,$vid,$pedidos,$total" >> "$OUT"
  done

  (
    cd "$WORK/producao"
    sha256sum identity.json dns.json config.ini clientes.csv pedidos.json recovery-metadata.json \
      > "$WORK/evidencias/manifest-${rp}.sha256"
  )
  mvid="$(aws s3api put-object \
    --bucket "$BUCKET" \
    --key "$PREFIX/manifests/manifest-${rp}.sha256" \
    --body "$WORK/evidencias/manifest-${rp}.sha256" \
    --metadata recovery-point="$rp" \
    --query VersionId --output text)"
  echo "$rp,$ts,manifest-${rp}.sha256,$mvid,$pedidos,$total" >> "$OUT"

  echo "[$rp] criado: pedidos=$pedidos total=$total timestamp=$ts"
}

make_state "RP01" 2 2080 "Inicio do periodo"
sleep 1
make_state "RP02" 3 2500 "Operacao normal"
sleep 1
make_state "RP03" 4 2800 "Fechamento parcial"
sleep 1
make_state "RP04" 5 3300 "Ultimo ponto da Aula 1"

cp "$WORK/evidencias/manifest-RP04.sha256" "$WORK/evidencias/manifest.sha256"

echo
echo "Historico criado."
echo "Arquivo: $OUT"
