---
name: feedback-didatica-iniciante
description: Defaults a aplicar ao montar ambiente didático Python + web para iniciante absoluto
metadata: 
  type: feedback
---

Ao configurar uma máquina para alguém aprender Python + web do zero (perfil "iniciante guiado"), favorecer **convenção clássica e poucos conceitos por aula** sobre "tecnicamente mais correto":

| Tema | Escolher | Em vez de | Por quê |
|---|---|---|---|
| Formatter Python | **Black** (`ms-python.black-formatter`) | Ruff | Black é "zero config", opinionado, padrão histórico. Ruff é poderoso mas tem mais flags pra explicar |
| Backend Python | **Flask** | FastAPI | Flask é síncrono e minimalista; FastAPI exige entender async + Pydantic |
| Frontend | **HTML/CSS/JS puro + Live Server** | React/Vue/Svelte | Aluno precisa aprender fundamentos antes de SPA |
| Testar API | **Thunder Client** (extensão VS Code) | Postman, curl | Não sai do editor, UI simples |
| Git pull | `pull.rebase=false` (merge) | rebase | Merge gera histórico que dá pra desenhar visualmente, didaticamente mais simples |
| Line endings | `core.autocrlf=input` | `true` (Windows default) | Quando máquina tem WSL2/Docker, evita arquivos quebrarem entre Win e Linux containers |
| `git user.name/email` | **não setar global** | setar com email do instrutor | Aluno deve commitar com a própria identidade; setar global cria armadilha onde commits saem com nome errado |
| Ambiente Python | Ensinar `venv` desde o primeiro `pip install` | `pip install` global | Evita poluir Python do sistema; ensina isolamento de dependências cedo |
| Type checking | `python.analysis.typeCheckingMode=basic` | `strict` | Strict gera muitos erros de tipo em código de aluno e desmotiva |

Extensões VS Code recomendadas pro perfil: Python (Microsoft), Jupyter, Black formatter, GitLens, Git Graph, Prettier, Live Server, Thunder Client. Configurar Prettier como formatter de HTML/CSS/JS/JSON/MD com `tab=2`, manter Python com `tab=4`.

**Why:** Em mai/2026 Rafael (instrutor) preparou uma máquina pra aluno aprender Python básico → Flask + HTML/CSS/JS. As escolhas acima resultaram de discussão deliberada — ver [project-aluno-setup](project_aluno_setup.md). Em revisão posterior, Rafael confirmou as escolhas como "boas pro aluno".

**How to apply:** Quando o contexto for "iniciante absoluto guiado por instrutor", aplicar este preset inteiro. Quando for desenvolvedor pleno (mesmo aprendendo nova linguagem), inverter várias escolhas: Ruff > Black, FastAPI competitivo com Flask, rebase > merge, type checking mais rígido. Não aplicar este preset cegamente — pergunte o perfil primeiro.
