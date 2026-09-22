#!/usr/bin/env bash
# Cyber Recovery / AWS Academy — inventário de capacidades
#
# Uso no AWS CloudShell:
#   ./student-kit/aws_access_check.sh                 # leitura + simulação IAM, sem criar recursos
#   ./student-kit/aws_access_check.sh --required      # somente capacidades exigidas pelo laboratório
#   ./student-kit/aws_access_check.sh --write-probes  # professor: testes reversíveis com recursos temporários
#
# O script não tenta elevar privilégio, não contorna SCP e não altera IAM.
# Uma resposta ALLOWED da simulação IAM é apenas indicativa: SCP, session policy,
# permissions boundary, condições e políticas do recurso podem mudar o resultado real.

set -uo pipefail
export AWS_PAGER=""
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

MODE="full"
WRITE_PROBES=0
for arg in "$@"; do
  case "$arg" in
    --required) MODE="required" ;;
    --full) MODE="full" ;;
    --write-probes) WRITE_PROBES=1 ;;
    -h|--help)
      sed -n '2,14p' "$0"
      exit 0
      ;;
    *) echo "Argumento desconhecido: $arg" >&2; exit 2 ;;
  esac
done

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="${CR_ACCESS_OUT:-$HOME/cyber-recovery-access-$timestamp}"
mkdir -p "$OUT/raw"
SUMMARY="$OUT/access-summary.csv"
REPORT="$OUT/access-report.md"
printf 'categoria,capacidade,status,observacao\n' > "$SUMMARY"

PASS=0; DENIED=0; WARN=0; UNKNOWN=0
csv_escape(){ local s=${1//\"/\"\"}; printf '"%s"' "$s"; }
record(){
  local category="$1" capability="$2" status="$3" note="$4"
  printf '%s,%s,%s,%s\n' "$(csv_escape "$category")" "$(csv_escape "$capability")" \
    "$(csv_escape "$status")" "$(csv_escape "$note")" >> "$SUMMARY"
  case "$status" in
    PASS|ALLOWED) PASS=$((PASS+1)) ;;
    DENIED) DENIED=$((DENIED+1)) ;;
    WARN) WARN=$((WARN+1)) ;;
    *) UNKNOWN=$((UNKNOWN+1)) ;;
  esac
  printf '[%-8s] %-26s %s\n' "$status" "$category" "$capability"
}

classify_error(){
  local file="$1"
  if grep -Eqi 'AccessDenied|UnauthorizedOperation|not authorized|explicit deny|blocked by SCP' "$file"; then
    echo DENIED
  elif grep -Eqi 'ExpiredToken|InvalidClientTokenId|UnrecognizedClient|RequestExpired' "$file"; then
    echo CREDENTIALS
  elif grep -Eqi 'not found|NoSuch|does not exist|ResourceNotFound|NotFoundException' "$file"; then
    echo NO_RESOURCE
  elif grep -Eqi 'not available|unsupported|Unknown options|InvalidAction' "$file"; then
    echo UNSUPPORTED
  else
    echo UNKNOWN
  fi
}

probe(){
  local category="$1" name="$2"; shift 2
  local slug
  slug="$(printf '%s-%s' "$category" "$name" | tr '[:upper:] /:' '[:lower:]---' | tr -cd 'a-z0-9_.-')"
  local out="$OUT/raw/$slug.out" err="$OUT/raw/$slug.err"
  if "$@" >"$out" 2>"$err"; then
    record "$category" "$name" PASS "Chamada executada com sucesso"
    return 0
  fi
  local cls; cls="$(classify_error "$err")"
  case "$cls" in
    DENIED) record "$category" "$name" DENIED "Negado pela autorização efetiva" ;;
    CREDENTIALS) record "$category" "$name" WARN "Sessão ausente ou expirada" ;;
    NO_RESOURCE) record "$category" "$name" PASS "API alcançável; nenhum recurso correspondente" ;;
    UNSUPPORTED) record "$category" "$name" WARN "Operação/serviço indisponível nesta região ou CLI" ;;
    *) record "$category" "$name" UNKNOWN "Falha não classificada; consulte $err" ;;
  esac
  return 1
}

for cmd in aws python3 git sha256sum; do
  if command -v "$cmd" >/dev/null 2>&1; then
    record Local "$cmd" PASS "Executável disponível"
  else
    record Local "$cmd" DENIED "Executável ausente"
  fi
done

IDENTITY_JSON="$OUT/raw/sts-identity.json"
if aws sts get-caller-identity --output json >"$IDENTITY_JSON" 2>"$OUT/raw/sts-identity.err"; then
  ACCOUNT="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["Account"])' "$IDENTITY_JSON")"
  CALLER_ARN="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["Arn"])' "$IDENTITY_JSON")"
  record Identity "sts:GetCallerIdentity" PASS "$CALLER_ARN"
else
  record Identity "sts:GetCallerIdentity" DENIED "Não foi possível identificar a sessão"
  echo "Inicie ou reinicie o Learner Lab e tente novamente." >&2
  exit 3
fi

REGION="$(aws configure get region 2>/dev/null || true)"
REGION="${REGION:-$AWS_DEFAULT_REGION}"
export AWS_DEFAULT_REGION="$REGION"

ROLE_ARN=""
if [[ "$CALLER_ARN" =~ ^arn:aws:sts::([0-9]+):assumed-role/([^/]+)/ ]]; then
  ROLE_ARN="arn:aws:iam::${BASH_REMATCH[1]}:role/${BASH_REMATCH[2]}"
fi

probe S3 ListBuckets aws s3api list-buckets --query 'Buckets[].Name' --output json || true
probe S3 GetAccountPublicAccessBlock aws s3control get-public-access-block --account-id "$ACCOUNT" || true
probe EC2 DescribeRegions aws ec2 describe-regions --region "$REGION" --query 'Regions[].RegionName' --output json || true
probe EC2 DescribeVolumes aws ec2 describe-volumes --region "$REGION" --max-results 5 || true
probe KMS ListAliases aws kms list-aliases --region "$REGION" --limit 10 || true
probe Backup ListBackupVaults aws backup list-backup-vaults --region "$REGION" --max-results 10 || true
probe CloudTrail DescribeTrails aws cloudtrail describe-trails --region "$REGION" || true
probe CloudWatchLogs DescribeLogGroups aws logs describe-log-groups --region "$REGION" --limit 5 || true

if [[ "$MODE" == "full" ]]; then
  probe IAM ListRoles aws iam list-roles --max-items 20 || true
  probe IAM GetAccountSummary aws iam get-account-summary || true
  probe ServiceQuotas ListServices aws service-quotas list-services --region "$REGION" --max-results 20 || true
  probe CloudWatch DescribeAlarms aws cloudwatch describe-alarms --region "$REGION" --max-records 5 || true
  probe EventBridge ListRules aws events list-rules --region "$REGION" --limit 5 || true
  probe SNS ListTopics aws sns list-topics --region "$REGION" || true
  probe SQS ListQueues aws sqs list-queues --region "$REGION" --max-results 5 || true
  probe Lambda ListFunctions aws lambda list-functions --region "$REGION" --max-items 5 || true
  probe DynamoDB ListTables aws dynamodb list-tables --region "$REGION" --limit 5 || true
  probe RDS DescribeDBInstances aws rds describe-db-instances --region "$REGION" --max-records 20 || true
  probe ECR DescribeRepositories aws ecr describe-repositories --region "$REGION" --max-results 5 || true
  probe ECS ListClusters aws ecs list-clusters --region "$REGION" --max-results 5 || true
  probe Config DescribeConfigurationRecorders aws configservice describe-configuration-recorders --region "$REGION" || true
  probe Organizations DescribeOrganization aws organizations describe-organization || true
fi

ACTION_NAMES=(
  s3:ListAllMyBuckets s3:CreateBucket s3:DeleteBucket s3:ListBucket
  s3:GetBucketVersioning s3:PutBucketVersioning s3:GetObject s3:PutObject
  s3:DeleteObject s3:DeleteObjectVersion s3:GetBucketPolicy
  s3:PutBucketPolicy s3:DeleteBucketPolicy s3:GetObjectRetention
  s3:PutObjectRetention s3:GetObjectLockConfiguration s3:PutObjectLockConfiguration
  backup:ListBackupVaults backup:CreateBackupVault backup:DeleteBackupVault
  backup:GetBackupVaultLockConfiguration backup:PutBackupVaultLockConfiguration
  backup:DeleteBackupVaultLockConfiguration kms:ListAliases iam:ListRoles
  ec2:DescribeVolumes ec2:DescribeSnapshots ec2:CreateSnapshot ec2:DeleteSnapshot
)

if [[ -n "$ROLE_ARN" ]]; then
  SIM_OUT="$OUT/raw/iam-simulation.json"
  SIM_ERR="$OUT/raw/iam-simulation.err"
  if aws iam simulate-principal-policy --policy-source-arn "$ROLE_ARN" \
      --action-names "${ACTION_NAMES[@]}" --output json >"$SIM_OUT" 2>"$SIM_ERR"; then
    python3 - "$SIM_OUT" "$SUMMARY" <<'PY'
import csv, json, sys
p, summary = sys.argv[1:]
data = json.load(open(p))
with open(summary, "a", newline="") as f:
    w = csv.writer(f)
    for r in data.get("EvaluationResults", []):
        decision = r.get("EvalDecision", "unknown")
        normalized = decision.lower()
        status = "ALLOWED" if normalized == "allowed" else "DENIED" if "deny" in normalized else "UNKNOWN"
        w.writerow(["IAM-SIMULATION", r.get("EvalActionName", ""), status,
                    "Resultado indicativo; não inclui necessariamente SCP, session policy, boundary, condições ou resource policy"])
PY
    record IAM "SimulatePrincipalPolicy" PASS "Resultado detalhado anexado ao CSV; interpretação indicativa"
  else
    cls="$(classify_error "$SIM_ERR")"
    record IAM "SimulatePrincipalPolicy" "$([[ "$cls" == DENIED ]] && echo DENIED || echo UNKNOWN)" \
      "Simulação indisponível; somente os testes reais sustentam conclusões"
  fi
else
  record IAM "SimulatePrincipalPolicy" UNKNOWN "ARN de role não pôde ser derivado da sessão"
fi

TEMP_BUCKET=""; TEMP_LOCK_BUCKET=""; TEMP_VAULT=""
cleanup(){
  set +e
  if [[ -n "$TEMP_BUCKET" ]]; then
    aws s3api delete-bucket-policy --bucket "$TEMP_BUCKET" >/dev/null 2>&1 || true
    aws s3api list-object-versions --bucket "$TEMP_BUCKET" --output json 2>/dev/null \
      | python3 -c 'import json,sys; d=json.load(sys.stdin); print("\n".join("{}\t{}".format(x["Key"],x["VersionId"]) for k in ("Versions","DeleteMarkers") for x in d.get(k,[])))' 2>/dev/null \
      | while IFS=$'\t' read -r key version; do
          [[ -n "$key" ]] && aws s3api delete-object --bucket "$TEMP_BUCKET" --key "$key" --version-id "$version" >/dev/null 2>&1 || true
        done
    aws s3api delete-bucket --bucket "$TEMP_BUCKET" >/dev/null 2>&1 || true
  fi
  [[ -n "$TEMP_LOCK_BUCKET" ]] && aws s3api delete-bucket --bucket "$TEMP_LOCK_BUCKET" >/dev/null 2>&1 || true
  if [[ -n "$TEMP_VAULT" ]]; then
    aws backup delete-backup-vault-lock-configuration --backup-vault-name "$TEMP_VAULT" --region "$REGION" >/dev/null 2>&1 || true
    aws backup delete-backup-vault --backup-vault-name "$TEMP_VAULT" --region "$REGION" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

if (( WRITE_PROBES == 1 )); then
  echo
  echo "Executando testes reversíveis. Nenhum teste de IAM, EC2 ou recurso faturável será criado."
  suffix="$(date -u +%Y%m%d%H%M%S)-$RANDOM"
  TEMP_BUCKET="cr-access-${ACCOUNT}-${suffix}"
  if probe S3 "CreateBucket(actual)" aws s3api create-bucket --bucket "$TEMP_BUCKET"; then
    probe S3 "PutBucketVersioning(actual)" aws s3api put-bucket-versioning --bucket "$TEMP_BUCKET" \
      --versioning-configuration Status=Enabled || true
    printf 'capability-test\n' > "$OUT/probe.txt"
    VID="$(aws s3api put-object --bucket "$TEMP_BUCKET" --key probe.txt --body "$OUT/probe.txt" --query VersionId --output text 2>"$OUT/raw/s3-put.err" || true)"
    if [[ -n "$VID" && "$VID" != None ]]; then
      record S3 "PutObject(actual)" PASS "VersionId=$VID"
      if aws s3api delete-object --bucket "$TEMP_BUCKET" --key probe.txt --version-id "$VID" >"$OUT/raw/s3-delete-version.out" 2>"$OUT/raw/s3-delete-version.err"; then
        record S3 "DeleteObjectVersion(actual)" PASS "Versão de teste removida"
      else
        record S3 "DeleteObjectVersion(actual)" DENIED "Operação essencial do cenário do Grupo B bloqueada"
      fi
    else
      record S3 "PutObject(actual)" DENIED "Upload/versionamento falhou"
    fi
    cat > "$OUT/harmless-policy.json" <<EOF
{"Version":"2012-10-17","Statement":[{"Sid":"CapabilityProbe","Effect":"Deny","Principal":"*","Action":"s3:DeleteObjectVersion","Resource":"arn:aws:s3:::$TEMP_BUCKET/*","Condition":{"StringEquals":{"aws:PrincipalAccount":"000000000000"}}}]}
EOF
    probe S3 "PutBucketPolicy(actual)" aws s3api put-bucket-policy --bucket "$TEMP_BUCKET" --policy "file://$OUT/harmless-policy.json" || true
    probe S3 "DeleteBucketPolicy(actual)" aws s3api delete-bucket-policy --bucket "$TEMP_BUCKET" || true
  fi

  TEMP_LOCK_BUCKET="cr-lockprobe-${ACCOUNT}-${suffix}"
  if probe S3 "CreateBucketObjectLock(actual)" aws s3api create-bucket --bucket "$TEMP_LOCK_BUCKET" --object-lock-enabled-for-bucket; then
    record S3 "ObjectLock" PASS "Bucket vazio criado com Object Lock; será removido sem criar objeto retido"
  else
    record S3 "ObjectLock" DENIED "Bloqueado no Learner Lab; não contornar"
    TEMP_LOCK_BUCKET=""
  fi

  TEMP_VAULT="cr-access-$suffix"
  if probe Backup "CreateBackupVault(actual)" aws backup create-backup-vault --backup-vault-name "$TEMP_VAULT" --region "$REGION"; then
    if probe Backup "PutVaultLock(actual)" aws backup put-backup-vault-lock-configuration \
      --backup-vault-name "$TEMP_VAULT" --min-retention-days 1 --changeable-for-days 3 --region "$REGION"; then
      probe Backup "DeleteVaultLock(actual)" aws backup delete-backup-vault-lock-configuration \
        --backup-vault-name "$TEMP_VAULT" --region "$REGION" || true
    fi
  else
    TEMP_VAULT=""
  fi
fi

read -r PASS_TOTAL DENIED_TOTAL WARN_TOTAL UNKNOWN_TOTAL < <(
  python3 - "$SUMMARY" <<'PY'
import csv, sys
c = {"PASS": 0, "DENIED": 0, "WARN": 0, "UNKNOWN": 0}
with open(sys.argv[1], newline="") as f:
    for row in csv.DictReader(f):
        status = row.get("status", "UNKNOWN")
        if status == "ALLOWED": status = "PASS"
        c[status if status in c else "UNKNOWN"] += 1
print(c["PASS"], c["DENIED"], c["WARN"], c["UNKNOWN"])
PY
)

cat > "$REPORT" <<EOF
# Relatório de capacidades AWS — Cyber Recovery

- Data UTC: $timestamp
- Conta: $ACCOUNT
- Região: $REGION
- Identidade: \`$CALLER_ARN\`
- Role derivada: \`${ROLE_ARN:-não derivada}\`
- Modo: $MODE
- Testes de escrita reversíveis: $WRITE_PROBES

## Resultado

| Métrica | Quantidade |
|---|---:|
| PASS/ALLOWED | $PASS_TOTAL |
| DENIED | $DENIED_TOTAL |
| WARN | $WARN_TOTAL |
| UNKNOWN | $UNKNOWN_TOTAL |

O inventário detalhado está em \`access-summary.csv\` e as respostas brutas em \`raw/\`.

## Limites de interpretação

1. Não existe uma chamada AWS que enumere, com certeza, "tudo o que a sessão pode fazer".
2. A simulação IAM pode não refletir SCP, session policy, permissions boundary, condições e políticas baseadas em recurso.
3. Uma chamada de leitura bem-sucedida não prova autorização para criar, alterar ou excluir recursos.
4. \`AccessDenied\` registra uma restrição do ambiente; não autoriza tentativas de contorno.
5. Somente um teste real, controlado e reversível confirma a combinação identidade + ação + recurso + condição.
EOF

echo
echo "Relatório: $REPORT"
echo "Matriz CSV: $SUMMARY"
echo "PASS/ALLOWED=$PASS_TOTAL DENIED=$DENIED_TOTAL WARN=$WARN_TOTAL UNKNOWN=$UNKNOWN_TOTAL"

# Para o laboratório, STS e S3 básico precisam funcionar. Restrições opcionais não falham o script.
if ! grep -q '"Identity","sts:GetCallerIdentity","PASS"' "$SUMMARY" || \
   ! grep -q '"S3","ListBuckets","PASS"' "$SUMMARY"; then
  exit 4
fi
