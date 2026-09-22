#!/usr/bin/env bash
set -euo pipefail

export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

GROUP="${1:-}"
if [[ "$GROUP" != "A" && "$GROUP" != "B" ]]; then
  echo "Uso: $0 A|B" >&2
  exit 2
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
SUFFIX="$(date -u +%Y%m%d%H%M%S)-$RANDOM"
WORK="$HOME/cyber-recovery-${GROUP,,}"

if [[ -e "$WORK/.lab.env" ]]; then
  echo "AVISO: ja existe um laboratorio em $WORK"
  echo "Para evitar sobrescrever evidencias, remova ou renomeie esse diretorio somente se tiver certeza."
  exit 3
fi

mkdir -p "$WORK"/{producao,evidencias,clean-room,incident,rehearsal}

cat > "$WORK/.lab.env" <<EOF
export AWS_DEFAULT_REGION='$AWS_DEFAULT_REGION'
export LAB_GROUP='$GROUP'
export LAB_ACCOUNT='$ACCOUNT'
export LAB_SUFFIX='$SUFFIX'
export LAB_WORK='$WORK'
export LAB_REPO_ROOT='$REPO_ROOT'
EOF

printf 'Ambiente local criado em: %s\n' "$WORK"
printf 'Conta AWS: %s\n' "$ACCOUNT"
printf 'Regiao: %s\n' "$AWS_DEFAULT_REGION"
printf 'Grupo: %s\n' "$GROUP"
printf 'Repositorio: %s\n' "$REPO_ROOT"
echo
echo "Execute:"
printf '  source %q\n' "$WORK/.lab.env"
printf '  cp %q %q/\n' "$REPO_ROOT/student-kit/create_dataset.sh" "$WORK"
printf '  cd %q && ./create_dataset.sh\n' "$WORK"
