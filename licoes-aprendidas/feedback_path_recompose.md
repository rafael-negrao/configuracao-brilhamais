---
name: feedback-path-recompose
description: "Por que e como recompor $env:PATH no PowerShell após instalar programas, sem precisar fechar a sessão"
metadata: 
  type: feedback
---

Depois de instalar um programa via `winget` (ou qualquer instalador que mexe em variáveis de ambiente), a sessão atual do PowerShell **não enxerga o novo PATH**. O `$env:PATH` do processo foi herdado quando ele iniciou e só atualiza com fork novo.

Recomponha manualmente para validar imediatamente:

```powershell
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
```

Depois disso, `Get-Command pwsh`, `python --version`, `code --version` etc. funcionam sem precisar abrir terminal novo.

**Why:** Em 2026-05-16, logo após `winget install Microsoft.PowerShell` e `Python.Python.3.13`, os comandos `pwsh` e `py` não eram encontrados — `which` retornava vazio. A instalação tinha gravado no PATH persistido, mas o `$env:PATH` da sessão atual era um snapshot antigo. Recompor resolveu na hora.

**How to apply:** Faça esta recomposição uma vez logo após qualquer instalação ou alteração de variáveis de ambiente persistidas. Inclua no início de blocos de verificação. Não precisa fazer em sessões novas (o shell já lê o PATH atualizado ao iniciar).
