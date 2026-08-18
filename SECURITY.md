# Security Policy

## Objetivo

Este documento define o modelo de segurança do **DIO Azure SQL Secure Lab**, incluindo ativos protegidos, fronteiras de confiança, superfície de ataque, ameaças, controles, limitações, política de evidências e processo de reporte responsável.

Princípio central:

> Quando o estado de segurança não puder ser confirmado, a automação deve interromper a operação em vez de assumir que o ambiente é seguro.

## Escopo

Inclui scripts PowerShell, T-SQL, documentação, evidências, histórico Git, configuração de remote, primeiro push e os recursos Azure do laboratório.

Não representa garantia de produção, conformidade regulatória, postura global do tenant, SOC/SIEM, continuidade de negócios ou segurança física da estação do operador.

## Ativos protegidos

- sessão Azure e contexto da subscription;
- identidade Microsoft Entra;
- Tenant ID, Object ID e outros identificadores;
- tokens, senhas, chaves, connection strings e cookies;
- e-mail e PII;
- IP público;
- Resource Group, SQL logical server, database e firewall;
- integridade de arquivos, commits, branches, tags, reflogs e objetos Git;
- evidências públicas.

## Fronteiras de confiança

1. **Workstation local → Microsoft Entra**: autenticação ocorre fora do repositório.
2. **PowerShell → Azure Control Plane**: alterações dependem do contexto ativo.
3. **Cliente → Azure SQL**: no laboratório, endpoint público protegido por single-IP.
4. **Microsoft Entra → Azure SQL data plane**: autenticação Entra-only.
5. **Git local → GitHub**: publicação bloqueada até a auditoria final.

## Superfície de ataque

- contexto/subscription incorretos;
- firewall amplo;
- `Allow Azure Services`;
- TLS abaixo do baseline;
- autenticação SQL indevida;
- operação destrutiva no Resource Group errado;
- recursos inesperados no RG;
- PII em screenshots;
- e-mail pessoal em commits;
- arquivos gerados com dados sensíveis;
- remote incorreto;
- push prematuro;
- regras database-level inesperadas.

## Modelo de ameaças

| Ameaça | Impacto | Controle |
|---|---|---|
| Operação na subscription errada | Alto | `ExpectedSubscriptionId` |
| Servidor existente inseguro | Alto | TLS 1.2 + Entra-only antes de continuar |
| Firewall excessivamente amplo | Alto | política single-IP |
| `Allow Azure Services` | Alto | detecção e falha |
| Range de IP | Alto | rejeição |
| Remoção da última regra por engano | Médio/Alto | bloqueio + override explícito |
| Exclusão do RG errado | Crítico | contexto, tags, inventário, locks, confirmação, `ShouldProcess` |
| Recurso inesperado | Alto | allowlist |
| Token/senha no Git | Crítico | `.gitignore` + scans |
| E-mail pessoal no Git | Privacidade | GitHub `noreply` + auditoria |
| PII em screenshot | Privacidade | sanitização obrigatória |
| Regra database-level esquecida | Alto | `sys.database_firewall_rules` |
| Duplicação de seed | Integridade | `IF NOT EXISTS` + testes |
| Linha órfã | Integridade | FK + teste |
| Falha de consulta interpretada como sucesso | Alto | fail-closed |

## Controles implementados

### PowerShell

- PowerShell 7;
- `Set-StrictMode -Version Latest`;
- `$ErrorActionPreference = "Stop"`;
- `-ErrorAction Stop`;
- dry-run;
- `SupportsShouldProcess`;
- guard de subscription;
- validação pós-alteração;
- ocultação do IP no console;
- allowlists;
- bloqueio em caso de incerteza.

### Azure SQL

Baseline validado:

- TLS 1.2;
- TDE;
- Microsoft Entra-only;
- Serverless;
- Free Limit;
- AutoPause;
- server-level single-IP;
- sem `Allow Azure Services`;
- zero regras database-level validadas na database `master` e na database do laboratório.

### T-SQL

Schema:

- criação condicional;
- ausência de `DROP TABLE`;
- PKs, FK, CHECK constraints e índices.

Seed:

- dados fictícios;
- transação;
- `XACT_ABORT`;
- `TRY/CATCH`;
- rollback;
- `IF NOT EXISTS`;
- IDs resolvidos pelo banco.

Testes:

- 14 controles;
- `THROW` quando houver qualquer `FAIL`.

## Política de segredos

É proibido versionar senha, token, PAT, API key, client secret, account key, SAS, connection string, cookie, certificado/chave privada, `.env`, conteúdo de `.azure/` ou dumps de contexto autenticado.

Se um segredo real for exposto:

1. considere-o comprometido;
2. revogue/rotacione;
3. interrompa o push;
4. remova do working tree;
5. reescreva o histórico se necessário;
6. limpe refs/reflogs/objetos;
7. repita a auditoria.

Um commit posterior que apaga um arquivo não remove o conteúdo dos commits anteriores.

## Política de privacidade

Não publicar:

- e-mail pessoal;
- nome pessoal desnecessário;
- Subscription ID;
- Tenant ID;
- Object ID;
- IP;
- caminho local;
- URL completa do Azure Portal;
- identificador de sessão;
- dado de navegador;
- nome de recurso real quando sua exposição não for necessária.

Commits destinados ao GitHub devem usar o endereço `noreply` fornecido pelo GitHub.

## Política de evidências

Toda evidência deve:

1. ter finalidade definida;
2. mostrar somente a região necessária;
3. ocultar PII/identificadores;
4. ser revisada depois da sanitização;
5. ser exportada de forma achatada;
6. ser reaberta antes do commit;
7. constar no catálogo de evidências.

Evidências brutas ficam fora do Git.

## Operações destrutivas

Fluxo mínimo:

1. validar contexto;
2. executar `99-destroy.ps1` sem `-Apply`;
3. revisar inventário;
4. executar `-Apply -WhatIf`;
5. confirmar que somente a ação prevista seria executada;
6. validar ausência de recursos inesperados;
7. excluir realmente apenas quando isso for intencional.

## Histórico Git

### Dado no working tree

Remover antes do commit.

### Dado em histórico alcançável

Requer reescrita do histórico.

### Dado somente em reflog/objeto inalcançável

Após confirmar que o histórico alcançável está limpo e possuir backup do estado desejado:

- expirar reflogs;
- executar garbage collection;
- validar novamente.

Essas operações removem a possibilidade de recuperar commits antigos não referenciados.

## Supply chain

- instale Git, PowerShell, Az e ferramentas auxiliares de fontes confiáveis;
- mantenha versões suportadas;
- revise breaking changes;
- não execute scripts de terceiros sem revisão;
- não instale ferramentas de reescrita de histórico apenas por copiar comandos de fontes não verificadas.

## Limitações

O laboratório utiliza endpoint público com firewall single-IP. Isso reduz exposição, mas não equivale a isolamento privado.

Para produção, considere Private Endpoint, `PublicNetworkAccess` desabilitado, Key Vault, PIM, RBAC mínimo, Azure Policy, Defender for SQL, Log Analytics, alertas e CI/CD com secret scanning.

## Reporte responsável

Não abra issue pública contendo segredo, token, PII ou detalhes exploráveis de uma implantação ativa.

1. Use **Private Vulnerability Reporting** do GitHub, se estiver habilitado.
2. Caso contrário, use um canal privado indicado pelo mantenedor.
3. Inclua impacto, pré-condições, reprodução e mitigação.
4. Substitua segredos por placeholders.

## Severidade sugerida

- **Crítica:** segredo utilizável, chave privada, token ativo, exclusão ampla indevida.
- **Alta:** bypass de guardrails, firewall amplo, operação em subscription errada.
- **Média:** exposição de identificadores operacionais ou ausência de validação defensiva.
- **Baixa:** documentação ou hardening adicional sem impacto imediato.

## Gate de publicação

O primeiro push só é permitido se:

- working tree estiver limpo;
- documentação estiver revisada;
- arquivos rastreados estiverem auditados;
- histórico alcançável estiver auditado;
- author/committer usarem `noreply`;
- PII proibida = 0;
- segredos = 0;
- evidências estiverem sanitizadas;
- reflogs/objetos antigos tiverem sido tratados;
- remote estiver validado;
- branch de publicação estiver confirmada.

Qualquer falha crítica bloqueia o push.
