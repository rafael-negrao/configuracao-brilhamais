---
name: feedback-winget-search-msstore
description: Comandos winget search/show ficam presos em prompt msstore mesmo com --silent — sempre passar --source winget --accept-source-agreements
metadata: 
  type: feedback
---

`winget search <termo>` (e `winget show`) **trava num prompt interativo** pedindo aceite dos termos da fonte `msstore` na primeira vez que ela é consultada. Esse prompt **não é satisfeito** por `--silent` nem `--accept-package-agreements`.

Solução: restringir explicitamente à fonte `winget` e aceitar termos de fonte na chamada:

```powershell
winget search dbeaver --source winget --accept-source-agreements
winget show Docker.DockerDesktop --source winget --accept-source-agreements
```

Para `winget install`, esse problema é menos comum porque o ID já vem com source implícito do pacote, mas vale o mesmo cinto e suspensório:

```powershell
winget install --id <ID> --source winget --accept-package-agreements --accept-source-agreements --silent
```

**Why:** Em 2026-05-16, rodei `winget search dbeaver` direto, o comando ficou pendurado em background com prompt "Você concorda com todos os termos dos contratos de origem?" da `msstore`. Tive que matar o processo (`TaskStop`) e refazer com `--source winget --accept-source-agreements`. O `--silent` global do winget não cobre prompts de **fonte** (só de **pacote**).

**How to apply:** Em scripts de provisionamento e em qualquer chamada não-interativa do winget, sempre incluir `--source winget --accept-source-agreements`. Alternativa permanente: rodar uma vez interativamente `winget search ""` e aceitar a msstore — depois disso o prompt some. Mas em ambiente automatizado (CI, harness do Claude Code), sempre explicitar.
