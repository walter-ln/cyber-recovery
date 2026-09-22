#!/usr/bin/env python3
from pathlib import Path
import csv, json, hashlib, sys

d = Path(sys.argv[1] if len(sys.argv) > 1 else "clean-room")
errors = []
checks = []

def ok(name, cond, detail):
    checks.append((name, bool(cond), detail))
    if not cond:
        errors.append(name)

required = ["identity.json","dns.json","config.ini","clientes.csv","pedidos.json","recovery-metadata.json","manifest.sha256"]
for f in required:
    ok(f"arquivo:{f}", (d/f).exists(), str(d/f))

try:
    identity = json.loads((d/"identity.json").read_text())
    ok("identity-state", identity.get("state") == "healthy", f"state={identity.get('state')}")
    ok("identity-tier", identity.get("tier") == 0, f"tier={identity.get('tier')}")
except Exception as e:
    ok("identity-json", False, repr(e))

try:
    dns = json.loads((d/"dns.json").read_text())
    records = dns.get("records", {})
    ok("dns-erp", records.get("erp.internal") == "10.10.20.10", str(records.get("erp.internal")))
    ok("dns-db", records.get("db.internal") == "10.10.30.20", str(records.get("db.internal")))
except Exception as e:
    ok("dns-json", False, repr(e))

try:
    rows = list(csv.DictReader((d/"clientes.csv").open()))
    ok("clientes-count", len(rows) == 3, f"count={len(rows)}")
except Exception as e:
    ok("clientes-csv", False, repr(e))

try:
    pedidos = json.loads((d/"pedidos.json").read_text())["pedidos"]
    total = sum(int(x["valor"]) for x in pedidos)
    ok("pedidos-count", len(pedidos) == 3, f"count={len(pedidos)}")
    ok("pedidos-total", total == 2500, f"total={total}")
except Exception as e:
    ok("pedidos-json", False, repr(e))

# Detecta marcadores simples de comprometimento usados no lab
ioc_terms = ["RANSOMWARE-DEMO", "ARQUIVO_CRIPTOGRAFADO", "COMPROMETIDO", "malicious-endpoint"]
for f in d.iterdir():
    if f.is_file():
        try:
            txt = f.read_text(errors="ignore")
            found = [x for x in ioc_terms if x in txt]
            ok(f"ioc:{f.name}", not found, f"found={found}")
        except Exception:
            pass

print("=== VALIDACAO DA CLEAN ROOM ===")
for name, passed, detail in checks:
    print(f"[{'PASS' if passed else 'FAIL'}] {name}: {detail}")

print()
if errors:
    print(f"RESULTADO: NO-GO ({len(errors)} falhas)")
    sys.exit(1)
print("RESULTADO: GO TECNICO PARA PROXIMO GATE")
