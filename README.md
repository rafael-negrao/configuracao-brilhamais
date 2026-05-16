# configuracao-brilhamais

Configuração de uma máquina Windows 10 Home preparada para um aluno aprender **Python básico** e depois **desenvolvimento web simples** (Flask como backend + HTML/CSS/JS puro como frontend).

Este repositório contém o script `setup-brilhamais.ps1` que **replica o setup completo em uma máquina nova**, além do registro das decisões tomadas.

## Como usar (replicar em uma máquina nova)

1. Abra o **PowerShell** (qualquer versão, 5.1 ou 7).
2. Baixe e execute o script:

   ```powershell
   # Permite scripts da sessão atual (não persiste)
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

   # Baixa direto do GitHub
   Invoke-WebRequest `
     -Uri "https://raw.githubusercontent.com/rafael-negrao/configuracao-brilhamais/main/setup-brilhamais.ps1" `
     -OutFile "$env:USERPROFILE\setup-brilhamais.ps1"

   # Executa todas as fases
   & "$env:USERPROFILE\setup-brilhamais.ps1"
   ```

3. Quando a **Fase 3 (WSL2)** terminar, o script **pausa e pede reboot**. Reinicie a máquina.
4. Após reiniciar, **abra o Ubuntu uma vez** no Menu Iniciar para definir usuário/senha.
5. Rode o script novamente — ele detecta o estado e segue da Fase 4 (Docker Desktop) em diante:

   ```powershell
   & "$env:USERPROFILE\setup-brilhamais.ps1"
   ```

6. Abra o Docker Desktop manualmente uma vez para aceitar os termos.

### Modos do script

| Comando | Efeito |
|---|---|
| `.\setup-brilhamais.ps1` | Roda todas as fases na ordem (padrão) |
| `.\setup-brilhamais.ps1 -Phase preflight` | Só **avalia o ambiente** (não instala nada) |
| `.\setup-brilhamais.ps1 -Phase status` | Só mostra o estado **pós-instalação** |
| `.\setup-brilhamais.ps1 -Phase 5` | Roda apenas a fase 5 (VS Code + git config) |

### Fases

| Fase | O quê | Admin? | Reboot? |
|---|---|---|---|
| **0 (preflight)** | **Avalia ambiente: build do Windows, virtualização da CPU, RAM, disco, internet, admin. Aborta se houver erro crítico.** | Não | Não |
| 1 | winget + PS7 + Python + VS Code + DBeaver + gh CLI | UAC só na instalação do PS7 | Não |
| 2 | Perfil do PowerShell 7 (`$PROFILE`) | Não | Não |
| 3 | WSL2 + Ubuntu (`wsl --install`) | Auto-elevação (UAC) | **Sim** |
| 4 | Docker Desktop (pós-reboot) | UAC pelo winget | Não |
| 5 | Git config global + VS Code settings + 8 extensões | Não | Não |
| 6 (status) | Validação final pós-instalação (smoke tests) | Não | Não |

A Fase 0 detecta automaticamente quando o hypervisor já está ativo (após a Fase 3 + reboot) e, nesse caso, **infere** que a virtualização da CPU está habilitada — caso contrário daria falso positivo na segunda execução do script (porque o Windows esconde `VirtualizationFirmwareEnabled` quando o Hyper-V/WSL2 está em uso).

O script é **idempotente** — pode ser executado quantas vezes precisar. Cada passo verifica se já foi feito e pula no caso afirmativo.

---

## Ambiente

| Ferramenta | Versão | Por quê |
|---|---|---|
| PowerShell 7 | 7.6.1 | Shell moderno, melhor que o PS 5.1 que vem por padrão no Windows |
| Python | 3.13.13 | Versão estável atual; suficiente para tudo que o aluno vai fazer |
| VS Code | 1.119.0 | Editor com Python + GitLens + Live Server + Thunder Client |
| WSL2 + Ubuntu | kernel 6.6 | Para Docker e quando o aluno avançar pro mundo Linux |
| Docker Desktop | 29.4.3 | Containers, com integração WSL2 automática |
| DBeaver Community | 26.0.4 | Cliente universal de banco de dados |
| GitHub CLI | 2.92 | Criar repos, abrir PRs sem sair do terminal |

Tudo foi instalado via `winget` quando possível, preferencialmente com `--scope user`.

## Por que essas escolhas e não outras

- **Black em vez de Ruff** — Black é "zero config", didaticamente mais simples para iniciante. Ruff é melhor tecnicamente, mas tem mais flags pra explicar.
- **Flask em vez de FastAPI** — Flask é síncrono e minimalista; FastAPI exige entender `async` e Pydantic antes mesmo da primeira rota funcionar.
- **HTML/CSS/JS puro em vez de SPA framework** — Aluno precisa entender DOM/eventos/fetch antes de abstrair com React/Vue/Svelte.
- **`pull.rebase = false`** — Merge gera histórico que pode ser desenhado no quadro, didaticamente mais claro que rebase.
- **`core.autocrlf = input`** — Mantém arquivos com LF mesmo no Windows. Evita que arquivos criados no Windows quebrem dentro de containers Docker / WSL2.
- **`user.name` / `user.email` não setados globalmente** — Esta máquina é compartilhada com aluno; identidade Git fica por repositório (config local) para evitar commits acidentais com a identidade errada.

## Estrutura

- `CLAUDE.md` — instruções para o Claude Code (claude.ai/code) operar nesta máquina em sessões futuras. Inclui estado do setup, convenções e o que não fazer.
- `README.md` — este arquivo.

## Setup paralelo do PowerShell 7

O perfil do PS7 (`$PROFILE` em `~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`) define:
- UTF-8 como entrada/saída padrão
- PSReadLine com predição inline e busca por prefixo (↑/↓)
- Funções `ll`, `touch`, `which`
- Prompt mostrando branch git quando aplicável

Não está versionado neste repositório porque o caminho é pessoal — quem reproduzir o setup pode copiar do `CLAUDE.md`.
