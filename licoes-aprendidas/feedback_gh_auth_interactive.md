---
name: feedback-gh-auth-interactive
description: "gh auth login não funciona via harness do Claude Code — precisa rodar com prefixo `!` para usar o shell interativo da UI"
metadata: 
  type: feedback
---

`gh auth login` é **interativo** (mostra um device code que o usuário precisa colar no browser, ou pede senha/token). Não funciona via Bash/PowerShell tool do harness — não há canal pra exibir o code nem pra capturar resposta.

Solução: peça que o **usuário cole o comando na conversa com prefixo `!`**, que executa no shell anexado à UI do Claude Code (terminal interativo, saída visível na conversa):

```
! gh auth login --hostname github.com --git-protocol https --web
```

⚠️ **Cuidado no Windows**: o `!` do Claude Code aqui usa **Git Bash** (`/usr/bin/bash`), **não** o PowerShell. Programas instalados via winget para o PATH do Windows (como `gh`, `code`, `winget`, etc.) **não** estão automaticamente no PATH do bash. Se `command not found`, use caminho POSIX absoluto:

```
! "/c/Program Files/GitHub CLI/gh.exe" auth login --hostname github.com --git-protocol https --web
```

Ou peça pro usuário abrir o Windows Terminal / PowerShell 7 e rodar `gh auth login ...` lá — fora do Claude Code — onde o PATH é o do Windows.

Fluxo esperado: gh mostra código `XXXX-XXXX`, usuário aperta Enter, browser abre em `github.com/login/device`, cola o código, autoriza escopos (`repo`, `read:org`, `gist`, `workflow`), volta pro terminal e vê `✓ Authentication complete`.

**Alternativa CI / token**: `echo $TOKEN | gh auth login --with-token` (não-interativo) se houver Personal Access Token disponível como variável de ambiente.

**Why:** Em 2026-05-16, ao subir um repo no GitHub a partir desta máquina (PS 5.1 do harness), tentar `gh auth login` direto via tool não funcionaria — prompt invisível pro usuário. O prefixo `!` envia ao terminal real da UI, onde o usuário interage normalmente.

**How to apply:** Sempre que uma CLI exigir OAuth/device flow (gh, az, gcloud, fly, vercel), instrua o usuário a rodar com `!`. Mesma lógica para qualquer comando que peça senha. Não tente Workaround com Bash tool e timeout — vai travar. Relaciona com [feedback-elevated-process](feedback_elevated_process.md): ambos são casos de "comando que não roda dentro do harness por motivos de I/O".
