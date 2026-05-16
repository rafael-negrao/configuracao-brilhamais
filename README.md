# configuracao-brilhamais

Configuração de uma máquina Windows 10 Home preparada para um aluno aprender **Python básico** e depois **desenvolvimento web simples** (Flask como backend + HTML/CSS/JS puro como frontend).

Este repositório não contém código de aplicação — é um registro do **ambiente de desenvolvimento** montado e das decisões tomadas. Outras pessoas que precisarem montar uma máquina parecida podem usar como ponto de partida.

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
