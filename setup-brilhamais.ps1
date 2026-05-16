#Requires -Version 5.1
<#
.SYNOPSIS
    Setup de uma maquina Windows 10/11 para ensino de Python + web (Flask + HTML/CSS/JS).

.DESCRIPTION
    Replica em outra maquina o setup documentado em
    https://github.com/rafael-negrao/configuracao-brilhamais

    Script idempotente, dividido em fases. Pode ser executado quantas vezes for
    necessario - cada fase detecta o estado atual e pula o que ja esta feito.

    O fluxo completo exige UM reboot entre as Fases 3 e 4 (depois de habilitar
    o WSL2). Apos reiniciar a maquina, basta rodar o script novamente que ele
    retoma de onde parou.

.PARAMETER Phase
    Numero da fase a executar (0..6), 'all' para tudo em sequencia (padrao),
    'preflight' (alias de 0) para apenas avaliar o ambiente,
    ou 'status' para apenas validar o estado pos-instalacao (alias de 6).

.EXAMPLE
    .\setup-brilhamais.ps1
    Executa todas as fases em sequencia.

.EXAMPLE
    .\setup-brilhamais.ps1 -Phase 4
    Executa apenas a Fase 4 (Docker Desktop).

.EXAMPLE
    .\setup-brilhamais.ps1 -Phase status
    Mostra o que ja esta instalado.

.NOTES
    Autor: Rafael Negrao (https://github.com/rafael-negrao)
    Licenca: MIT
#>
[CmdletBinding()]
param(
    [ValidateSet('all', 'status', 'preflight', '0', '1', '2', '3', '4', '5', '6')]
    [string]$Phase = 'all'
)

$ErrorActionPreference = 'Stop'

# ======================================================================
#  Helpers
# ======================================================================

function Write-Phase {
    param([string]$Number, [string]$Title)
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "  FASE $Number - $Title" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Cyan
}

function Write-Step {
    param(
        [string]$Message,
        [ValidateSet('Info', 'OK', 'Skip', 'Warn', 'Err')]
        [string]$Status = 'Info'
    )
    $colors = @{ Info = 'White'; OK = 'Green'; Skip = 'DarkGray'; Warn = 'Yellow'; Err = 'Red' }
    $tags = @{ Info = '[INFO] '; OK = '[ OK ] '; Skip = '[SKIP] '; Warn = '[WARN] '; Err = '[ERR ] ' }
    Write-Host ($tags[$Status] + $Message) -ForegroundColor $colors[$Status]
}

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal]$id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Update-SessionPath {
    # Apos uma instalacao, o $env:PATH da sessao atual nao reflete o novo PATH
    # persistido. Recompoe combinando Machine + User para validar binarios na hora.
    $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') +
                ';' +
                [System.Environment]::GetEnvironmentVariable('PATH', 'User')
}

function Test-CommandExists {
    param([string]$Name)
    Update-SessionPath
    [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Invoke-Elevated {
    <#
    Executa um bloco em processo elevado e captura a saida via transcript.
    Se ja estiver elevado, executa direto na sessao atual.
    #>
    param(
        [Parameter(Mandatory)][string]$Body,
        [string]$Description = 'comando elevado'
    )
    if (Test-IsAdmin) {
        Invoke-Expression $Body
        return
    }
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $log = "$env:TEMP\setup_elev_$stamp.log"
    $script = "$env:TEMP\setup_elev_$stamp.ps1"
    @"
Start-Transcript -Path '$log' -Force | Out-Null
try {
$Body
} catch {
    Write-Output ('ERRO: ' + `$_.Exception.Message)
} finally {
    Stop-Transcript | Out-Null
}
"@ | Out-File -FilePath $script -Encoding utf8

    Write-Step "Disparando $Description (aceite o UAC)" 'Warn'
    Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script
    ) | Out-Null

    if (Test-Path $log) {
        Get-Content $log |
            Where-Object {
                $_ -and
                $_ -notmatch '^\*+$' -and
                $_ -notmatch '^(Hora|Nome|Computador|Aplicativo|ID|PSVersion|PSEdition|PSCompat|BuildVersion|CLRVersion|WSMan|PSRemoting|Serialization|Inicio|Executar|Configuracao|Host|inicio|fim|Transcricao|Transcription).*'
            } |
            ForEach-Object { Write-Host "    | $_" -ForegroundColor DarkGray }
        Remove-Item $log -Force -ErrorAction SilentlyContinue
    }
    Remove-Item $script -Force -ErrorAction SilentlyContinue
}

function Test-WingetPackageInstalled {
    param([string]$Id)
    if (-not (Test-CommandExists 'winget')) { return $false }
    $result = winget list --id $Id --source winget --accept-source-agreements 2>$null |
              Select-String -Pattern $Id -SimpleMatch
    [bool]$result
}

function Install-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$DisplayName,
        [string[]]$ExtraArgs = @()
    )
    if (Test-WingetPackageInstalled -Id $Id) {
        Write-Step "$DisplayName ja instalado" 'Skip'
        return
    }
    Write-Step "Instalando $DisplayName ($Id)..."
    $args = @(
        'install', '--id', $Id, '--source', 'winget',
        '--accept-package-agreements', '--accept-source-agreements', '--silent'
    ) + $ExtraArgs
    & winget @args | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Step "$DisplayName instalado" 'OK'
    } else {
        Write-Step "$DisplayName retornou exit code $LASTEXITCODE" 'Warn'
    }
}

# ======================================================================
#  Fase 0: Preflight - avalia o ambiente antes de instalar
# ======================================================================

function Invoke-Phase0 {
    Write-Phase '0' 'Preflight - avaliacao do ambiente'

    $blocking = 0
    $warnings = 0

    # --- Windows build ---
    $ver = [System.Environment]::OSVersion.Version
    if ($ver.Build -ge 19041) {
        Write-Step ("Windows build {0} (>=19041, ok para WSL2)" -f $ver.Build) 'OK'
    } else {
        Write-Step ("Windows build {0} - precisa >=19041 (Win10 v2004 de 2020 ou Win11)" -f $ver.Build) 'Err'
        $blocking++
    }

    # --- CPU: virtualizacao no firmware ---
    # IMPORTANTE: quando um hipervisor (Hyper-V/WSL2) ja esta ativo, o Windows
    # esconde VirtualizationFirmwareEnabled e SLAT do Win32_Processor (retornam
    # False mesmo a CPU tendo o recurso). Detectamos isso antes para nao dar
    # falso positivo na 2a execucao do script.
    $hyperVisorActive = $false
    try {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $hyperVisorActive = [bool]$cs.HypervisorPresent
    } catch {}

    if ($hyperVisorActive) {
        Write-Step "CPU: hipervisor ja ativo (Hyper-V/WSL2) - virtualizacao habilitada (inferido)" 'OK'
    } else {
        try {
            $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
            if ($cpu.VirtualizationFirmwareEnabled) {
                Write-Step "CPU: virtualizacao habilitada no firmware" 'OK'
            } else {
                Write-Step "CPU: virtualizacao DESABILITADA no firmware - habilite Intel VT-x / AMD-V no BIOS/UEFI" 'Err'
                $blocking++
            }
            if ($cpu.SecondLevelAddressTranslationExtensions) {
                Write-Step "CPU: SLAT (Second Level Address Translation) presente" 'OK'
            } else {
                Write-Step "CPU: SLAT ausente - WSL2 e Docker Desktop nao funcionarao nessa CPU" 'Err'
                $blocking++
            }
        } catch {
            Write-Step "Nao foi possivel ler caracteristicas da CPU - prosseguindo" 'Warn'
            $warnings++
        }
    }

    # --- RAM ---
    try {
        $ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory / 1GB, 1)
        if ($ramGB -ge 8) {
            Write-Step ("RAM: {0} GB" -f $ramGB) 'OK'
        } elseif ($ramGB -ge 4) {
            Write-Step ("RAM: {0} GB - funciona mas Docker Desktop pode ficar apertado (ideal 8 GB+)" -f $ramGB) 'Warn'
            $warnings++
        } else {
            Write-Step ("RAM: {0} GB - insuficiente, minimo 4 GB" -f $ramGB) 'Err'
            $blocking++
        }
    } catch {
        Write-Step "Nao foi possivel ler total de RAM" 'Warn'
        $warnings++
    }

    # --- Disco C: ---
    try {
        $diskC = Get-PSDrive C -ErrorAction Stop
        $freeGB = [math]::Round($diskC.Free / 1GB, 1)
        if ($freeGB -ge 15) {
            Write-Step ("Disco C:\ - {0} GB livres" -f $freeGB) 'OK'
        } elseif ($freeGB -ge 10) {
            Write-Step ("Disco C:\ - {0} GB livres (apertado, ideal 15 GB+)" -f $freeGB) 'Warn'
            $warnings++
        } else {
            Write-Step ("Disco C:\ - {0} GB livres - insuficiente, minimo 10 GB" -f $freeGB) 'Err'
            $blocking++
        }
    } catch {
        Write-Step "Nao foi possivel ler espaco do disco C" 'Warn'
        $warnings++
    }

    # --- Conectividade com GitHub (necessario para downloads) ---
    $hasInternet = $false
    try {
        $resp = Invoke-WebRequest -Uri 'https://github.com' -Method Head -TimeoutSec 8 -UseBasicParsing -ErrorAction Stop
        $hasInternet = ($resp.StatusCode -lt 500)
    } catch {}
    if ($hasInternet) {
        Write-Step "Internet: github.com acessivel" 'OK'
    } else {
        Write-Step "Internet: github.com nao respondeu em 8s - downloads de winget/Docker vao falhar" 'Err'
        $blocking++
    }

    # --- Permissao de admin (informativo) ---
    if (Test-IsAdmin) {
        Write-Step "Sessao atual: ADMIN (UAC nao sera solicitado novamente)" 'OK'
    } else {
        Write-Step "Sessao atual: usuario normal - UAC sera solicitado para Fase 3 (WSL2) e Fase 4 (Docker)" 'Warn'
        $warnings++
    }

    # --- Resumo ---
    Write-Host ''
    if ($blocking -gt 0) {
        Write-Step ("Preflight: {0} problema(s) CRITICO(s). Corrija antes de prosseguir." -f $blocking) 'Err'
        throw 'Preflight falhou. Setup abortado.'
    }
    if ($warnings -gt 0) {
        Write-Step ("Preflight: {0} aviso(s) nao-bloqueante(s). Prosseguindo." -f $warnings) 'Warn'
    } else {
        Write-Step 'Preflight: tudo OK, ambiente apto para o setup completo.' 'OK'
    }
}

# ======================================================================
#  Fase 1: Winget + ferramentas base
# ======================================================================

function Install-Winget {
    # Instala o App Installer (winget) em Win10 que nao o tem por padrao.
    # Usa v1.12.470 estavel - versoes 1.28+ exigem Microsoft.WindowsAppRuntime.1.8
    # que nao vem pre-instalado em Win10.
    $base = 'https://github.com/microsoft/winget-cli/releases/download/v1.12.470'
    $main = "$env:TEMP\winget_main.msixbundle"
    $depZip = "$env:TEMP\winget_deps.zip"
    $depDir = "$env:TEMP\winget_deps_extracted"

    Write-Step 'Baixando winget v1.12.470 (~206 MB) + dependencias (~93 MB)...'
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest "$base/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -OutFile $main -UseBasicParsing
    Invoke-WebRequest "$base/DesktopAppInstaller_Dependencies.zip" -OutFile $depZip -UseBasicParsing

    if (Test-Path $depDir) { Remove-Item -Recurse -Force $depDir }
    Expand-Archive -Path $depZip -DestinationPath $depDir -Force

    $arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
    $depFiles = Get-ChildItem "$depDir\$arch" -Filter '*.appx' | Select-Object -ExpandProperty FullName

    Write-Step 'Instalando winget (Add-AppxPackage)...'
    Add-AppxPackage -Path $main -DependencyPath $depFiles -ErrorAction Stop

    Remove-Item $main, $depZip -Force -ErrorAction SilentlyContinue
    Remove-Item $depDir -Recurse -Force -ErrorAction SilentlyContinue

    Update-SessionPath
    if (Test-CommandExists 'winget') {
        Write-Step "winget instalado: $(winget --version)" 'OK'
    } else {
        Write-Step 'winget nao apareceu no PATH. Tente reabrir o terminal.' 'Err'
        throw 'winget instalado mas nao disponivel'
    }
}

function Invoke-Phase1 {
    Write-Phase '1' 'Ferramentas base via winget'

    if (-not (Test-CommandExists 'winget')) {
        Write-Step 'winget nao encontrado - instalando' 'Warn'
        Install-Winget
    } else {
        Write-Step "winget ja presente ($(winget --version))" 'Skip'
    }

    Install-WingetPackage -Id 'Microsoft.PowerShell'         -DisplayName 'PowerShell 7'
    Install-WingetPackage -Id 'Python.Python.3.13'           -DisplayName 'Python 3.13'   -ExtraArgs @('--scope', 'user')
    Install-WingetPackage -Id 'Microsoft.VisualStudioCode'   -DisplayName 'VS Code'       -ExtraArgs @('--scope', 'user')
    Install-WingetPackage -Id 'DBeaver.DBeaver.Community'    -DisplayName 'DBeaver CE'    -ExtraArgs @('--scope', 'user')
    Install-WingetPackage -Id 'GitHub.cli'                   -DisplayName 'GitHub CLI'
}

# ======================================================================
#  Fase 2: Perfil do PowerShell 7
# ======================================================================

function Invoke-Phase2 {
    Write-Phase '2' 'Perfil do PowerShell 7'

    $profileDir = "$env:USERPROFILE\Documents\PowerShell"
    $profilePath = "$profileDir\Microsoft.PowerShell_profile.ps1"

    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    if (Test-Path $profilePath) {
        Write-Step "Perfil ja existe em $profilePath (renomeie para forcar recriacao)" 'Skip'
        return
    }

    $content = @'
# UTF-8 padrao para entrada/saida
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8'

# PSReadLine (so configura em sessao interativa)
if ((Get-Module -ListAvailable -Name PSReadLine) -and $Host.UI.SupportsVirtualTerminal) {
    try {
        Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView -ErrorAction Stop
        Set-PSReadLineOption -HistoryNoDuplicates -HistorySearchCursorMovesToEnd
        Set-PSReadLineOption -EditMode Windows -BellStyle None
        Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
        Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
        Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete
    } catch {}
}

# Aliases tipo Unix
function ll { Get-ChildItem -Force @args | Format-Table -AutoSize Mode, LastWriteTime, Length, Name }
function touch {
    param([Parameter(Mandatory)][string]$Path)
    if (Test-Path $Path) { (Get-Item $Path).LastWriteTime = Get-Date }
    else { New-Item -ItemType File -Path $Path | Out-Null }
}
function which {
    param([Parameter(Mandatory)][string]$Name)
    (Get-Command $Name -ErrorAction SilentlyContinue).Source
}

# Prompt com branch git
function global:prompt {
    $cwd = $executionContext.SessionState.Path.CurrentLocation.Path
    $short = $cwd.Replace($HOME, '~')
    $branch = $null
    try { $branch = git -C $cwd rev-parse --abbrev-ref HEAD 2>$null } catch {}
    Write-Host "PS " -NoNewline -ForegroundColor DarkGray
    Write-Host $short -NoNewline -ForegroundColor Cyan
    if ($branch) { Write-Host " ($branch)" -NoNewline -ForegroundColor Yellow }
    return "`n> "
}
'@

    $content | Out-File -FilePath $profilePath -Encoding utf8
    Write-Step "Perfil criado em $profilePath" 'OK'
}

# ======================================================================
#  Fase 3: WSL2 + Ubuntu (admin + reboot)
# ======================================================================

function Test-WSLReady {
    if (-not (Test-CommandExists 'wsl')) { return $false }
    try {
        $list = wsl -l -v 2>&1
        if ($LASTEXITCODE -ne 0) { return $false }
        return ($list -match 'Ubuntu')
    } catch {
        return $false
    }
}

function Invoke-Phase3 {
    Write-Phase '3' 'WSL2 + Ubuntu (admin + reboot)'

    if (Test-WSLReady) {
        Write-Step 'WSL2 + Ubuntu ja instalados e funcionais' 'Skip'
        return $false
    }

    Write-Step 'Habilitando WSL2 + features + kernel + Ubuntu (UAC vai aparecer)' 'Warn'
    Invoke-Elevated -Body 'wsl --install --no-launch' -Description 'wsl --install'

    Write-Host ''
    Write-Host '  ===========================================================' -ForegroundColor Yellow
    Write-Host '   REBOOT NECESSARIO antes de continuar para a Fase 4.' -ForegroundColor Yellow
    Write-Host '   1. Reinicie a maquina agora.' -ForegroundColor Yellow
    Write-Host '   2. Apos reiniciar, abra o "Ubuntu" no Menu Iniciar uma vez' -ForegroundColor Yellow
    Write-Host '      para definir usuario/senha do WSL.' -ForegroundColor Yellow
    Write-Host '   3. Volte aqui e rode novamente:' -ForegroundColor Yellow
    Write-Host '         .\setup-brilhamais.ps1' -ForegroundColor Yellow
    Write-Host '      (o script detecta o estado e segue de onde parou)' -ForegroundColor Yellow
    Write-Host '  ===========================================================' -ForegroundColor Yellow
    return $true  # sinaliza "para aqui, precisa reboot"
}

# ======================================================================
#  Fase 4: Docker Desktop (pos-reboot)
# ======================================================================

function Invoke-Phase4 {
    Write-Phase '4' 'Docker Desktop (pos-reboot WSL2)'

    if (-not (Test-WSLReady)) {
        Write-Step 'WSL2/Ubuntu nao detectado - execute a Fase 3 e reinicie antes' 'Err'
        return
    }

    Install-WingetPackage -Id 'Docker.DockerDesktop' -DisplayName 'Docker Desktop'

    $dd = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dd) {
        Write-Step 'Docker Desktop instalado.' 'OK'
        Write-Host ''
        Write-Host '  Abra o Docker Desktop manualmente para aceitar os termos' -ForegroundColor Yellow
        Write-Host '  de servico na primeira execucao. O engine vai subir em WSL2' -ForegroundColor Yellow
        Write-Host '  automaticamente. Caminho:' -ForegroundColor Yellow
        Write-Host "    $dd" -ForegroundColor DarkGray
        Write-Host ''
    }
}

# ======================================================================
#  Fase 5: Git config + VS Code (settings.json + extensoes)
# ======================================================================

function Invoke-Phase5 {
    Write-Phase '5' 'Git config + VS Code (settings + extensoes)'

    # Git config global - SEM user.name/email, conforme conveccao didatica
    # (a maquina e compartilhada com aluno; identidade git fica por repo).
    if (-not (Test-CommandExists 'git')) {
        Write-Step 'git nao encontrado - pulando git config' 'Warn'
    } else {
        Write-Step 'Aplicando git config global (sem user.name/email)...'
        git config --global init.defaultBranch main
        git config --global core.autocrlf input
        git config --global pull.rebase false
        git config --global credential.helper manager
        git config --global core.editor 'code --wait'
        Write-Step 'git config aplicado' 'OK'
    }

    # VS Code user settings.json
    $vscSettings = "$env:APPDATA\Code\User\settings.json"
    $vscDir = Split-Path $vscSettings -Parent
    if (-not (Test-Path $vscDir)) {
        New-Item -ItemType Directory -Path $vscDir -Force | Out-Null
    }

    if (Test-Path $vscSettings) {
        Write-Step 'VS Code settings.json ja existe (renomeie para recriar)' 'Skip'
    } else {
        $settingsJson = @'
{
  "editor.formatOnSave": true,
  "editor.rulers": [88],
  "editor.tabSize": 4,
  "editor.renderWhitespace": "boundary",
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true,
  "files.eol": "\n",
  "terminal.integrated.defaultProfile.windows": "PowerShell",
  "[python]": {
    "editor.defaultFormatter": "ms-python.black-formatter",
    "editor.tabSize": 4,
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": { "source.organizeImports": "explicit" }
  },
  "python.terminal.activateEnvironment": true,
  "python.analysis.typeCheckingMode": "basic",
  "[html]":       { "editor.defaultFormatter": "esbenp.prettier-vscode", "editor.tabSize": 2 },
  "[css]":        { "editor.defaultFormatter": "esbenp.prettier-vscode", "editor.tabSize": 2 },
  "[javascript]": { "editor.defaultFormatter": "esbenp.prettier-vscode", "editor.tabSize": 2 },
  "[json]":       { "editor.defaultFormatter": "esbenp.prettier-vscode", "editor.tabSize": 2 },
  "[jsonc]":      { "editor.defaultFormatter": "esbenp.prettier-vscode", "editor.tabSize": 2 },
  "[markdown]":   { "editor.defaultFormatter": "esbenp.prettier-vscode", "editor.tabSize": 2 },
  "git.autofetch": true,
  "git.confirmSync": false,
  "git.enableSmartCommit": true,
  "gitlens.codeLens.enabled": true,
  "gitlens.currentLine.enabled": true,
  "liveServer.settings.donotShowInfoMsg": true,
  "telemetry.telemetryLevel": "off"
}
'@
        $settingsJson | Out-File -FilePath $vscSettings -Encoding utf8
        Write-Step "VS Code settings.json criado em $vscSettings" 'OK'
    }

    # VS Code extensions
    Update-SessionPath
    if (-not (Test-CommandExists 'code')) {
        Write-Step "VS Code (code) nao esta no PATH - pule esta fase apos abrir o VS Code uma vez ou re-executar o script em terminal novo" 'Warn'
        return
    }

    $extensions = @(
        'ms-python.python',
        'ms-toolsai.jupyter',
        'ms-python.black-formatter',
        'eamodio.gitlens',
        'mhutchie.git-graph',
        'esbenp.prettier-vscode',
        'ritwickdey.LiveServer',
        'rangav.vscode-thunder-client'
    )
    $installed = @(code --list-extensions 2>$null) -split "`r?`n"
    foreach ($ext in $extensions) {
        if ($installed -contains $ext) {
            Write-Step "Extensao $ext ja instalada" 'Skip'
        } else {
            Write-Step "Instalando $ext..."
            $null = code --install-extension $ext --force 2>&1
            Write-Step "$ext instalada" 'OK'
        }
    }
}

# ======================================================================
#  Fase 6: Validacao final
# ======================================================================

function Invoke-Phase6 {
    Write-Phase '6' 'Validacao final (smoke tests)'
    Update-SessionPath

    $checks = @(
        @{ Name = 'winget';  Cmd = { winget --version } },
        @{ Name = 'pwsh';    Cmd = { pwsh -NoProfile -NoLogo -Command '$PSVersionTable.PSVersion.ToString()' } },
        @{ Name = 'python';  Cmd = { py --version } },
        @{ Name = 'code';    Cmd = { (code --version 2>&1 | Select-Object -First 1) } },
        @{ Name = 'gh';      Cmd = { (gh --version 2>&1 | Select-Object -First 1) } },
        @{ Name = 'git';     Cmd = { git --version } },
        @{ Name = 'dbeaver'; Cmd = {
            $p = "$env:LOCALAPPDATA\DBeaver\dbeaver.exe"
            if (Test-Path $p) { (Get-Item $p).VersionInfo.ProductVersion } else { $null }
          } },
        @{ Name = 'wsl';     Cmd = { (wsl -l -v 2>&1 | Out-String).Trim() } },
        @{ Name = 'docker';  Cmd = { docker --version } }
    )

    foreach ($c in $checks) {
        try {
            $output = & $c.Cmd 2>$null
            if ($output) {
                $line = ($output | Out-String).Trim() -replace "`r?`n", ' | '
                Write-Step ("{0,-8} {1}" -f $c.Name, $line) 'OK'
            } else {
                Write-Step ("{0,-8} nao detectado" -f $c.Name) 'Warn'
            }
        } catch {
            Write-Step ("{0,-8} ERRO: {1}" -f $c.Name, $_.Exception.Message) 'Err'
        }
    }
}

# ======================================================================
#  Entry point
# ======================================================================

Write-Host ''
Write-Host '+----------------------------------------------------------------+' -ForegroundColor Cyan
Write-Host '|  configuracao-brilhamais - setup de maquina para ensino       |' -ForegroundColor Cyan
Write-Host '|  https://github.com/rafael-negrao/configuracao-brilhamais     |' -ForegroundColor Cyan
Write-Host '+----------------------------------------------------------------+' -ForegroundColor Cyan
Write-Host ''

switch ($Phase) {
    '0'         { Invoke-Phase0 }
    'preflight' { Invoke-Phase0 }
    '1'         { Invoke-Phase1 }
    '2'         { Invoke-Phase2 }
    '3'         { [void](Invoke-Phase3) }
    '4'         { Invoke-Phase4 }
    '5'         { Invoke-Phase5 }
    '6'         { Invoke-Phase6 }
    'status'    { Invoke-Phase6 }
    'all' {
        Invoke-Phase0
        Invoke-Phase1
        Invoke-Phase2
        $needsReboot = Invoke-Phase3
        if ($needsReboot) {
            Write-Host ''
            Write-Step 'Pausando antes da Fase 4 ate o reboot acontecer.' 'Warn'
            return
        }
        Invoke-Phase4
        Invoke-Phase5
        Invoke-Phase6
    }
}

Write-Host ''
Write-Host 'Concluido.' -ForegroundColor Green
Write-Host ''
