# Grupo A — Operação Fênix
## Barreira operacional, recovery points e domínio administrativo

> **Percurso:** Aula 1 (3h) e Aula 2 (3h) consecutivas. Conteúdo seguinte assíncrono.

Antes de começar, leia:

- [Conceitos essenciais](../docs/01-conceitos-essenciais.md);
- [Plano de aprendizagem](../docs/02-plano-de-aprendizagem.md).

# AULA 1 — PREPARE / BUILD / PROVE (3h)

> **Duração planejada:** 180 minutos  
> **Formato:** Game Day / PBL  
> **Objetivo da aula:** terminar com uma capacidade mínima de recovery **construída, testada, medida e criticada**.

---


## Cronograma-alvo

| Etapa | Tempo |
|---|---:|
| Formação da equipe | 10 min |
| Reconhecimento cloud | 15 min |
| Inicialização | 10 min |
| Dependências e criticidade | 20 min |
| Construção do recovery domain | 20 min |
| Conceitos S3/cloud | 10 min |
| História de recovery points | 20 min |
| Versioning/delete markers | 15 min |
| Bucket Policy e teste seguro | 15 min |
| Recovery rehearsal | 20 min |
| RPO/RTO/RTA | 10 min |
| Readiness review e defesa | 15 min |
| **Total** | **180 min** |

> Se uma equipe terminar uma etapa antes, ela avança para as perguntas de aprofundamento daquela seção; não deve pular diretamente para a próxima missão sem registrar as evidências pedidas.

---

## Regra desta aula

Este roteiro não foi feito para ser executado de ponta a ponta copiando comandos.

Em vários pontos você receberá:

- uma **missão**;
- um **critério de sucesso**;
- uma **dica Nível 1**;
- e, somente se necessário, uma **dica Nível 2 com comando**.

A equipe deve registrar no arquivo:

```text
evidencias/diario-aula1.md
```

as decisões e evidências pedidas.

Crie-o agora:

```bash
mkdir -p ~/cyber-recovery-a/evidencias 2>/dev/null || true
touch ~/cyber-recovery-a/evidencias/diario-aula1.md 2>/dev/null || true
```

---

# 0. Formação da Cyber Recovery Cell — 10 min

Distribuam funções:

- **Incident/Recovery Lead**
- **Cloud Engineer**
- **Evidence Lead**
- **Application Owner**
- opcional: **Security Analyst**
- opcional: **Scribe**

Registrem os nomes/funções.

A equipe pode trocar papéis após 90 minutos.

---

# 1. Reconhecimento Cloud — 15 min

## Missão

Sem criar recursos ainda, descubram:

1. qual conta AWS estão usando;
2. qual região;
3. qual identidade/role;
4. se a sessão parece temporária;
5. quais buckets já existem;
6. qual é a diferença entre **Account**, **Region**, **ARN**, **Role** e **Session**.

### Critério de sucesso

Entregar uma tabela:

| Item | Valor observado | O que significa |
|---|---|---|
| Account | | |
| Region | | |
| ARN | | |
| Role | | |
| Session name | | |
| Credencial permanente? | | |

### Dica Nível 1

Procurem comandos `sts`, `configure` e `s3api`.

### Dica Nível 2

```bash
aws sts get-caller-identity
aws configure get region
aws s3api list-buckets --query 'Buckets[].Name'
```

### Questão

> Se a mesma role puder administrar produção e recovery, qual é o possível **blast radius** de uma credencial comprometida?

Registrem a hipótese. Não é necessário saber ainda a resposta definitiva.

---

# 2. Inicializar o laboratório — 10 min

No repositório:

```bash
chmod +x student-kit/*.sh

./student-kit/student_preflight.sh
./student-kit/bootstrap.sh A

source ~/cyber-recovery-a/.lab.env
cp "$LAB_REPO_ROOT/student-kit/create_dataset.sh" "$LAB_WORK/"
cp "$LAB_REPO_ROOT/student-kit/seed_recovery_history.sh" "$LAB_WORK/"
cp "$LAB_REPO_ROOT/student-kit/validate_recovery.py" "$LAB_WORK/"

cd "$LAB_WORK"

chmod +x create_dataset.sh seed_recovery_history.sh
./create_dataset.sh
```

---

# 3. Entender o serviço antes de protegê-lo — 20 min

Vocês receberam seis artefatos:

```text
identity.json
dns.json
config.ini
clientes.csv
pedidos.json
recovery-metadata.json
```

## Missão A — Dependências

Construam um grafo simples:

```text
IDENTITY ---> ?
DNS -------> ?
CONFIG ----> ?
CLIENTES --> ?
PEDIDOS ---> ?
```

A pergunta não é “qual arquivo é mais importante?”, mas:

> **Qual precisa existir antes de qual para o serviço poder voltar?**

## Missão B — Classificação

Para cada ativo, atribuam:

- Tier 0 / plataforma / aplicação / dado / recovery metadata;
- criticidade: alta / média / baixa;
- tolerância de perda de dados;
- ordem de restauração.

### Critério de sucesso

Produzir no `diario-aula1.md`:

```text
ORDEM DE RECUPERAÇÃO PROPOSTA:
1.
2.
3.
4.
5.

JUSTIFICATIVA:
```

### Desafio

O arquivo `recovery-metadata.json` já contém uma ordem sugerida.

Vocês concordam com ela?

```bash
cat producao/recovery-metadata.json
```

Não aceitem automaticamente o que está no arquivo.

---

# 4. Construir o recovery domain — 20 min

## Requisito

Criar um bucket S3 para o Grupo A que:

1. tenha nome único;
2. esteja associado à conta do laboratório;
3. tenha versionamento habilitado;
4. seja verificável por AWS CLI;
5. seja registrado em `evidencias/bucket.txt`.

Vocês já conhecem os elementos necessários da aula anterior/roteiro.

### Critério de sucesso

Os comandos abaixo precisam produzir evidência coerente:

```bash
cat evidencias/bucket.txt
aws s3api get-bucket-versioning --bucket "$BUCKET"
```

### Dica Nível 1

O nome previsto pelo laboratório começa com:

```text
cr-a-
```

### Dica Nível 2

```bash
BUCKET="cr-a-${LAB_ACCOUNT}-${LAB_SUFFIX}"
echo "$BUCKET" | tee evidencias/bucket.txt
printf "export BUCKET='%s'\n" "$BUCKET" >> "$LAB_WORK/.lab.env"
aws s3api create-bucket --bucket "$BUCKET"
aws s3api put-bucket-versioning \
  --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
```

---

# 5. Conceito Cloud: o que o S3 está realmente fazendo? — 10 min

Antes de continuar, respondam em grupo.

### Questão 1

Quando fazemos:

```bash
aws s3api put-object
```

o objeto fica “dentro de uma pasta”?

### Questão 2

Qual a diferença entre:

```text
bucket
key
prefix
object
VersionId
```

### Questão 3

S3 pertence a uma VPC?

### Questão 4

Observem um objeto após o primeiro upload da próxima etapa e identifiquem:

- `VersionId`
- `ETag`
- `ServerSideEncryption`
- `ContentLength`
- `LastModified`

O que cada um prova — e o que **não** prova?

---

# 6. Criar uma história de recovery points — 20 min

Até agora vocês tinham apenas um estado.

Cyber Recovery real exige escolher entre **vários pontos possíveis**.

Execute:

```bash
./seed_recovery_history.sh "$BUCKET" vault
```

O script cria quatro recovery points sucessivos do ERP.

Ele **não informa qual vocês deverão restaurar durante o incidente da Aula 2**.

Depois:

```bash
aws s3api list-object-versions \
  --bucket "$BUCKET" \
  --prefix vault/ \
  --output table
```

e:

```bash
cat evidencias/recovery-points.csv
```

## Missão

Construam esta tabela:

| Recovery Point | Momento | Pedidos | Total financeiro | VersionId de pedidos | Comentário |
|---|---|---:|---:|---|---|
| RP01 | | | | | |
| RP02 | | | | | |
| RP03 | | | | | |
| RP04 | | | | | |

### Perguntas

1. Qual é o recovery point mais recente?
2. Qual apresenta menor perda de dados?
3. Isso significa que ele será necessariamente o mais confiável?
4. Qual seria o RPO se o incidente acontecesse 20 minutos após RP04?
5. `LastModified` é suficiente para decidir confiança?

---

# 7. Laboratório de Versioning: delete marker × destruição real — 15 min

Agora vocês vão testar em um **objeto sacrificial**, não nos dados do ERP.

Crie:

```bash
echo "VERSAO-1" > /tmp/lab-delete.txt

VID1=$(aws s3api put-object \
  --bucket "$BUCKET" \
  --key sandbox/lab-delete.txt \
  --body /tmp/lab-delete.txt \
  --query VersionId --output text)

echo "VERSAO-2" > /tmp/lab-delete.txt

VID2=$(aws s3api put-object \
  --bucket "$BUCKET" \
  --key sandbox/lab-delete.txt \
  --body /tmp/lab-delete.txt \
  --query VersionId --output text)
```

Agora:

```bash
aws s3api delete-object \
  --bucket "$BUCKET" \
  --key sandbox/lab-delete.txt
```

## Missão

Sem apagar as versões ainda, descubram:

- o que apareceu;
- qual versão ainda existe;
- se um `GET` normal funciona;
- se um `GET` pelo `VersionId` antigo funciona.

### Evidência

```bash
aws s3api list-object-versions \
  --bucket "$BUCKET" \
  --prefix sandbox/lab-delete.txt
```

### Pergunta-chave

> **Excluir o nome lógico do objeto é o mesmo que destruir uma versão?**

---

# 8. Aplicar a barreira operacional do Grupo A — 15 min

Agora protejam o prefixo do laboratório contra:

```text
s3:DeleteObjectVersion
```

usando uma **Bucket Policy**.

### Requisito

A policy deve negar a destruição permanente de versões do bucket.

### Dica Nível 1

Trata-se de uma **resource-based policy**.

### Dica Nível 2

```bash
cat > evidencias/protect-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "DenyPermanentVersionDeletion",
    "Effect": "Deny",
    "Principal": "*",
    "Action": "s3:DeleteObjectVersion",
    "Resource": "arn:aws:s3:::$BUCKET/*"
  }]
}
EOF

aws s3api put-bucket-policy \
  --bucket "$BUCKET" \
  --policy file://evidencias/protect-policy.json
```

### Teste seguro

Tentem apagar **VID1 do objeto sacrificial**:

```bash
aws s3api delete-object \
  --bucket "$BUCKET" \
  --key sandbox/lab-delete.txt \
  --version-id "$VID1"
```

Registrem a saída.

### Discussão

Não usem ainda a palavra “imutável”.

Completem:

```text
O controle impediu:
O controle NÃO provou:
A identidade que administra a policy é:
```

---

# 9. Recovery Rehearsal sorteado — 20 min

A equipe não escolherá simplesmente “o último”.

Escolha um recovery point aleatoriamente:

```bash
RP=$((1 + RANDOM % 4))
printf -v RP_NAME "RP%02d" "$RP"
echo "Recovery Point sorteado: $RP_NAME"
```

Localizem os VersionIds correspondentes em:

```bash
evidencias/recovery-points.csv
```

Criem:

```bash
rm -rf rehearsal
mkdir rehearsal
```

Recuperem pelo menos:

```text
identity.json
dns.json
config.ini
pedidos.json
```

**pelos VersionIds do recovery point sorteado**.

Depois validem:

1. arquivos existem;
2. JSON é válido;
3. dependências fazem sentido;
4. número e total dos pedidos correspondem àquele recovery point.

### Critério de sucesso

A equipe deve conseguir explicar:

> “Restauramos RPxx porque utilizamos explicitamente os VersionIds ..., e não porque eram os objetos `Latest`.”

---

# 10. RPO, RTO, RTA e readiness — 10 min

Calculem/definam:

### RPO declarado

Obtenham de:

```bash
cat producao/recovery-metadata.json
```

### RPO observado

Considere:

```text
Incidente hipotético: 20 minutos após RP04.
```

Qual seria o RPO?

### RTO declarado

Também está nos metadados.

### RTO observado no rehearsal

Meçam uma restauração de quatro objetos.

Pergunta:

> O tempo medido é realmente RTO do ERP ou apenas tempo técnico de restore?

Introduza a distinção:

- **RTO** — objetivo;
- **RTA / tempo observado** — capacidade medida no exercício;
- recuperação técnica ≠ retorno do serviço.

---

# 11. Recovery Readiness Review — 15 min

A equipe tem 7 minutos para preparar e 3 minutos para defender.

Preencham:

```text
RECOVERY READINESS CARD

Conta/role:
Recovery domain:
Versioning:
Recovery points disponíveis:
Último recovery point:
RPO declarado:
RTO declarado:
Restore testado:
Integridade verificável:
Tier 0 identificado:
Proteção contra DeleteObjectVersion:
Mesmo domínio administrativo?:
Maior risco:
Maior hipótese ainda não testada:
```

## Perguntas de defesa

O professor poderá escolher três:

1. Se a policy for removida, o que muda?
2. Bucket separado significa isolamento administrativo?
3. Versioning é imutabilidade?
4. SHA-256 prova que não há malware?
5. O manifesto também precisa ser protegido?
6. Qual ativo deve voltar primeiro?
7. Último recovery point é sempre o melhor?
8. Qual evidência prova que vocês conseguem restaurar?
9. Qual dependência pode tornar um restore tecnicamente correto mas funcionalmente inútil?
10. O que vocês ainda não sabem sobre a capacidade de Cyber Recovery?

---

# Fim da Aula 1

**Não destruam o bucket.**

Na Aula 2 este ambiente será usado em um incidente.

Salvem:

```bash
cat evidencias/bucket.txt
cat evidencias/recovery-points.csv
```

e mantenham o diretório:

```text
~/cyber-recovery-a
```

A Aula 2 começará com uma mudança de contexto: vocês deixarão de ser arquitetos e passarão a operar como equipe de recuperação durante um incidente.

Prossiga diretamente para a Aula 2. Não execute atividade assíncrona entre os dois encontros e não altere o estado do laboratório fora das instruções do jogo.

---

# AULA 2 — INCIDENT / RECOVER / WAR ROOM (3h)

Esta aula começa imediatamente após a Aula 1. O estado necessário foi construído durante o primeiro encontro; nenhuma atividade assíncrona é esperada entre as aulas.

## Cronograma

| Etapa | Tempo |
|---|---:|
| Retomada, incidente e critérios de retorno | 15 min |
| Ataque controlado e investigação | 25 min |
| Recuperação e validação | 20 min |
| Injects e revisão da decisão | 20 min |
| Defesa do Grupo A e auditoria do Grupo B | 30 min |
| Defesa do Grupo B e auditoria do Grupo A | 30 min |
| Redesenho e post-mortem | 25 min |
| Consolidação, entrega e cleanup | 15 min |
| **Total** | **180 min** |

## 1. Retomar o ambiente e receber o incidente — 15 min

```bash
source ~/cyber-recovery-a/.lab.env
cd "$LAB_WORK"
aws sts get-caller-identity
date -u +"%Y-%m-%dT%H:%M:%SZ" | tee evidencias/incident-time.txt
```

Confirme que existem:

- `evidencias/recovery-points.csv`;
- `evidencias/protect-policy.json`;
- manifestos RP01–RP04;
- evidência do rehearsal da Aula 1.

O professor apresentará o incidente. Antes de restaurar, registre:

```text
CRITÉRIOS MÍNIMOS PARA RETORNO:
1.
2.
3.

CONDIÇÃO DE NO-GO:
```

## 2. Ataque controlado e investigação — 25 min

Simule a corrupção local:

```bash
cat > producao/config.ini <<'EOF'
[SISTEMA]
status=COMPROMETIDO
endpoint=malicious-endpoint
EOF

printf 'ARQUIVO_CRIPTOGRAFADO\nRANSOMWARE-DEMO\n' > producao/clientes.csv
```

Crie versões maliciosas no caminho do cofre e um delete marker:

```bash
aws s3 cp producao/config.ini "s3://$BUCKET/vault/config.ini"
aws s3 cp producao/clientes.csv "s3://$BUCKET/vault/clientes.csv"
aws s3api delete-object --bucket "$BUCKET" --key vault/pedidos.json
```

Teste a barreira usando a versão de `pedidos.json` do RP04:

```bash
VID_PEDIDOS_RP04=$(awk -F, '$1=="RP04" && $3=="pedidos.json"{print $4}' \
  evidencias/recovery-points.csv)

aws s3api delete-object \
  --bucket "$BUCKET" \
  --key vault/pedidos.json \
  --version-id "$VID_PEDIDOS_RP04" \
  2>&1 | tee evidencias/delete-version-attack.txt
```

A exclusão deve ser negada enquanto a Bucket Policy existir. Registre o erro completo.

Investigue:

```bash
aws s3api list-object-versions \
  --bucket "$BUCKET" --prefix vault/ \
  | tee evidencias/incident-versions.json
```

Escolha um recovery point e justifique por evidência; não use `Latest` como critério suficiente.

## 3. Recuperar e validar — 20 min

Defina o ponto selecionado:

```bash
RP_NAME="RP04"   # altere se a análise justificar outro ponto
mkdir -p clean-room
```

Restaure as versões registradas:

```bash
for ARQ in identity.json dns.json config.ini clientes.csv pedidos.json recovery-metadata.json; do
  VID=$(awk -F, -v rp="$RP_NAME" -v arq="$ARQ" \
    '$1==rp && $3==arq{print $4}' evidencias/recovery-points.csv)

  aws s3api get-object \
    --bucket "$BUCKET" \
    --key "vault/$ARQ" \
    --version-id "$VID" \
    "clean-room/$ARQ"
done

MVID=$(awk -F, -v rp="$RP_NAME" \
  '$1==rp && $3==("manifest-" rp ".sha256"){print $4}' \
  evidencias/recovery-points.csv)

aws s3api get-object \
  --bucket "$BUCKET" \
  --key "vault/manifests/manifest-${RP_NAME}.sha256" \
  --version-id "$MVID" \
  clean-room/manifest.sha256
```

Valide:

```bash
cd clean-room
sha256sum -c manifest.sha256 \
  2>&1 | tee ../evidencias/hash-validation-aula2.txt
cd ..

python3 validate_recovery.py clean-room \
  2>&1 | tee evidencias/functional-validation-aula2.txt
```

Classifique cada gate como `PASS`, `FAIL` ou `INCONCLUSIVO`.

## 4. Injects e revisão da decisão — 20 min

O professor apresentará evidências adicionais sobre domínio administrativo e dwell time.

Quando autorizado, teste se a mesma identidade remove a proteção:

```bash
aws s3api get-bucket-policy --bucket "$BUCKET"
aws s3api delete-bucket-policy --bucket "$BUCKET"
```

**Não exclua uma versão boa depois da remoção da policy.** Reaplique o controle para preservar o ambiente até o cleanup:

```bash
aws s3api put-bucket-policy \
  --bucket "$BUCKET" \
  --policy file://evidencias/protect-policy.json
```

Revise a decisão:

```text
DECISÃO: GO / NO-GO / GO COM RISCO ACEITO
Recovery point:
Evidências favoráveis:
Evidências contrárias:
RPO observado:
Risco residual:
O que refutaria esta decisão:
Quem autoriza o retorno:
```

## 5. War Room — 60 min

### Defesa do Grupo A — 15 min

Apresente arquitetura, timeline, ponto selecionado, validações, decisão e risco residual.

### Auditoria do Grupo B — 15 min

O Grupo B deve questionar evidências e pressupostos, não apenas sugerir controles.

### Defesa do Grupo B — 15 min

Observe como a perda de uma versão altera a capacidade de recuperação.

### Auditoria do Grupo A — 15 min

Perguntas obrigatórias:

- Qual evidência refutaria a decisão?
- O manifesto pertence à mesma cadeia de confiança?
- Como foi delimitada a janela de comprometimento?
- Qual dependência Tier 0 pode invalidar o restore?
- Quem autoriza o retorno?

## 6. Redesenho e post-mortem — 25 min

Revise a arquitetura com:

- domínio de recovery separado;
- identidade administrativa segregada;
- WORM;
- chaves sobreviventes ao comprometimento de produção;
- logs/evidências independentes;
- break-glass;
- clean room;
- gates técnicos e de negócio.

Para cada controle, declare:

```text
ameaça reduzida | responsável | evidência | limitação
```

## 7. Entrega e cleanup — 15 min

Finalize `templates/incident-report.md` e preserve a decisão original da War Room.

Depois da autorização do professor:

```bash
source ~/cyber-recovery-a/.lab.env
"$LAB_REPO_ROOT/student-kit/cleanup_bucket.sh" "$BUCKET"
```

As [atividades assíncronas complementares](trilha-assincrona.md) podem ser feitas posteriormente e não alteram o resultado oficial do jogo.
