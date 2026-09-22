#!/usr/bin/env bash
set -euo pipefail

BUCKET="${1:-}"

if [[ -z "$BUCKET" ]]; then
  echo "Uso: $0 <bucket-do-laboratorio>" >&2
  exit 2
fi

ACCOUNT="$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)"
if [[ -z "$ACCOUNT" ]]; then
  echo "Nao foi possivel validar a conta AWS atual." >&2
  exit 2
fi

# Só aceita o padrão criado pelos roteiros e exige que o Account ID atual
# esteja incorporado no nome do bucket.
if [[ ! "$BUCKET" =~ ^cr-[ab]-${ACCOUNT}-[0-9]{14}-[0-9]+$ ]]; then
  echo "RECUSADO." >&2
  echo "O bucket nao corresponde ao padrao seguro deste laboratorio para a conta atual:" >&2
  echo "  cr-a-${ACCOUNT}-YYYYMMDDhhmmss-RANDOM" >&2
  echo "  cr-b-${ACCOUNT}-YYYYMMDDhhmmss-RANDOM" >&2
  exit 2
fi

# Confirma que o bucket existe e e acessivel antes de qualquer exclusao.
aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1 || {
  echo "Bucket inexistente ou inacessivel: $BUCKET" >&2
  exit 2
}

echo "ATENCAO: este script removera TODAS as versoes e delete markers do bucket:"
echo "  $BUCKET"
echo
read -r -p "Digite exatamente DELETE-LAB-$ACCOUNT para continuar: " ACK
[[ "$ACK" == "DELETE-LAB-$ACCOUNT" ]] || {
  echo "Cancelado."
  exit 3
}

# A policy do Grupo A pode impedir DeleteObjectVersion.
aws s3api delete-bucket-policy --bucket "$BUCKET" >/dev/null 2>&1 || true

python3 - "$BUCKET" <<'PY'
import json, subprocess, sys

bucket = sys.argv[1]
paginator = None
objects = []

while True:
    cmd = ["aws","s3api","list-object-versions","--bucket",bucket,"--output","json"]
    if paginator:
        cmd += ["--key-marker", paginator[0], "--version-id-marker", paginator[1]]
    data = json.loads(subprocess.check_output(cmd))
    for x in data.get("Versions", []):
        objects.append({"Key": x["Key"], "VersionId": x["VersionId"]})
    for x in data.get("DeleteMarkers", []):
        objects.append({"Key": x["Key"], "VersionId": x["VersionId"]})
    if not data.get("IsTruncated"):
        break
    paginator = (data.get("NextKeyMarker",""), data.get("NextVersionIdMarker",""))

for i in range(0, len(objects), 1000):
    batch = {"Objects": objects[i:i+1000], "Quiet": True}
    subprocess.check_call([
        "aws","s3api","delete-objects",
        "--bucket",bucket,
        "--delete",json.dumps(batch),
        "--output","json"
    ])
PY

aws s3api delete-bucket --bucket "$BUCKET"
echo "Bucket removido com sucesso: $BUCKET"
