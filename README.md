# configuracao-brilhamais

Configuração de uma máquina Windows (10 ou 11, Home) preparada para um aluno aprender **Python básico** e depois **desenvolvimento web simples** (Flask como backend + HTML/CSS/JS puro como frontend).

Este repositório contém o script `setup-brilhamais.ps1` que **replica o setup completo em uma máquina nova**, scripts auxiliares para gerenciar contas locais, e o registro das decisões tomadas.

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

## Executar sem clonar o repositório

Os scripts de contas são independentes entre si — dá para baixar e rodar só o que você precisa, sem clonar nada.

Em máquinas antigas, o `Invoke-WebRequest` pode falhar com erro de SSL porque o PowerShell 5.1 não negocia TLS 1.2 por padrão. A linha `SecurityProtocol` resolve isso e é inofensiva onde já funciona.

### Listar as contas locais

Somente leitura, não pede UAC.

```powershell
# Permite scripts da sessão atual (não persiste)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Baixa direto do GitHub
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/rafael-negrao/configuracao-brilhamais/main/listar-usuarios.ps1" `
  -OutFile "$env:USERPROFILE\listar-usuarios.ps1"

# Executa
& "$env:USERPROFILE\listar-usuarios.ps1"

# Variações
& "$env:USERPROFILE\listar-usuarios.ps1" -AdminsOnly
& "$env:USERPROFILE\listar-usuarios.ps1" -Detailed -IncludeBuiltIn
```

### Criar o usuário administrador

Pede elevação sozinho (UAC).

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/rafael-negrao/configuracao-brilhamais/main/criar-usuario-admin.ps1" `
  -OutFile "$env:USERPROFILE\criar-usuario-admin.ps1"

# Pergunta a senha, com confirmação e sem eco na tela
& "$env:USERPROFILE\criar-usuario-admin.ps1"

# Desatendido
& "$env:USERPROFILE\criar-usuario-admin.ps1" -Password '<SENHA_AQUI>'

# Outro nome de conta
& "$env:USERPROFILE\criar-usuario-admin.ps1" -UserName 'suporte_bm' -FullName 'Suporte BrilhaMais'
```

### Remover o usuário administrador

Pede elevação sozinho (UAC) e confirmação digitada.

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/rafael-negrao/configuracao-brilhamais/main/remover-usuario-admin.ps1" `
  -OutFile "$env:USERPROFILE\remover-usuario-admin.ps1"

# Remove a conta, PRESERVANDO C:\Users\admin_brilhamais
& "$env:USERPROFILE\remover-usuario-admin.ps1"

# Remove a conta E apaga o perfil (irreversível)
& "$env:USERPROFILE\remover-usuario-admin.ps1" -RemoveProfile
```

### Baixar os três de uma vez

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$base = "https://raw.githubusercontent.com/rafael-negrao/configuracao-brilhamais/main"
foreach ($s in 'listar-usuarios','criar-usuario-admin','remover-usuario-admin') {
    Invoke-WebRequest -Uri "$base/$s.ps1" -OutFile "$env:USERPROFILE\$s.ps1"
    Write-Host "baixado: $s.ps1"
}
```

> **Antes de executar**, confira que a URL aponta para `rafael-negrao/configuracao-brilhamais` e dê uma olhada no arquivo baixado (`notepad "$env:USERPROFILE\criar-usuario-admin.ps1"`). Rodar script da internet com privilégio de administrador merece esse minuto de atenção — vale para estes e para qualquer outro.

---

## Criar usuário administrador local

O `criar-usuario-admin.ps1` cria (ou reconfigura) uma conta local com perfil de administrador. É independente do `setup-brilhamais.ps1` — útil para provisionar a conta de manutenção antes ou depois do setup principal.

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Interativo: pede a senha com confirmação, sem eco na tela
.\criar-usuario-admin.ps1

# Desatendido
.\criar-usuario-admin.ps1 -Password '<SENHA_AQUI>'

# Outro nome de usuário
.\criar-usuario-admin.ps1 -UserName 'suporte_bm' -FullName 'Suporte BrilhaMais'
```

| Parâmetro | Padrão | O quê |
|---|---|---|
| `-UserName` | `admin_brilhamais` | Nome da conta local |
| `-Password` | _(solicita)_ | Senha em texto puro; se omitida, pergunta com confirmação |
| `-FullName` | `Admin BrilhaMais` | Nome completo exibido |
| `-Description` | `Conta administrativa local BrilhaMais` | Descrição da conta |
| `-PasswordExpires` | _(desligado)_ | Faz a senha seguir a política de expiração do sistema |

Comportamento:

- **Idempotente** — se a conta já existir, apenas redefine senha/dados em vez de falhar.
- **Auto-elevação** — detecta sessão sem privilégio e reabre elevado via UAC.
- **Independente de idioma** — resolve o grupo Administradores pelo SID `S-1-5-32-544`, então funciona em Windows pt-BR, en-US ou qualquer outro.
- **Log** — grava `criar-usuario-admin.log` ao lado do script (ignorado pelo `.gitignore`).

> **Segurança:** nunca versione uma senha real neste repositório. Prefira a forma interativa, ou passe a senha por variável de ambiente (`-Password $env:BM_ADMIN_PWD`). Ao usar `-Password` junto com auto-elevação, a senha fica visível na linha de comando do processo elevado por alguns instantes — para uso sensível, rode a partir de um PowerShell já elevado e deixe o script perguntar.

## Listar contas locais

O `listar-usuarios.ps1` é **somente leitura** e **não exige elevação**. Mostra quem existe na máquina, quem é administrador, último logon, situação da senha e se há pasta de perfil.

```powershell
.\listar-usuarios.ps1                      # contas reais (esconde as internas do Windows)
.\listar-usuarios.ps1 -AdminsOnly          # só os administradores locais
.\listar-usuarios.ps1 -IncludeBuiltIn      # inclui Administrador, Convidado, DefaultAccount…
.\listar-usuarios.ps1 -Detailed            # SID, caminho do perfil, descrição e grupos
.\listar-usuarios.ps1 -AsObject | Where-Object Admin | Export-Csv contas.csv
```

Saída típica:

```
Nome             Ativa Admin Ultimo logon     Senha          Perfil
----             ----- ----- ------------     -----          ------
admin_brilhamais sim   SIM   nunca            nao expira     nao criado
Usuario          sim   SIM   2026-08-22 09:18 nunca definida ok
```

## Remover a conta administrador

O `remover-usuario-admin.ps1` é a contrapartida do script de criação.

```powershell
.\remover-usuario-admin.ps1                     # remove a conta, PRESERVA C:\Users\admin_brilhamais
.\remover-usuario-admin.ps1 -RemoveProfile      # remove a conta E apaga o perfil (irreversível)
.\remover-usuario-admin.ps1 -UserName 'suporte_bm' -Force   # sem confirmação
```

| Parâmetro | Padrão | O quê |
|---|---|---|
| `-UserName` | `admin_brilhamais` | Conta a remover |
| `-RemoveProfile` | _(desligado)_ | Apaga também a pasta de perfil e o registro. **Irreversível** |
| `-Force` | _(desligado)_ | Pula a confirmação digitada |

**Por padrão o perfil é preservado** — remover a conta não apaga os arquivos do usuário. Sem `-Force`, o script exige que você **digite o nome da conta** para confirmar.

Proteções — o script se recusa a prosseguir se:

- a conta for **a que você está usando** no momento;
- for uma **conta interna do Windows** (RID < 1000: `Administrador`, `Convidado`, `DefaultAccount`, `WDAGUtilityAccount`);
- for o **último administrador local habilitado** — impede deixar a máquina sem administrador;
- (aviso, não bloqueio) a conta tiver **sessão aberta** — faça logoff antes.

Se a conta não existir, o script informa e sai com sucesso — é idempotente como os demais.

Código de saída: `0` sucesso ou nada a fazer · `1` erro · `2` cancelado na confirmação.

---

## Ambiente

### O que o `setup-brilhamais.ps1` instala

O script não fixa versão: pede o pacote ao `winget`, que entrega a versão estável do momento. Por isso a coluna abaixo traz o **ID do pacote**, não um número que envelhece.

| Ferramenta | Pacote winget | Escopo | Por quê |
|---|---|---|---|
| PowerShell 7 | `Microsoft.PowerShell` | machine | Shell moderno, melhor que o PS 5.1 que vem por padrão no Windows |
| Python | `Python.Python.3.13` | `--scope user` | Versão estável atual; suficiente para tudo que o aluno vai fazer |
| VS Code | `Microsoft.VisualStudioCode` | `--scope user` | Editor com Python + GitLens + Live Server + Thunder Client |
| DBeaver Community | `DBeaver.DBeaver.Community` | `--scope user` | Cliente universal de banco de dados |
| GitHub CLI | `GitHub.cli` | machine | Criar repos, abrir PRs sem sair do terminal |
| Docker Desktop | `Docker.DockerDesktop` | machine | Containers, com integração WSL2 automática |
| WSL2 + Ubuntu | `wsl --install` | machine | Para Docker e quando o aluno avançar pro mundo Linux |

Preferência por `--scope user` onde o pacote suporta — evita UAC.

### O que está instalado na máquina de referência

Medido em **2026-08-22** em `DESKTOP-386PSAG` (Windows 11 Home Single Language, build 26200.8875, pt-BR · Intel i5-8265U · 11,9 GB RAM).

| Ferramenta | Versão | Escopo |
|---|---|---|
| Git | 2.47.1.windows.2 | machine |
| Python | 3.12.8 | machine |
| VS Code | 1.119.0 | machine |
| winget | v1.29.290 | user |
| Docker Desktop | 29.3.1 (build `c2be9cc`) | machine |
| Docker Compose | v5.1.0 | — |
| WSL | 2.7.11.0 · kernel 6.18.33.2-2 · WSLg 1.0.73.2 | machine |

**Ainda não instalados nesta máquina**, embora o script os preveja: **PowerShell 7**, **Ubuntu no WSL2** (só existe a distro interna `docker-desktop`), **DBeaver Community** e **GitHub CLI**.

> ⚠️ A máquina de referência **divergiu** do que o script instala — note o Python 3.12 em escopo machine, onde o script pede 3.13 em escopo user. Rode `.\setup-brilhamais.ps1 -Phase status` para conferir o estado real antes de assumir qualquer coisa desta tabela. O `CLAUDE.md` detalha as divergências, incluindo extensões do VS Code e `settings.json`.

## Por que essas escolhas e não outras

- **Black em vez de Ruff** — Black é "zero config", didaticamente mais simples para iniciante. Ruff é melhor tecnicamente, mas tem mais flags pra explicar.
- **Flask em vez de FastAPI** — Flask é síncrono e minimalista; FastAPI exige entender `async` e Pydantic antes mesmo da primeira rota funcionar.
- **HTML/CSS/JS puro em vez de SPA framework** — Aluno precisa entender DOM/eventos/fetch antes de abstrair com React/Vue/Svelte.
- **`pull.rebase = false`** — Merge gera histórico que pode ser desenhado no quadro, didaticamente mais claro que rebase.
- **`core.autocrlf = input`** — Mantém arquivos com LF mesmo no Windows. Evita que arquivos criados no Windows quebrem dentro de containers Docker / WSL2.
- **`user.name` / `user.email` não setados globalmente** — Esta máquina é compartilhada com aluno; identidade Git fica por repositório (config local) para evitar commits acidentais com a identidade errada.

## Estrutura

- `setup-brilhamais.ps1` — script principal de provisionamento, em 6 fases idempotentes (+ Fase 0 de preflight).
- `criar-usuario-admin.ps1` — cria uma conta local com perfil de administrador. Idempotente, com auto-elevação (UAC).
- `remover-usuario-admin.ps1` — remove essa conta, com proteções contra remover a conta em uso, contas internas do Windows ou o último administrador.
- `listar-usuarios.ps1` — inventário somente leitura das contas locais. Não exige elevação.
- `licoes-aprendidas/` — armadilhas técnicas e decisões didáticas acumuladas durante o setup. Veja o [índice](licoes-aprendidas/README.md).
- `CLAUDE.md` — instruções para o [Claude Code](https://claude.com/claude-code) operar nesta máquina em sessões futuras. Inclui estado do setup, convenções e o que não fazer.
- `README.md` — este arquivo.

## Setup paralelo do PowerShell 7

A **Fase 2** cria o perfil do PS7 (`$PROFILE` em `~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`) com:
- UTF-8 como entrada/saída padrão
- PSReadLine com predição inline e busca por prefixo (↑/↓)
- Funções `ll`, `touch`, `which`
- Prompt mostrando branch git quando aplicável

O arquivo em si não é versionado aqui porque o caminho é pessoal — o conteúdo é gerado pelo script.

> Na máquina de referência esse perfil **não existe**, porque o PowerShell 7 ainda não foi instalado (Fase 1 não rodou lá).
