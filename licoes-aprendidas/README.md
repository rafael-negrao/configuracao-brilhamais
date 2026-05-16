# Lições aprendidas

Estas notas foram acumuladas durante o setup desta máquina (registrado em `setup-brilhamais.ps1`). Cada arquivo descreve uma armadilha técnica, uma decisão didática, ou um padrão recorrente que vale registrar para não esquecer e para que outras pessoas (ou agentes automáticos) reaproveitem.

Originalmente vivem no sistema de memória do [Claude Code](https://claude.com/claude-code) — aqui são uma cópia versionada, útil mesmo para quem nunca usou esse sistema. O frontmatter YAML (`name`, `description`, `metadata.type`) é convenção do Claude Code, mas todo o conteúdo é prosa Markdown comum.

## Tipos

- **feedback** — uma lição operacional: regra, com **Why** (motivo/incidente) e **How to apply** (quando vale o conselho)
- **project** — contexto vivo sobre o projeto/máquina

## Índice

### Setup de máquina Windows (técnico)

| Arquivo | Lição |
|---|---|
| [feedback_winget_install_win10.md](feedback_winget_install_win10.md) | Em Win10 sem App Installer da Store, usar winget v1.12.470 estável + dependencies zip; v1.28+ exige WindowsAppRuntime que falta |
| [feedback_winget_search_msstore.md](feedback_winget_search_msstore.md) | `winget search`/`show` trava em prompt msstore mesmo com `--silent` — passar `--source winget --accept-source-agreements` |
| [feedback_pwsh_child_invocation.md](feedback_pwsh_child_invocation.md) | Ao chamar `pwsh` de PS 5.1, preferir `-File script.ps1` a `-Command` — evita interpolação dupla |
| [feedback_path_recompose.md](feedback_path_recompose.md) | `$env:PATH` da sessão atual é snapshot; recompor `Machine + User` para validar binários recém-instalados sem reabrir terminal |
| [feedback_elevated_process.md](feedback_elevated_process.md) | Para rodar admin a partir de sessão não-elevada e ler a saída: `Start-Process -Verb RunAs -File script.ps1` + `Start-Transcript` |
| [feedback_gh_auth_interactive.md](feedback_gh_auth_interactive.md) | `gh auth login` é interativo (device flow) — rodar com prefixo `!` no Claude Code ou em terminal externo |
| [feedback_cpu_virt_hypervisor_mask.md](feedback_cpu_virt_hypervisor_mask.md) | `Win32_Processor.VirtualizationFirmwareEnabled` retorna `False` quando hypervisor já está ativo — checar `Win32_ComputerSystem.HypervisorPresent` primeiro |

### Decisões didáticas e contexto do projeto

| Arquivo | Conteúdo |
|---|---|
| [project_aluno_setup.md](project_aluno_setup.md) | Por que esta máquina foi preparada do jeito que foi — perfil "aluno guiado por instrutor" |
| [feedback_didatica_iniciante.md](feedback_didatica_iniciante.md) | Tabela de defaults para ambiente Python + web iniciante (Black em vez de Ruff, Flask em vez de FastAPI, merge em vez de rebase, etc.) |

## Como contribuir

Se você reproduziu este setup em outra máquina e descobriu uma armadilha nova, abra um PR adicionando um `feedback_<slug>.md` aqui usando o mesmo formato dos existentes.
