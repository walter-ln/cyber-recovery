# Conceitos essenciais antes do laboratório

Leia este documento antes de executar os scripts. O laboratório avalia decisões de recuperação, não memorização de comandos AWS.

## 1. Backup, Disaster Recovery e Cyber Recovery

**Backup** é uma cópia de dados mantida para restauração. A existência da cópia não prova que ela esteja íntegra, legível, completa ou protegida contra o atacante.

**Disaster Recovery — DR** é a capacidade de restabelecer serviços após falhas operacionais ou desastres. Normalmente prioriza disponibilidade, infraestrutura alternativa e tempos de retorno.

**Cyber Recovery** é a recuperação após um ataque que pode ter comprometido produção, identidades administrativas, ferramentas de backup, chaves, logs e pontos de recuperação. Além de restaurar, é necessário demonstrar que o estado selecionado é confiável.

## 2. RPO, RTO e RTA

**RPO — Recovery Point Objective** é a perda máxima de dados tolerável, medida no tempo entre o incidente e o ponto recuperado.

**RTO — Recovery Time Objective** é o tempo máximo de indisponibilidade aceito pelo negócio.

**RTA — Recovery Time Actual** é o tempo efetivamente medido em um exercício ou incidente. Um teste parcial mede apenas a etapa executada; não deve ser apresentado automaticamente como RTA do serviço completo.

## 3. Recovery point e trusted recovery point

**Recovery point** é um estado recuperável associado a um momento ou versão.

**Trusted recovery point** é um ponto para o qual existe argumento de confiança: origem conhecida, cadeia de evidências preservada, integridade verificada, ausência de indicadores incompatíveis e validação técnica/funcional suficiente.

`Latest` significa apenas “mais recente”. Não significa “limpo” nem “confiável”.

## 4. Integridade, limpeza e completude

**Integridade** indica que o conteúdo corresponde à referência usada na verificação, por exemplo um hash SHA-256.

**Clean copy** é uma cópia para a qual há evidência suficiente de ausência do comprometimento investigado.

**Completude** indica que todos os artefatos necessários ao serviço e às suas dependências estão presentes.

Um hash válido não prova limpeza se o arquivo e o manifesto tiverem sido produzidos ou alterados depois do comprometimento.

## 5. Isolamento e domínio administrativo

**Separação lógica** usa outro bucket, prefixo, conta lógica ou rede.

**Isolamento administrativo** impede que a mesma identidade, plano de controle ou cadeia de confiança usada na produção também administre a recuperação.

Um bucket separado na mesma conta e administrado pela mesma role reduz alguns riscos, mas não cria automaticamente um cyber vault.

## 6. Imutabilidade e WORM

**Imutabilidade** é a propriedade de impedir alteração ou exclusão durante um período definido.

**WORM — Write Once, Read Many** permite gravar e ler, mas impede modificação/exclusão conforme a política de retenção.

Uma Bucket Policy removível pela mesma identidade administrativa é uma barreira operacional, não uma prova de WORM.

No AWS Academy Learner Lab desta disciplina, S3 Object Lock e AWS Backup Vault Lock podem ser bloqueados por SCP ou `explicit deny`. A restrição será registrada; não deverá ser contornada.

## 7. S3: bucket, key, prefix, objeto e versão

- **Bucket:** contêiner lógico globalmente nomeado.
- **Key:** identificador completo do objeto dentro do bucket.
- **Prefix:** trecho inicial de uma key usado para organização e consulta; não é uma pasta real.
- **Objeto:** conteúdo e metadados associados a uma key.
- **VersionId:** identificador de uma versão específica quando o versionamento está habilitado.
- **Delete marker:** marcador criado por uma exclusão sem `VersionId`; oculta a versão corrente, mas não destrói necessariamente as versões anteriores.

Excluir uma key sem `VersionId` e excluir permanentemente uma versão são operações diferentes.

## 8. Clean room e recovery gate

**Clean room** é um ambiente controlado usado para restaurar e validar dados/sistemas sem confiar automaticamente na produção comprometida.

**Recovery gate** é um ponto formal de decisão. A equipe apresenta evidências e recomenda `GO`, `NO-GO` ou `GO COM RISCO ACEITO`. A autorização deve ter responsável explícito.

## 9. Tier 0 e ordem de recuperação

**Tier 0** reúne dependências cuja indisponibilidade ou comprometimento afeta a confiança e a recuperação de todo o ambiente, como identidade, DNS, PKI ou mecanismos equivalentes.

Recuperar dados da aplicação antes das dependências pode produzir arquivos íntegros em um serviço incapaz de operar ou de autenticar usuários com segurança.

## 10. Evidência

Evidência é informação preservada de forma que outra pessoa consiga verificar a afirmação. Neste laboratório, inclui:

- identidade/ARN da sessão;
- timestamps UTC;
- comandos e erros completos;
- nomes de recursos;
- `VersionId`;
- hashes;
- inventário de versões e delete markers;
- resultado do validador;
- decisão e justificativa.

`AccessDenied` também é evidência. Ele demonstra uma restrição efetiva da sessão e não autoriza tentativas de contorno.

## 11. Limite do inventário de acessos AWS

Não existe uma API que enumere com certeza todas as ações possíveis de uma sessão. A autorização pode depender de identidade, recurso, região, SCP, session policy, permissions boundary, condição, tag e política baseada em recurso.

O script `aws_access_check.sh` combina:

1. identificação da sessão;
2. chamadas reais de leitura;
3. simulação IAM, quando permitida;
4. testes de escrita reversíveis, somente quando o professor usa `--write-probes`.

Uma simulação `ALLOWED` é indicativa. O resultado real continua sendo a evidência mais forte.

