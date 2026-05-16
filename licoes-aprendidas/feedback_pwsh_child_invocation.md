---
name: feedback-pwsh-child-invocation
description: Como invocar pwsh (PowerShell 7) a partir de uma sessão PowerShell 5.1 sem quebrar aspas e variáveis
metadata: 
  type: feedback
---

Ao chamar `pwsh.exe` (PS7) de dentro de uma sessão PowerShell 5.1 — comum no harness do Claude Code no Windows — **prefira `-File` a `-Command`** quando o script tem aspas duplas, `$variáveis` ou expressões `$(...)`.

```powershell
# RUIM: o PS 5.1 pai interpola $OutputEncoding antes de passar para o filho
pwsh -Command "Write-Output ('encoding: ' + $OutputEncoding.EncodingName)"

# BOM: gera arquivo .ps1 e invoca como script
$script = "$env:TEMP\probe.ps1"
@'
Write-Output ("encoding: " + $OutputEncoding.EncodingName)
'@ | Out-File -FilePath $script -Encoding utf8
pwsh -NoLogo -File $script
Remove-Item $script -Force
```

Alternativa: passar uma here-string single-quoted (`@' ... '@`) para `-Command $cmd`. Funciona se o conteúdo não tiver aspas duplas internas, porque o boundary `-Command` ainda destrói parte do parsing.

**Why:** Em 2026-05-16 perdi várias chamadas tentando testar o perfil do PS7 — `$OutputEncoding`, `(which git)` e outras expansões eram resolvidas no shell pai (PS 5.1) antes do filho ver. Geram erros como `'OutputEncoding:'` não reconhecido como cmdlet, ou `+` sem operando.

**How to apply:** Sempre que precisar rodar um snippet não-trivial em PS7 a partir do harness atual, escreva-o num `.ps1` temporário e use `-File`. Para one-liners curtos sem `$` nem aspas duplas, `-Command` ainda funciona.
