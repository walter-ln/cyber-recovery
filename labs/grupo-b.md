# Grupo B — Operação Fênix
## Backup versionado: quando a versão necessária deixa de existir

> **Percurso:** Aula 1 (3h) e Aula 2 (3h) consecutivas; 5h assíncronas apenas como complemento  
> **Papel:** Cyber Recovery Cell da ACME Brasil

Antes de começar, leia:

- [Conceitos essenciais](../docs/01-conceitos-essenciais.md);
- [Plano de aprendizagem](../docs/02-plano-de-aprendizagem.md).

## Missão

A ACME possui backup versionado.

A equipe acredita que isso é suficiente contra ransomware.

Vocês deverão testar essa hipótese.

---

# AULA 1 — PREPARE / BUILD / PROVE

## Cronograma da Aula 1

| Etapa | Tempo |
|---|---:|
| Conceitos, cenário, papéis e critérios de evidência | 60 min |
| Preflight, bootstrap e dataset | 35 min |
| Bucket, versionamento e recovery point | 45 min |
| Rehearsal, análise e relatório preliminar | 40 min |
| **Total** | **180 min** |

## Missão 1 — entrar na nuvem

```bash
cd ~
git clone https://github.com/walter-ln/cyber-recovery.git
cd ~/cyber-recovery
chmod +x student-kit/*.sh
./student-kit/student_preflight.sh
./student-kit/bootstrap.sh B
source ~/cyber-recovery-b/.lab.env
```

```bash
aws sts get-caller-identity
```

Registre Account, ARN e Region.

### Checkpoint Cloud 1

- O que é uma role assumida?
- O que acontece se essa sessão for comprometida?
- Onde está o limite entre autenticação e autorização?

---

## Missão 2 — criar o serviço

```bash
cp student-kit/create_dataset.sh "$LAB_WORK/"
cd "$LAB_WORK"
chmod +x create_dataset.sh
./create_dataset.sh
```

Leia:

```bash
cat producao/recovery-metadata.json
cat evidencias/manifest.sha256
```

Classifique dependências Tier 0 e dados operacionais.

---

## Missão 3 — criar o backup

```bash
BUCKET="cr-b-${LAB_ACCOUNT}-${LAB_SUFFIX}"
echo "$BUCKET" | tee evidencias/bucket.txt
printf "export BUCKET='%s'\n" "$BUCKET" >> "$LAB_WORK/.lab.env"

aws s3api create-bucket --bucket "$BUCKET"

aws s3api put-bucket-versioning \
  --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
```

### Checkpoint Cloud 2

Explique:

- bucket;
- object;
- key;
- prefix;
- `VersionId`;
- delete marker.

---

## Missão 4 — recovery point

```bash
rm -f evidencias/versions.csv

for ARQ in identity.json dns.json config.ini clientes.csv pedidos.json recovery-metadata.json; do
  VID=$(aws s3api put-object \
    --bucket "$BUCKET" \
    --key "backup/$ARQ" \
    --body "producao/$ARQ" \
    --query VersionId --output text)
  echo "$ARQ,$VID" | tee -a evidencias/versions.csv
done

VID_MANIFEST=$(aws s3api put-object \
  --bucket "$BUCKET" \
  --key backup/manifest.sha256 \
  --body evidencias/manifest.sha256 \
  --query VersionId --output text)

echo "manifest.sha256,$VID_MANIFEST" >> evidencias/versions.csv

date -u +"%Y-%m-%dT%H:%M:%SZ" \
  | tee evidencias/restore-point-time.txt
```

---

## Missão 5 — rehearsal

Recupere um objeto por VersionId:

```bash
mkdir -p rehearsal
VID=$(awk -F, '$1=="dns.json"{print $2}' evidencias/versions.csv)

aws s3api get-object \
  --bucket "$BUCKET" \
  --key backup/dns.json \
  --version-id "$VID" \
  rehearsal/dns.json
```

### Pergunta

> Se o restore funcionou agora, o que ainda pode fazer a recuperação falhar durante um incidente?

---

## Entrega da Aula 1

```text
RECOVERY READINESS CARD
Account/ARN:
Region:
Bucket:
Recovery Point:
RPO declarado:
RTO declarado:
Dependências Tier 0:
Proteção contra exclusão de VersionId:
Maior risco conhecido:
Uma coisa ainda não provada:
```

Pare aqui.

Prossiga diretamente para a Aula 2. Não execute atividade assíncrona entre os dois encontros e não altere o estado do laboratório fora das instruções do jogo.

---

# AULA 2 — INCIDENT / RECOVER / DECIDE

Esta aula começa imediatamente após a Aula 1. Nenhuma entrega assíncrona é necessária para iniciar ou concluir o incidente.

## Cronograma da Aula 2

| Etapa | Tempo |
|---|---:|
| Retomada e abertura do incidente | 10 min |
| Ataque controlado e investigação | 40 min |
| Clean room, validação e decisão | 40 min |
| Defesas e auditorias cruzadas dos dois grupos | 60 min |
| Redesenho e post-mortem | 20 min |
| Entrega e cleanup | 10 min |
| **Total** | **180 min** |

## INC-CR-001

> O ERP está indisponível e há sinais de ransomware. Produção é considerada não confiável.

```bash
date -u +"%Y-%m-%dT%H:%M:%SZ" \
  | tee evidencias/incident-time.txt
```

Defina critérios mínimos para retorno.

---

## Missão 6 — comprometer produção

```bash
cat > producao/config.ini <<'EOF'
[SISTEMA]
status=COMPROMETIDO
endpoint=malicious-endpoint
EOF

cat > producao/clientes.csv <<'EOF'
ARQUIVO_CRIPTOGRAFADO
RANSOMWARE-DEMO
EOF

cat > producao/identity.json <<'EOF'
{
  "service": "identity",
  "tier": 0,
  "state": "COMPROMETIDO",
  "generation": 43
}
EOF

rm -f producao/pedidos.json
```

---

## INJECT — identidade de backup comprometida

Crie versões maliciosas:

```bash
aws s3 cp producao/config.ini "s3://$BUCKET/backup/config.ini"
aws s3 cp producao/clientes.csv "s3://$BUCKET/backup/clientes.csv"
aws s3 cp producao/identity.json "s3://$BUCKET/backup/identity.json"
```

Exclusão normal:

```bash
aws s3api delete-object \
  --bucket "$BUCKET" \
  --key backup/pedidos.json
```

---

## Missão 7 — investigação

```bash
aws s3api list-object-versions \
  --bucket "$BUCKET" \
  --prefix backup/ \
  | tee evidencias/incident-versions.json
```

Construa:

```text
objeto | VersionId | LastModified | Latest? | delete marker? | hipótese
```

### Checkpoint

> A exclusão sem `--version-id` destruiu necessariamente o dado?

---

## Missão 8 — ataque destrutivo

Obtenha a versão conhecida como boa:

```bash
VID_PEDIDOS=$(awk -F, '$1=="pedidos.json"{print $2}' evidencias/versions.csv)
echo "$VID_PEDIDOS"
```

Agora execute:

```bash
aws s3api delete-object \
  --bucket "$BUCKET" \
  --key backup/pedidos.json \
  --version-id "$VID_PEDIDOS" \
  | tee evidencias/delete-version.json
```

Confirme:

```bash
aws s3api list-object-versions \
  --bucket "$BUCKET" \
  --prefix backup/pedidos.json \
  | tee evidencias/pedidos-after-delete.json
```

### Checkpoint crítico

> Havia backup? Havia versionamento? Por que isso não evitou a perda do recovery point?

---

## Missão 9 — clean room

Inicie o tempo:

```bash
date +%s > evidencias/recovery-start.epoch
rm -rf clean-room
mkdir clean-room
```

Tente seguir a ordem:

1. identity;
2. DNS;
3. config;
4. clientes;
5. pedidos;
6. recovery metadata;
7. manifesto.

Para cada item:

```bash
ARQ="identity.json"
VID=$(awk -F, -v a="$ARQ" '$1==a{print $2}' evidencias/versions.csv)

aws s3api get-object \
  --bucket "$BUCKET" \
  --key "backup/$ARQ" \
  --version-id "$VID" \
  "clean-room/$ARQ"
```

Repita para os demais.

Quando chegar a `pedidos.json`, registre a falha.

**Não recrie o arquivo manualmente.**

---

## Missão 10 — validar

Recupere também o manifesto se ainda não fez.

```bash
cd clean-room
sha256sum -c manifest.sha256 \
  2>&1 | tee ../evidencias/hash-validation.txt
cd ..
```

```bash
cp "$LAB_REPO_ROOT/student-kit/validate_recovery.py" .
python3 validate_recovery.py clean-room \
  2>&1 | tee evidencias/functional-validation.txt
```

### Pergunta

> O validador falhar significa que o processo falhou ou que ele funcionou corretamente ao impedir um falso “GO”?

---

## INJECT — dwell time

> A primeira atividade suspeita ocorreu 12 dias antes. O recovery point foi criado ontem.

Mesmo se `pedidos.json` existisse:

- hash válido significaria clean copy?
- qual seria a sua confiança?
- que evidência de segurança deveria entrar no gate?

---

## Missão 11 — medir

Finalize quando a equipe conseguir **determinar o estado recuperável**:

```bash
date +%s > evidencias/recovery-end.epoch

START=$(cat evidencias/recovery-start.epoch)
END=$(cat evidencias/recovery-end.epoch)

echo "Tempo para determinar estado recuperavel: $((END-START)) segundos" \
  | tee evidencias/rto-investigative.txt

TBACKUP=$(date -d "$(cat evidencias/restore-point-time.txt)" +%s)
TINC=$(date -d "$(cat evidencias/incident-time.txt)" +%s)

echo "RPO observado: $((TINC-TBACKUP)) segundos" \
  | tee evidencias/rpo.txt
```

### Atenção

Não declare “RTO atingido” se o serviço não foi recuperado integralmente.

---

## Missão final — decisão

Escolha:

```text
GO
NO-GO
GO COM RISCO ACEITO
```

Justifique com evidências.

Perguntas obrigatórias:

1. `Latest` era o estado correto?
2. O VersionId confiável ainda existia?
3. O manifesto estava disponível?
4. O conjunto estava completo?
5. Tier 0 foi recuperável?
6. O validador funcional aprovou?
7. Há base técnica para retorno?

---

## War Room — defesa e auditoria

A equipe terá 15 minutos para apresentar:

1. arquitetura executada;
2. timeline do incidente;
3. VersionId destruído;
4. impacto sobre completude e validação;
5. RPO e tempo observado;
6. decisão final;
7. risco residual e arquitetura-alvo.

Depois, o Grupo A terá 15 minutos para auditar a decisão. Responda sempre com evidência observada ou limite explicitamente o que permanece inconclusivo.

---

## Redesenho

Desenhe a arquitetura que teria alterado o resultado:

- domínio de recovery separado;
- administração segregada;
- WORM;
- proteção de chaves;
- break-glass;
- detecção de corrupção;
- clean room;
- autorização de retorno.

### Regra

“Adicionar outra cópia no mesmo domínio administrativo” não é resposta suficiente.

---

## Entrega

`incident-report.md`:

1. arquitetura as-built;
2. timeline;
3. evidências;
4. VersionId destruído;
5. resultado da clean room;
6. RPO;
7. tempo de investigação/recuperação;
8. GO/NO-GO;
9. arquitetura-alvo;
10. after-action.

### Pergunta final

> **Em que momento o backup deixou de ser uma capacidade de recuperação e passou a ser apenas uma cópia que existia no passado?**

## Cleanup orientado

Somente após entregar o relatório e receber autorização do professor:

```bash
source ~/cyber-recovery-b/.lab.env
"$LAB_REPO_ROOT/student-kit/cleanup_bucket.sh" "$BUCKET"
```

Preserve localmente as evidências exigidas para avaliação.

As [atividades assíncronas complementares](trilha-assincrona.md) podem ser realizadas posteriormente e não alteram o resultado oficial do jogo.
