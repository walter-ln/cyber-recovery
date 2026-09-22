# Cyber Recovery Game Day — Operação Fênix

Laboratório prático de Cyber Recovery em AWS para equipes de 3–4 alunos.

## Carga horária e sequência

- **Game Day síncrono:** duas aulas consecutivas de 3 horas — 6 horas;
- **atividades assíncronas complementares:** 5 horas;
- **carga total:** 11 horas.

O jogo começa na Aula 1 e termina na Aula 2, sem depender de atividade realizada entre os encontros. As cinco horas assíncronas são complementares: servem para aprofundamento, documentação, automação e reflexão individual, mas não alteram o estado oficial do incidente nem são pré-requisito para concluir o Game Day.

O orçamento disponível é de até US$ 50 por aluno, mas o desenho usa principalmente S3 e deve consumir uma fração pequena desse valor. Não crie serviços adicionais sem autorização do professor.

## Antes de executar comandos

1. Leia [Conceitos essenciais](docs/01-conceitos-essenciais.md).
2. Leia o [Plano de aprendizagem](docs/02-plano-de-aprendizagem.md).
3. Aguarde a distribuição dos grupos.
4. Inicie o AWS Academy Learner Lab e abra o CloudShell em `us-east-1`.

## Estrutura

```text
.
├── README.md
├── docs/
│   ├── 01-conceitos-essenciais.md
│   └── 02-plano-de-aprendizagem.md
├── labs/
│   ├── grupo-a.md
│   ├── grupo-b.md
│   └── trilha-assincrona.md
├── templates/
│   ├── relatorio-preliminar.md
│   ├── incident-report.md
│   └── recovery-decision.md
└── student-kit/
    ├── aws_access_check.sh
    ├── student_preflight.sh
    ├── bootstrap.sh
    ├── create_dataset.sh
    ├── seed_recovery_history.sh
    ├── evidence_snapshot.sh
    ├── validate_recovery.py
    └── cleanup_bucket.sh
```

## Início no AWS CloudShell

```bash
cd ~
git clone https://github.com/walter-ln/cyber-recovery.git
cd ~/cyber-recovery
chmod +x student-kit/*.sh
./student-kit/student_preflight.sh
```

O preflight é somente leitura. Ele gera um relatório de capacidades e restrições da sessão sem criar recursos.

Depois, siga apenas o roteiro do seu grupo:

- [Grupo A](labs/grupo-a.md) — barreira operacional, recovery points e análise do domínio administrativo;
- [Grupo B](labs/grupo-b.md) — versionamento sem imutabilidade e destruição controlada de uma versão;
- [Atividades assíncronas complementares](labs/trilha-assincrona.md) — aprofundamentos independentes do Game Day.

## Script de inventário de acessos

Uso normal, sem criação de recursos:

```bash
./student-kit/aws_access_check.sh --full
```

O script combina chamadas reais de leitura e, quando permitido, simulação IAM. Nenhuma dessas técnicas consegue enumerar com certeza absoluta tudo o que a sessão pode fazer. SCP, session policy, permissions boundary, condições e políticas do recurso também participam da autorização.

O modo `--write-probes` cria recursos temporários e é reservado ao professor.

## Regras de segurança

1. Use apenas o AWS Academy Learner Lab.
2. Não crie IAM users, access keys ou roles.
3. Não tente contornar `AccessDenied`, SCP ou políticas do Academy.
4. Não use dados reais.
5. Execute comandos destrutivos apenas nos recursos criados por este laboratório.
6. Confira o valor de `$BUCKET` antes de qualquer comando `delete-*`.
7. Não execute `cleanup_bucket.sh` em buckets externos ao laboratório.
8. Preserve as evidências até a conclusão da avaliação.
9. Não use NAT Gateway, RDS, OpenSearch ou serviços de custo contínuo.
10. Se a sessão expirar, reinicie o Learner Lab e repita o preflight.

## Critério de sucesso

O objetivo não é fazer todos os comandos terminarem com sucesso. O objetivo é explicar, com evidências:

- o que sobreviveu;
- o que foi perdido;
- qual ponto pode ser recuperado;
- por que esse ponto é ou não confiável;
- se o serviço pode voltar;
- quais controles reduziriam o risco residual.
