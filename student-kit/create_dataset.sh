#!/usr/bin/env bash
set -euo pipefail

WORK="${LAB_WORK:-$HOME/cyber-recovery-${LAB_GROUP,,}}"
mkdir -p "$WORK"/{producao,evidencias,clean-room,incident}

cat > "$WORK/producao/identity.json" <<'EOF'
{
  "service": "identity",
  "tier": 0,
  "state": "healthy",
  "generation": 42,
  "note": "Dependencia logica para autenticacao do ERP"
}
EOF

cat > "$WORK/producao/dns.json" <<'EOF'
{
  "service": "dns",
  "tier": 0,
  "state": "healthy",
  "records": {
    "erp.internal": "10.10.20.10",
    "db.internal": "10.10.30.20"
  }
}
EOF

cat > "$WORK/producao/config.ini" <<'EOF'
[SISTEMA]
nome=ERP-ACME
ambiente=producao
versao=2.4
database=db.internal
auth=identity
EOF

cat > "$WORK/producao/clientes.csv" <<'EOF'
id,nome,categoria
1001,Cliente-A,Premium
1002,Cliente-B,Standard
1003,Cliente-C,Premium
EOF

cat > "$WORK/producao/pedidos.json" <<'EOF'
{
  "pedidos": [
    {"id": 9001, "cliente": 1001, "valor": 1250},
    {"id": 9002, "cliente": 1002, "valor": 830},
    {"id": 9003, "cliente": 1003, "valor": 420}
  ]
}
EOF

cat > "$WORK/producao/recovery-metadata.json" <<'EOF'
{
  "business_service": "ERP-ACME",
  "declared_rpo_minutes": 30,
  "declared_rto_minutes": 120,
  "recovery_order": ["identity.json", "dns.json", "config.ini", "clientes.csv", "pedidos.json"]
}
EOF

(
  cd "$WORK/producao"
  sha256sum identity.json dns.json config.ini clientes.csv pedidos.json recovery-metadata.json \
    > "$WORK/evidencias/manifest.sha256"
)

date -u +"%Y-%m-%dT%H:%M:%SZ" > "$WORK/evidencias/source-state-time.txt"

echo "Dataset criado."
echo "Arquivos:"
find "$WORK/producao" -maxdepth 1 -type f -printf '  %f\n' | sort
echo
echo "Manifesto:"
cat "$WORK/evidencias/manifest.sha256"
