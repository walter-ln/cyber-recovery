# Atividades assíncronas complementares — 5 horas

## Como esta carga se relaciona com o Game Day

O Game Day é realizado e concluído nas duas aulas síncronas consecutivas. Estas cinco horas não são uma fase intermediária do incidente e não são pré-requisito para a Aula 2.

As atividades podem ser realizadas depois do jogo, distribuídas ao longo da disciplina ou combinadas com outras tarefas definidas pelo professor. Salvo orientação expressa, não mantenha recursos AWS ativos apenas para cumprir esta carga.

## Regras

1. Trabalhe com as evidências exportadas ou com cenários locais.
2. Não modifique retroativamente as evidências oficiais do Game Day.
3. Não recrie o incidente oficial nem altere o bucket depois do cleanup.
4. Se uma atividade opcional usar AWS, execute primeiro o preflight e utilize apenas recursos autorizados pelo professor.
5. Não crie IAM users, access keys, roles, NAT Gateway, RDS ou serviços de custo contínuo.

## Organização sugerida

| Atividade | Carga | Produto |
|---|---:|---|
| 1. Análise individual do incidente | 1h | reflexão técnica |
| 2. Mapa de ameaças e controles | 1h | matriz ataque × controle × evidência |
| 3. Melhoria de automação | 1h30 | proposta ou código testado localmente |
| 4. Arquitetura-alvo e custos | 1h | desenho justificado |
| 5. After-action individual | 30 min | plano pessoal de melhoria |
| **Total** | **5h** | aprofundamento complementar |

# Atividade 1 — análise individual do incidente (1h)

Produza uma análise de duas páginas respondendo:

1. Qual foi a diferença entre a arquitetura dos grupos?
2. Qual controle alterou o resultado imediato?
3. Por que Bucket Policy não equivale a WORM?
4. Em que momento `Latest` deixou de ser uma hipótese suficiente?
5. Que evidência sustentou ou impediu o `GO`?
6. O que permaneceu inconclusivo?

Inclua pelo menos três evidências observadas durante o jogo, sem publicar Account ID, ARN completo ou informações da sessão.

# Atividade 2 — mapa de ameaças, controles e evidências (1h)

Preencha a matriz:

| Ameaça | Ativo | Controle preventivo | Controle de detecção | Evidência | Limitação |
|---|---|---|---|---|---|
| Credencial de produção comprometida | | | | | |
| Exclusão de versão | | | | | |
| Corrupção replicada | | | | | |
| Manifesto adulterado | | | | | |
| Chave indisponível | | | | | |
| Dwell time desconhecido | | | | | |

Depois, classifique cada controle como:

- aplicado no laboratório;
- demonstrado conceitualmente;
- indisponível no Learner Lab;
- recomendado para ambiente corporativo.

# Atividade 3 — melhoria de automação (1h30)

Escolha uma opção.

## Opção A — relatório de evidências

Proponha ou implemente localmente uma melhoria no `evidence_snapshot.sh` para produzir:

- timestamp UTC;
- identidade parcialmente mascarada;
- inventário de versões;
- delete markers;
- hashes dos arquivos locais;
- código de saída de cada verificação;
- sumário Markdown.

## Opção B — testes do validador

Crie testes locais para `validate_recovery.py` cobrindo:

1. conjunto íntegro;
2. arquivo ausente;
3. JSON inválido;
4. marcador de ransomware;
5. total financeiro incorreto.

## Opção C — análise do auditor AWS

Use uma saída previamente salva do `aws_access_check.sh` e produza uma tabela:

```text
ação | leitura real | simulação IAM | teste real | conclusão | confiança
```

Explique por que `ALLOWED` na simulação não é prova definitiva e por que um `AccessDenied` deve ser preservado como evidência.

# Atividade 4 — arquitetura-alvo e custos (1h)

Desenhe uma arquitetura corporativa contendo:

- domínio de produção;
- fluxo controlado de cópia;
- cyber vault;
- administração segregada;
- WORM;
- chaves fora do domínio comprometido;
- logs independentes;
- clean room;
- recovery gates;
- break-glass;
- retorno controlado.

Para cada componente, registre:

```text
objetivo | ameaça reduzida | responsável | evidência | custo/complexidade | limitação
```

Não é necessário implantar essa arquitetura na AWS Academy.

# Atividade 5 — after-action individual (30 min)

Entregue:

- três decisões corretas da equipe;
- duas decisões que você mudaria;
- uma evidência que faltou;
- um conceito que ficou mais claro;
- uma ação técnica que você seria capaz de executar em um ambiente real;
- uma pergunta que ainda precisa ser investigada.

## Critério de conclusão

As cinco horas complementares devem aprofundar o raciocínio e a documentação. Elas não podem ser usadas para terminar atrasadamente uma etapa essencial do Game Day nem para alterar a decisão registrada na War Room. Caso uma análise posterior mude sua compreensão, registre-a como aprendizado pós-exercício, preservando a decisão original e o contexto em que foi tomada.

