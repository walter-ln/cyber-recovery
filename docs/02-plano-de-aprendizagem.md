# Plano de aprendizagem — Operação Fênix

## Carga horária

| Etapa | Carga | Resultado esperado |
|---|---:|---|
| Aula síncrona 1 | 3h | preparação, baseline, recovery points e readiness review |
| Aula síncrona 2, imediatamente após a Aula 1 | 3h | incidente, recuperação, War Room, decisão e post-mortem |
| Atividades assíncronas complementares | 5h | aprofundamento, documentação, automação e reflexão |
| **Total** | **11h** | Game Day concluído em 6h síncronas e aprofundado em 5h complementares |

## Regra de sequência

As duas aulas síncronas formam um único Game Day contínuo. Nenhuma atividade assíncrona é exigida entre a Aula 1 e a Aula 2. Ao terminar a primeira aula, preserve o ambiente e prossiga diretamente para a segunda, conforme orientação do professor.

## Aula síncrona 1 — Alinhamento, cenário e diagnóstico

### Primeira hora — conceitos e contexto

| Tempo | Atividade |
|---:|---|
| 0–15 min | briefing, papéis e regras de segurança |
| 15–35 min | definições: Cyber Recovery, RPO, RTO, RTA, trusted recovery point |
| 35–60 min | cenário ACME, dependências Tier 0 e critérios de evidência |

### Segunda e terceira horas — diagnóstico e preflight

| Tempo | Atividade |
|---:|---|
| 60–80 min | inventário de capacidades AWS e identidade da sessão |
| 80–110 min | bootstrap, dataset e classificação dos ativos |
| 110–145 min | arquitetura inicial e recovery points |
| 145–165 min | rehearsal e captura de evidências |
| 165–180 min | readiness review e passagem direta para a Aula 2 |

## Atividades assíncronas complementares — 5 horas

Siga [trilha-assincrona.md](../labs/trilha-assincrona.md) fora do fluxo crítico do jogo, preferencialmente depois das duas aulas. As atividades usam os conceitos e evidências do exercício, mas podem ser realizadas sem manter o ambiente AWS do Game Day ativo.

## Aula síncrona 2 — validação final e War Room

### Primeira hora — incidente, recuperação e validação

| Tempo | Atividade |
|---:|---|
| 0–15 min | retomar papéis, conferir ambiente e receber o incidente |
| 15–40 min | investigar versões e executar a recuperação controlada |
| 40–60 min | validar o conjunto e preparar decisão preliminar |

### Segunda e terceira horas — War Room e post-mortem

| Tempo | Atividade |
|---:|---|
| 60–80 min | inject final e análise de confiança |
| 80–110 min | defesa do Grupo A e auditoria do Grupo B |
| 110–140 min | defesa do Grupo B e auditoria do Grupo A |
| 140–165 min | redesenho da arquitetura, priorização e post-mortem |
| 165–180 min | post-mortem, lições e cleanup orientado |
