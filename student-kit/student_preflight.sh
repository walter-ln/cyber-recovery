#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================================"
echo "CYBER RECOVERY GAME DAY — STUDENT PREFLIGHT"
echo "============================================================"
echo "Este preflight é somente leitura e não consome créditos."
echo

chmod +x "$SCRIPT_DIR/aws_access_check.sh"
"$SCRIPT_DIR/aws_access_check.sh" --required

echo
echo "Preflight concluído. Nenhum recurso foi criado, alterado ou removido."
echo "Preserve o relatório gerado: ele comprova as capacidades e restrições da sessão."
