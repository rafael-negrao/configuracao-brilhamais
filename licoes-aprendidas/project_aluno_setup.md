---
name: project-aluno-setup
description: Esta máquina (Windows 10 Home) está sendo preparada para um aluno aprender Python + web. Setup datado de mai/2026.
metadata: 
  type: project
---

Em **2026-05-16**, esta máquina (Win10 Home Single Language pt-BR, build 19045) foi configurada por Rafael (instrutor) para um aluno que vai:

1. Aprender **Python básico** primeiro.
2. Depois construir uma **aplicação web simples**: backend **Flask** + frontend **HTML/CSS/JS puro** (sem framework SPA).

Decisões de stack registradas com esse propósito em mente — ver [feedback-didatica-iniciante](feedback_didatica_iniciante.md) para o racional de cada uma (Black em vez de Ruff, merge em vez de rebase, autocrlf=input, etc.).

**Why:** O perfil de "iniciante absoluto guiado por instrutor" muda o trade-off entre "ferramenta mais correta tecnicamente" e "ferramenta mais fácil de explicar". Ferramentas clássicas e opinadas (Black, Flask, Live Server) ganham de ferramentas mais avançadas (Ruff, FastAPI, Vite).

**How to apply:** Antes de propor mudanças nesta máquina, verificar se o perfil ainda é "máquina de aluno". Se Rafael disser que está usando pra si mesmo agora ou que o aluno virou pleno, este viés didático deixa de valer e pode-se sugerir Ruff, rebase, FastAPI, frameworks SPA, etc. Não confiar nesta memória sem validar — perfis mudam.

**Específicos a preservar enquanto o perfil "aluno" valer:**
- Não setar `git config --global user.name` ou `user.email` — o aluno define com a própria conta GitHub quando começar.
- Não instalar libs Python globais (`pip install flask` sem venv) — ensinar `python -m venv .venv` desde o primeiro `pip install`.
- Não complicar com pre-commit hooks, mypy, type checking strict, etc.
