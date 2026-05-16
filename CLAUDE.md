# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Natureza deste diretório

Este não é um repositório de código. É um **workspace de configuração da máquina** do usuário (Windows 10 Home, single language, pt-BR). O usuário usa o Claude Code aqui para instalar/configurar ferramentas de desenvolvimento na própria máquina, não para editar código.

Não há build, lint, ou testes a rodar. As "ações" são instalações via `winget`, edição de perfis (`$PROFILE`), ajuste de variáveis de ambiente, etc.

## Comunicação

Sempre responder em **português brasileiro**. Vale para perguntas, status, resumos e mensagens de erro próprias (mensagens de ferramentas externas permanecem como saem).

## Ambiente da máquina

- **OS:** Windows 10 Home Single Language, build 19045
- **CPU:** Intel i5-8265U (virtualização habilitada no firmware, SLAT presente — apto a WSL2/Hyper-V)
- **Shell ativo do Claude Code:** PowerShell 5.1 (limitação atual do harness). PS7 está instalado e deve ser usado em janelas novas que o usuário abre manualmente.
- **Privilégios:** usuário tem admin.

## Estado conhecido do setup

Já instalado (versões no momento desta nota — verifique antes de assumir):

| Ferramenta | Versão | Origem |
|---|---|---|
| Git | 2.54 | já vinha |
| Claude Code | — | já vinha |
| winget | 1.12.470 | `.msixbundle` v1.12 estável + dependencies bundle do GitHub (a v1.28+ exige `Microsoft.WindowsAppRuntime.1.8` que não está pré-instalado) |
| PowerShell 7 | 7.6.1 | `winget install Microsoft.PowerShell` |
| Python | 3.13.13 | `winget install Python.Python.3.13 --scope user` |
| VS Code | 1.119.0 | `winget install Microsoft.VisualStudioCode --scope user` |
| WSL2 + Ubuntu | kernel 6.6.114.1 | `wsl --install --no-launch` elevado (instala features+kernel+distro padrão) |
| Docker Desktop | 29.4.3 (Compose v5.1.3) | `winget install Docker.DockerDesktop` — backend WSL2, integração com Ubuntu automática |
| DBeaver Community | 26.0.4 | `winget install DBeaver.DBeaver.Community --scope user` |

Perfil do PS7 em `C:\Users\Usuario\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` — define UTF-8 padrão, PSReadLine com predição inline, funções `ll`/`touch`/`which`, prompt com branch git.

## Perfil de uso: aluno (Python + web básico)

Esta máquina está sendo preparada para um aluno que vai aprender Python básico e depois desenvolvimento web (frontend HTML/CSS/JS puro + backend API com Flask). Decisões tomadas com esse perfil em mente — favorecem **didática** sobre **otimização**:

**Extensões VS Code instaladas:**
- `ms-python.python` (puxa Pylance + debugpy), `ms-toolsai.jupyter`
- `ms-python.black-formatter` (Black, não Ruff — Ruff é mais avançado, deixar pra quando o aluno crescer)
- `eamodio.gitlens`, `mhutchie.git-graph`
- `esbenp.prettier-vscode` (HTML/CSS/JS), `ritwickdey.LiveServer` (preview HTML com reload)
- `rangav.vscode-thunder-client` (testar API dentro do VS Code, sem Postman)

**Git config global:**
- `init.defaultBranch=main`, `core.autocrlf=input` (Win↔WSL/Docker), `pull.rebase=false` (merge é didaticamente mais simples), `credential.helper=manager`, `core.editor="code --wait"`
- **NÃO setou `user.name`/`user.email`** — aluno define com a própria conta GitHub quando começar. Não rode `git config --global user.email ...` sem confirmar com o instrutor.

**`settings.json` do VS Code (user):**
- `editor.formatOnSave=true`, `editor.rulers=[88]` (limite Black)
- Python: Black formatter + organize imports on save + ativa venv no terminal automático + `typeCheckingMode=basic`
- HTML/CSS/JS/JSON/MD: Prettier, tab=2
- Terminal padrão: PowerShell (vai pegar o PS7)
- `files.eol="\n"` (LF) — combina com `autocrlf=input` para consistência cross-platform
- Telemetry desligada

## Convenções de ensino

- Ensinar `venv` desde o primeiro `pip install` — não instalar libs globais. Use `python -m venv .venv && .venv\Scripts\activate` (Win) ou `source .venv/bin/activate` (WSL).
- Para Flask, recomende `pip install flask` dentro de venv; `flask --app app run --debug` para servir.
- Para frontend, abrir HTML com **Live Server** (botão "Go Live" no canto inferior do VS Code).
- Para testar API, **Thunder Client** (ícone de raio na sidebar) — explica melhor que linha de comando.

## Pasta exemplo

`C:\Users\Usuario\teste-vscode\` é uma pasta de **exemplo didático** criada em 2026-05-16 para o aluno usar como referência inicial. Contém: `olamundo.py` (Hello World com algumas variáveis), `.venv` com Python 3.13, `.vscode/launch.json` (debug com `stopOnEntry: true`) e `.vscode/settings.json` (aponta o interpreter pro venv). Não é workspace ativo — pode ser apagada quando o aluno tiver seu primeiro projeto próprio.

## Convenções para instalações futuras

- **Preferir `winget` quando possível.** O usuário escolheu esse caminho. Use `--accept-package-agreements --accept-source-agreements --silent` para evitar prompts, e `--scope user` quando viável (não exige UAC).
- **PATH no shell PS 5.1 corrente não reflete instalações recentes.** Antes de verificar binários recém-instalados, recomponha o PATH:
  ```powershell
  $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
  ```
- **Confirmar antes de baixar/instalar.** Ações de instalação de pacotes do sistema são significativas; sempre apresentar o plano (tamanho, fonte, escopo) e pedir aprovação antes de prosseguir.
- **Testar perfil do PS7 via `pwsh -File <script.ps1>`** (não `pwsh -Command`), porque o PS 5.1 pai interpola variáveis dentro de aspas duplas antes de passar para o pwsh filho.
- **Erros de PSReadLine "doesn't support virtual terminal processing"** acontecem em sessões não-interativas (como as do harness). O perfil já guarda essas chamadas com `$Host.UI.SupportsVirtualTerminal` + try/catch.

## Tarefas em aberto / contexto vivo

Não confie nesta seção sem validar — ela envelhece. Verifique `TaskList` e o estado real da máquina antes de continuar.

- _(nada pendente no momento)_

## O que NÃO fazer

- Não criar arquivos de código, scripts de build, ou estruturas de projeto neste diretório — o usuário não está desenvolvendo aqui, está configurando a máquina.
- Não rodar `git init` aqui sem motivo claro; esta pasta não é destinada a ser um repo.
- Não assumir o estado dos PATH/variáveis sem reler — instalações alteram o ambiente persistido, mas a sessão atual do shell pai não enxerga até relogar ou recompor o PATH manualmente.
