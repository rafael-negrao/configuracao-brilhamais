---
name: feedback-elevated-process
description: Como rodar comandos elevados (admin) a partir do harness PS 5.1 do Claude Code e capturar a saída
metadata: 
  type: feedback
---

Para executar um comando que exige elevação (admin/UAC) e ainda assim conseguir ler a saída no harness do Claude Code, o padrão confiável é:

1. **Gere um `.ps1` temporário** com o comando + `Start-Transcript`/`Stop-Transcript`.
2. **Dispare elevado** com `Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$script)`.
3. **Leia o transcript** do `$env:TEMP` após o `-Wait` retornar.

```powershell
$log = "$env:TEMP\op.log"
$script = "$env:TEMP\op.ps1"
@"
Start-Transcript -Path '$log' -Force | Out-Null
# comando elevado aqui
wsl --install --no-launch
Stop-Transcript | Out-Null
"@ | Out-File -FilePath $script -Encoding utf8

Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList @(
  '-NoProfile','-ExecutionPolicy','Bypass','-File',$script
)
Get-Content $log
```

**Why:** Em 2026-05-16, ao habilitar WSL2, tentei primeiro `Start-Process ... -Verb RunAs -ArgumentList '-Command', $cmd` com inline script. Falhou silenciosamente (ExitCode 1, log vazio), provavelmente por problemas de quoting na passagem da string `-Command`. Migrar para arquivo `.ps1` + `-File` + `Start-Transcript` deu visibilidade total da execução elevada (incluindo confirmação `IsInRole(Administrator)=True` e `LASTEXITCODE`).

**How to apply:** Use sempre que precisar elevar um comando não-trivial (habilitar features Windows, instalar serviço, mexer em HKLM, etc.). Para uma única linha trivial, `-Verb RunAs -ArgumentList '/c','comando'` com cmd.exe ainda funciona, mas perde a saída. Relaciona com [feedback-pwsh-child-invocation](feedback_pwsh_child_invocation.md) — mesmo motivo (preferir `-File` a `-Command`).
