# Catálogo de Evidências

## Objetivo

Este diretório documenta evidências técnicas públicas do laboratório sem expor dados pessoais, credenciais ou metadados operacionais desnecessários.

Evidência não é dump de tela. Cada arquivo deve provar um controle específico.

## Princípios

Uma evidência pública deve ser:

- mínima;
- relevante;
- legível;
- reproduzível;
- sanitizada;
- revisada antes do commit;
- livre de credenciais e PII.

## Estrutura sugerida

```text
docs/evidencias/
├── README.md
├── 01-prerequisitos.png
├── 02-validacao-azure.png
├── 03-firewall-audit.png
├── 04-destroy-whatif.png
├── 05-schema-sql.png
├── 06-seed-idempotencia.png
└── 07-security-tests-14-pass.png
```

Os arquivos acima são nomes planejados. Só devem existir no Git depois de produzidos, sanitizados e aprovados.

## Catálogo

| Evidência | Objetivo | Conteúdo mínimo | Status inicial |
|---|---|---|---|
| `01-prerequisitos.png` | Provar ambiente local compatível | resultado do script sem identidade pessoal | A produzir |
| `02-validacao-azure.png` | Provar baseline Azure | TLS/TDE/Entra/summary sem IDs | A produzir |
| `03-firewall-audit.png` | Provar política de firewall | uma regra, single-IP, IP oculto | A produzir |
| `04-destroy-whatif.png` | Provar proteção destrutiva | confirmação + `WhatIf`, sem IDs | A produzir |
| `05-schema-sql.png` | Provar schema | tabelas + execução bem-sucedida | A produzir |
| `06-seed-idempotencia.png` | Provar idempotência | `3` assets e `4` events após repetição | A produzir |
| `07-security-tests-14-pass.png` | Provar suíte de segurança | 14 linhas PASS | A produzir |

## Dados proibidos

Antes de salvar uma captura, procure visualmente por:

- e-mail;
- nome pessoal;
- foto/avatar quando desnecessária;
- Subscription ID;
- Tenant ID;
- Object ID;
- Application/Client ID;
- Resource ID;
- IP;
- hostname real quando não for necessário;
- URL completa do Azure Portal;
- query string;
- identificador de sessão;
- cookies;
- token;
- senha;
- chave;
- connection string;
- caminho local do usuário;
- nome de usuário do Windows;
- abas do navegador;
- favoritos;
- notificações;
- dados de outras aplicações.

## Procedimento seguro

### 1. Defina o objetivo

Exemplo:

```text
Objetivo: comprovar 14/14 testes SQL com PASS.
```

Se algo não contribui para esse objetivo, não deve aparecer.

### 2. Minimize a interface

Prefira:

- janela focada na área técnica;
- painel estritamente necessário;
- navegador sem favoritos;
- nenhuma aba pessoal;
- cabeçalho de conta fora da captura;
- terminal sem prompt contendo caminho pessoal.

### 3. Capture somente a região necessária

Prefira captura de região, não tela inteira.

### 4. Redija permanentemente

Quando um identificador inevitavelmente aparecer:

- cubra completamente;
- não use blur leve;
- não use transparência;
- exporte nova imagem achatada;
- não versione arquivo editável com camadas.

Rótulos permitidos:

```text
[REDACTED]
<SUBSCRIPTION_ID>
<CLIENT_IPV4>
```

### 5. Recorte

Remova barra de endereço, conta autenticada, avatar, relógio, desktop, outras janelas, abas e caminho local.

### 6. Reabra o arquivo

Abra o PNG/JPG final e faça uma segunda inspeção visual.

### 7. Metadados

A evidência pública deve ser uma cópia final reexportada. Quando possível, reencode para remover metadados não essenciais.

### 8. Nomeie pela finalidade

Bom:

```text
07-security-tests-14-pass.png
```

Ruim:

```text
Screenshot_2026-08-17_213455_user-email.png
```

### 9. Use `temp/` para material bruto

O `.gitignore` prevê:

```text
docs/evidencias/temp/
```

Não use `git add -f` para contornar essa proteção.

## Revisão pré-commit

```powershell
Get-ChildItem `
    -LiteralPath ".\docs\evidencias" `
    -File |
    Select-Object Name, Length
```

```powershell
git status --short
```

Depois do staging:

```powershell
git diff --cached --name-only
```

O commit não deve conter arquivos brutos/temporários.

## Evidências de terminal

Não publique:

```text
%USERPROFILE%\...
```

Prefira recorte somente da saída técnica.

## Evidências Azure Portal

Não publique a tela inteira de Overview.

Áreas de risco:

- conta;
- URL;
- Subscription ID;
- Resource ID;
- tenant/diretório;
- IP;
- Object IDs.

## Evidências SQL

Boas evidências:

- tabelas necessárias;
- `ExpectedLabAssets=3`;
- `ExpectedSecurityEvents=4`;
- 14 `PASS`.

Evite conta autenticada, URL, subscription e servidor real desnecessário.

## Evidências PowerShell

Boas saídas:

```text
Falhas: 0
Avisos: 0
```

```text
Firewall validado.
Nenhum endereço IP foi exibido.
```

```text
What if: Performing the operation ...
```

Evite dumps completos de objetos Az.

## Critério PASS

- prova um controle;
- nenhuma informação proibida visível;
- redação permanente;
- arquivo reaberto e revisado;
- nome neutro;
- escopo claro;
- compreensível por terceiro.

## Critério FAIL

Rejeite se houver dúvida sobre PII, identificador Azure, origem, necessidade ou qualidade da sanitização.

## Integridade opcional

```powershell
Get-ChildItem `
    -LiteralPath ".\docs\evidencias" `
    -File |
    Where-Object Extension -In ".png", ".jpg", ".jpeg" |
    Get-FileHash -Algorithm SHA256 |
    Select-Object Path, Hash
```

Hash comprova integridade do arquivo aprovado; não substitui sanitização.
