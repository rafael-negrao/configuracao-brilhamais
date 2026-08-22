# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Natureza deste repositório

Este repositório guarda os **scripts e as decisões** que replicam a configuração de uma máquina Windows preparada para um aluno aprender Python básico e depois desenvolvimento web (Flask + HTML/CSS/JS puro).

Não é um projeto de aplicação: não há build, lint, nem testes. O que existe são scripts PowerShell idempotentes e o registro do porquê de cada escolha. As "ações" são instalações via `winget`, edição de perfis (`$PROFILE`), ajuste de variáveis de ambiente e contas locais.

## Comunicação

Sempre responder em **português brasileiro**. Vale para perguntas, status, resumos e mensagens de erro próprias (mensagens de ferramentas externas permanecem como saem).

## ⚠️ Estado da máquina ≠ estado descrito nas versões antigas deste arquivo

Até 2026-08-22, este arquivo descrevia uma máquina **Windows 10 Home build 19045** com PowerShell 7, Ubuntu no WSL2, DBeaver, gh CLI e um conjunto grande de extensões do VS Code.

A máquina onde o repositório está clonado hoje **não corresponde a essa descrição**. Mesma CPU (i5-8265U), mas Windows 11 e um setup bem mais enxuto — provável reinstalação do sistema, ou uma segunda máquina. As seções abaixo refletem o que foi **medido em 2026-08-22**.

Lição geral: **meça antes de assumir.** Este arquivo envelhece rápido.

## Ambiente da máquina (verificado em 2026-08-22)

- **OS:** Windows 11 Home Single Language, build 26200 (10.0.26200), pt-BR
- **CPU:** Intel i5-8265U · **RAM:** 11,9 GB · **Disco C:** ~172 GB livres
- **Virtualização:** `HypervisorPresent = True`. Note que `VirtualizationFirmwareEnabled` retorna `False` — é o mascaramento descrito em [feedback_cpu_virt_hypervisor_mask.md](licoes-aprendidas/feedback_cpu_virt_hypervisor_mask.md), não ausência de suporte.
- **Shell ativo do Claude Code:** PowerShell 5.1. **PS7 não está instalado nesta máquina.**
- **Privilégios:** a conta `Usuario` é membro de Administradores, mas as sessões do harness **não são elevadas** — exigem auto-elevação via UAC.
- **Interatividade:** o harness roda com prompts de terminal desabilitados. Comandos que pedem login (`git push` sem credencial salva, `gh auth login`) **falham com "Cannot prompt because user interactivity has been disabled"** — o usuário precisa rodá-los com o prefixo `!` no Claude Code, ou em terminal externo.

### Instalado (medido em 2026-08-22)

| Ferramenta | Versão | Escopo | Observação |
|---|---|---|---|
| Git | 2.47.1.windows.2 | machine | `C:\Program Files\Git` |
| Python | 3.12.8 | **machine** | `C:\Program Files\Python312` — não é 3.13 nem `--scope user` |
| pip | 26.2 | user | pacotes em `%APPDATA%\Python\Python312` |
| VS Code | 1.119.0 | **machine** | `C:\Program Files\Microsoft VS Code` |
| winget | v1.29.290 | user | |
| Docker Desktop | 29.3.1 (build c2be9cc) | machine | |
| WSL | presente | — | **apenas a distro `docker-desktop` (Stopped). Não há Ubuntu.** |
| Claude Code | — | — | já vinha |

### NÃO instalado (embora o `setup-brilhamais.ps1` e o README os prevejam)

- **PowerShell 7** — logo, não existe perfil em `~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`
- **Ubuntu no WSL2** — só a distro interna do Docker Desktop
- **DBeaver Community**
- **GitHub CLI (`gh`)** — confirmado com `PATH` recomposto de Machine+User, não é sessão desatualizada

Antes de afirmar que algo está instalado, **recomponha o PATH e verifique** (veja [feedback_path_recompose.md](licoes-aprendidas/feedback_path_recompose.md)).

### VS Code — estado real

`settings.json` do usuário tem **74 bytes**, apenas:

```json
{
    "window.autoDetectColorScheme": true,
    "git.autofetch": true
}
```

Ou seja, **nada** do settings didático descrito no README (Black on save, rulers 88, Prettier, telemetria off) está aplicado aqui.

Extensões presentes:

```
github.copilot-chat
github.vscode-pull-request-github
ms-ceintl.vscode-language-pack-pt-br
ms-python.debugpy
ms-python.python
ms-python.vscode-pylance
ms-python.vscode-python-envs
ms-vscode.live-server
```

Divergências relevantes em relação ao conjunto planejado: **faltam** `black-formatter`, `jupyter`, `gitlens`, `git-graph`, `prettier-vscode`, `thunder-client`. O Live Server aqui é o `ms-vscode.live-server` (Microsoft), não o `ritwickdey.LiveServer`.

## Identidade Git — atenção

O README afirma que `user.name`/`user.email` **não** são definidos globalmente. **Nesta máquina eles estão definidos**, e com a identidade de outra pessoa:

```
user.name  = Lucas Berber Portalupi
user.email = lucasbportalupi17@gmail.com
```

Portanto, **sempre configure identidade local** (`git config user.email ...`, sem `--global`) antes de commitar neste repositório, ou os commits sairão com o autor errado. A autoria histórica do repo é `Rafael Negrão <rafael.negrao@adelfo.com.br>`.

Em 2026-08-22 a credencial do Windows `git:https://github.com` (que estava salva como `lucasbportalupi17-png`) foi **removida a pedido do usuário**, porque bloqueava o push para `rafael-negrao/configuracao-brilhamais` com HTTP 403. Quem usar a outra conta nesta máquina precisará autenticar de novo.

## Contas locais

- `admin_brilhamais` — conta local de administrador criada em 2026-08-22 pelo `criar-usuario-admin.ps1`. Membro de Administradores, habilitada, senha sem expiração. O perfil `C:\Users\admin_brilhamais` só é criado no primeiro logon.

## Perfil de uso: aluno (Python + web básico)

Esta máquina está sendo preparada para um aluno que vai aprender Python básico e depois desenvolvimento web (frontend HTML/CSS/JS puro + backend API com Flask). As decisões abaixo são o **alvo do projeto** — favorecem **didática** sobre **otimização** — e valem como intenção mesmo quando o estado medido acima ainda não bate.

**Extensões VS Code planejadas:**
- `ms-python.python` (puxa Pylance + debugpy), `ms-toolsai.jupyter`
- `ms-python.black-formatter` (Black, não Ruff — Ruff é mais avançado, deixar pra quando o aluno crescer)
- `eamodio.gitlens`, `mhutchie.git-graph`
- `esbenp.prettier-vscode` (HTML/CSS/JS), Live Server (preview HTML com reload)
- `rangav.vscode-thunder-client` (testar API dentro do VS Code, sem Postman)

**Git config planejado:**
- `init.defaultBranch=main`, `core.autocrlf=input` (Win↔WSL/Docker), `pull.rebase=false` (merge é didaticamente mais simples), `credential.helper=manager`, `core.editor="code --wait"`
- Identidade **por repositório**, não global — máquina compartilhada (veja a seção acima, que registra a violação atual dessa regra).

**`settings.json` planejado:**
- `editor.formatOnSave=true`, `editor.rulers=[88]` (limite Black)
- Python: Black formatter + organize imports on save + ativa venv no terminal automático + `typeCheckingMode=basic`
- HTML/CSS/JS/JSON/MD: Prettier, tab=2
- `files.eol="\n"` (LF) — combina com `autocrlf=input`
- Telemetry desligada

## Convenções de ensino

- Ensinar `venv` desde o primeiro `pip install` — não instalar libs globais. Use `python -m venv .venv && .venv\Scripts\activate` (Win) ou `source .venv/bin/activate` (WSL).
- Para Flask, recomende `pip install flask` dentro de venv; `flask --app app run --debug` para servir.
- Para frontend, abrir HTML com **Live Server**.
- Para testar API, **Thunder Client** (ícone de raio na sidebar) — explica melhor que linha de comando.

## Scripts deste repositório

- `setup-brilhamais.ps1` — provisionamento em 6 fases idempotentes (+ Fase 0 de preflight).
- `criar-usuario-admin.ps1` — cria/reconfigura uma conta local de administrador. Idempotente, com auto-elevação via UAC, resolve o grupo Administradores pelo SID `S-1-5-32-544` (independe do idioma do Windows) e grava log ao lado do script.
- `criar-usuario-aluno.ps1` — cria a conta local de uma turma: `-Turma 3A -Ano 2026` produz `aluno_3A_2026` com senha `Aluno@2026`. `-TipoConta Padrao` cria sem privilégio administrativo; `-ExigirTrocaSenha` força nova senha no primeiro logon (via ADSI `PasswordExpired = 1`). Valida o limite de 20 caracteres do Windows para nome de conta. Senha previsível é escolha deliberada para laboratório de aula — **não** use em máquina com RDP ou exposta.
- `remover-usuario-admin.ps1` — contrapartida dos scripts de criação; apesar do nome, remove qualquer conta local via `-UserName`. Preserva a pasta de perfil por padrão (`-RemoveProfile` para apagar). Recusa-se a remover a conta em uso, contas internas (RID < 1000) ou o último administrador habilitado; exige o nome digitado como confirmação, salvo com `-Force`. Sai com `2` se cancelado.
- `listar-usuarios.ps1` — inventário somente leitura das contas locais (habilitada, admin, último logon, senha, perfil, grupos). **Não exige elevação.** `-AsObject` devolve objetos para pipeline/CSV.

## Convenções para scripts e instalações

- **Nomes de arquivo em kebab-case** (`setup-brilhamais.ps1`, `criar-usuario-admin.ps1`), não `Verbo-Substantivo.ps1`.
- **Idempotência é obrigatória** — todo script deve poder rodar várias vezes; cada passo verifica se já foi feito e pula.
- **Preferir `winget`.** Use `--accept-package-agreements --accept-source-agreements --silent`, e `--scope user` quando viável (não exige UAC).
- **PATH da sessão PS 5.1 não reflete instalações recentes.** Recomponha antes de verificar binários:
  ```powershell
  $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
  ```
- **Confirmar antes de baixar/instalar.** Apresente o plano (tamanho, fonte, escopo) e peça aprovação.
- **Elevação:** gere um `.ps1` e dispare com `Start-Process powershell.exe -Verb RunAs -Wait -File`, lendo a saída de um log/transcript depois. Veja [feedback_elevated_process.md](licoes-aprendidas/feedback_elevated_process.md).
- **Nunca versionar senha real.** Use parâmetro interativo ou variável de ambiente. Ao passar senha por linha de comando para um processo elevado, ela fica visível na lista de processos por alguns instantes.
- **Manter os `.ps1` em ASCII puro.** O PS 5.1 lê `.ps1` sem BOM como ANSI (Windows-1252), então acento em literal de string quebra silenciosamente. Isso é especialmente perigoso ao comparar valores localizados do Windows — `Get-LocalGroupMember` devolve `ObjectClass = 'Usuário'` em pt-BR e `'User'` em en-US. **Não compare essas strings:** resolva por SID (`Get-LocalUser -SID`), como faz o `remover-usuario-admin.ps1`. Verifique com:
  ```powershell
  @([IO.File]::ReadAllBytes($p) | Where-Object { $_ -gt 127 }).Count   # deve ser 0
  ```
- **Mensagens ao usuário podem ter acento**, desde que fiquem fora dos `.ps1` (README, CLAUDE.md) ou que o arquivo seja salvo com BOM UTF-8.
- **`wsl` emite UTF-16 LE** — force `[Console]::OutputEncoding = [System.Text.Encoding]::Unicode` antes de parsear a saída.
- **Testar scripts para PS7 via `pwsh -File <script.ps1>`** (não `-Command`), porque o PS 5.1 pai interpola variáveis dentro de aspas duplas antes de passar ao filho.
- **Erros de PSReadLine "doesn't support virtual terminal processing"** acontecem em sessões não-interativas (como as do harness); guarde essas chamadas com `$Host.UI.SupportsVirtualTerminal` + try/catch.

## Tarefas em aberto / contexto vivo

Não confie nesta seção sem validar — ela envelhece.

- O estado da máquina divergiu bastante do setup planejado (sem PS7, sem Ubuntu, sem DBeaver, sem gh, VS Code quase sem configuração). **Decidir com o instrutor** se o `setup-brilhamais.ps1` deve ser rodado aqui para convergir, ou se este arquivo deve passar a descrever um perfil de máquina diferente.
- `user.name`/`user.email` globais estão com a identidade errada para este repositório (veja "Identidade Git").

## O que NÃO fazer

- Não assumir o estado de PATH/variáveis/ferramentas sem reler — instalações alteram o ambiente persistido, mas a sessão atual do shell pai não enxerga até relogar ou recompor o PATH.
- Não rodar `git config --global user.name/user.email` — a identidade é por repositório nesta máquina compartilhada.
- Não commitar senha, token ou credencial. Confira com `git grep` antes do commit.
- Não tentar comandos interativos direto no harness (login, `gh auth login`, prompts de credencial) — eles falham; peça ao usuário para rodar com o prefixo `!`.
