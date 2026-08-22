<#
.SYNOPSIS
    Remove um usuario local de administrador criado pelo criar-usuario-admin.ps1.

.DESCRIPTION
    Contrapartida do criar-usuario-admin.ps1. Script idempotente: se a conta nao
    existir, informa e sai com sucesso.

    Por padrao remove APENAS a conta, preservando a pasta de perfil
    (C:\Users\<usuario>) para nao destruir dados. Use -RemoveProfile para apagar
    o perfil tambem.

    Protecoes (o script se recusa a prosseguir):
    - nao remove a conta com a qual voce esta logado;
    - nao remove contas internas do Windows (RID < 1000: Administrador,
      Convidado, DefaultAccount, WDAGUtilityAccount);
    - nao remove o ultimo administrador local habilitado da maquina;
    - pede confirmacao digitada, a menos que -Force seja informado.

.PARAMETER UserName
    Nome do usuario local a remover. Padrao: admin_brilhamais

.PARAMETER RemoveProfile
    Alem da conta, apaga a pasta de perfil e o registro correspondente.
    DESTRUTIVO E IRREVERSIVEL - todos os arquivos do usuario sao perdidos.

.PARAMETER Force
    Nao pede confirmacao. Use com cuidado, sobretudo junto com -RemoveProfile.

.EXAMPLE
    .\remover-usuario-admin.ps1
    Remove a conta admin_brilhamais, preservando a pasta de perfil.
    Pede confirmacao digitada.

.EXAMPLE
    .\remover-usuario-admin.ps1 -RemoveProfile
    Remove a conta E apaga C:\Users\admin_brilhamais.

.EXAMPLE
    .\remover-usuario-admin.ps1 -UserName 'suporte_bm' -Force
    Remove a conta suporte_bm sem perguntar, mantendo o perfil.

.NOTES
    Requer Windows 10/11 ou Server 2016+ (modulo Microsoft.PowerShell.LocalAccounts).
    Codigos de saida: 0 = sucesso (ou nada a fazer) | 1 = erro | 2 = cancelado.
#>

[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string] $UserName = 'admin_brilhamais',

    [switch] $RemoveProfile,

    [switch] $Force,

    # Uso interno: mantem a janela elevada aberta para exibir o resultado.
    [switch] $KeepOpen
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- log ------
$scriptDir  = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$scriptPath = $PSCommandPath
$logName    = if ($scriptPath) { [IO.Path]::GetFileNameWithoutExtension($scriptPath) } else { 'remover-usuario-admin' }
$logPath    = Join-Path $scriptDir "$logName.log"

function Write-Log {
    param(
        [Parameter(Mandatory)] [string] $Message,
        [ValidateSet('INFO', 'OK', 'AVISO', 'ERRO')] [string] $Level = 'INFO'
    )
    $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line  = "[$stamp] [$Level] $Message"
    $color = switch ($Level) {
        'OK'    { 'Green' }
        'AVISO' { 'Yellow' }
        'ERRO'  { 'Red' }
        default { 'Gray' }
    }
    Write-Host $line -ForegroundColor $color
    try { Add-Content -Path $logPath -Value $line -Encoding utf8 } catch { }
}

# ----------------------------------------------------- auto-elevacao -------
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdmin   = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Log "Sessao nao elevada. Solicitando elevacao via UAC..." 'AVISO'

    if (-not $scriptPath) {
        Write-Log "Nao foi possivel localizar o arquivo do script para reexecutar elevado. Abra um PowerShell como administrador e rode novamente." 'ERRO'
        exit 1
    }

    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$scriptPath`"",
                 '-UserName', "`"$UserName`"")
    if ($RemoveProfile) { $argList += '-RemoveProfile' }
    if ($Force)         { $argList += '-Force' }
    $argList += '-KeepOpen'

    try {
        $proc = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList $argList
        exit $proc.ExitCode
    }
    catch {
        Write-Log "Elevacao cancelada ou negada: $($_.Exception.Message)" 'ERRO'
        exit 1
    }
}

# ------------------------------------------------------------ execucao -----
try {
    Write-Log "=== Inicio | alvo: '$UserName' | executando como: $($identity.Name) ==="

    # 1) A conta existe? -------------------------------------------------------
    $user = Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue
    if (-not $user) {
        Write-Log "Usuario '$UserName' nao existe nesta maquina. Nada a fazer." 'OK'
        if ($KeepOpen) { Write-Host ""; Read-Host "Pressione ENTER para fechar" | Out-Null }
        exit 0
    }

    $userSid = $user.SID.Value
    Write-Log "Encontrado: '$UserName' (SID $userSid)."

    # 2) Protecao: conta interna do Windows ------------------------------------
    $rid = [int]($userSid -split '-')[-1]
    if ($rid -lt 1000) {
        throw "'$UserName' e uma conta interna do Windows (RID $rid). Remocao bloqueada por seguranca."
    }

    # 3) Protecao: conta em uso ------------------------------------------------
    if ($identity.User.Value -eq $userSid) {
        throw "'$UserName' e a conta com a qual voce esta logado. Remocao bloqueada."
    }

    # 4) Protecao: ultimo administrador habilitado -----------------------------
    $adminGroup = Get-LocalGroup -SID 'S-1-5-32-544'
    $isMemberOfAdmins = [bool](Get-LocalGroupMember -Group $adminGroup.Name |
                               Where-Object { $_.SID.Value -eq $userSid })

    if ($isMemberOfAdmins) {
        # Nao filtra por ObjectClass: o valor e localizado (pt-BR vs en-US) e o
        # PS 5.1 le .ps1 sem BOM como ANSI, o que corromperia a comparacao.
        # Resolver por SID com Get-LocalUser ja descarta grupos e contas de dominio.
        $outrosAdmins = @(
            Get-LocalGroupMember -Group $adminGroup.Name |
            Where-Object { $_.SID.Value -ne $userSid } |
            ForEach-Object { Get-LocalUser -SID $_.SID -ErrorAction SilentlyContinue } |
            Where-Object { $_ -and $_.Enabled }
        )

        if ($outrosAdmins.Count -eq 0) {
            throw "'$UserName' e o unico administrador local habilitado. Remove-lo deixaria a maquina sem administrador. Remocao bloqueada."
        }
        Write-Log "Outros administradores habilitados: $($outrosAdmins.Name -join ', ')."
    }
    else {
        Write-Log "A conta nao pertence ao grupo '$($adminGroup.Name)'." 'AVISO'
    }

    # 5) Sessao ativa? ---------------------------------------------------------
    $sessaoAtiva = $false
    try {
        $explorers = Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" -ErrorAction SilentlyContinue
        foreach ($p in $explorers) {
            $owner = Invoke-CimMethod -InputObject $p -MethodName GetOwner -ErrorAction SilentlyContinue
            if ($owner.User -eq $UserName) { $sessaoAtiva = $true }
        }
    } catch { }
    if ($sessaoAtiva) {
        Write-Log "'$UserName' parece ter uma sessao aberta. Faca logoff dessa conta antes de continuar." 'AVISO'
    }

    # 6) Perfil ----------------------------------------------------------------
    $perfil = Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue |
              Where-Object { $_.SID -eq $userSid }
    $perfilPath = if ($perfil) { $perfil.LocalPath } else { $null }

    if ($perfilPath) {
        Write-Log "Perfil encontrado em: $perfilPath"
    } else {
        Write-Log "Nenhum perfil criado para esta conta (o usuario nunca fez logon)."
    }

    # 7) Confirmacao -----------------------------------------------------------
    if (-not $Force) {
        Write-Host ""
        Write-Host "  ATENCAO - operacao irreversivel" -ForegroundColor Yellow
        Write-Host "  Conta a remover : $UserName ($userSid)" -ForegroundColor Yellow
        if ($RemoveProfile -and $perfilPath) {
            Write-Host "  Perfil          : $perfilPath  <-- SERA APAGADO" -ForegroundColor Red
        } elseif ($perfilPath) {
            Write-Host "  Perfil          : $perfilPath  (preservado)" -ForegroundColor Gray
        }
        Write-Host ""
        $resp = Read-Host "Digite o nome da conta para confirmar"
        if ($resp -ne $UserName) {
            Write-Log "Confirmacao nao conferiu. Operacao cancelada. Nada foi alterado." 'AVISO'
            if ($KeepOpen) { Write-Host ""; Read-Host "Pressione ENTER para fechar" | Out-Null }
            exit 2
        }
    }

    # 8) Remover do grupo ------------------------------------------------------
    if ($isMemberOfAdmins) {
        Remove-LocalGroupMember -Group $adminGroup.Name -Member $UserName
        Write-Log "Removido do grupo '$($adminGroup.Name)'." 'OK'
    }

    # 9) Remover a conta -------------------------------------------------------
    Remove-LocalUser -Name $UserName
    Write-Log "Conta '$UserName' removida." 'OK'

    # 10) Remover o perfil -----------------------------------------------------
    if ($RemoveProfile) {
        if ($perfil) {
            Remove-CimInstance -InputObject $perfil
            Write-Log "Perfil removido: $perfilPath" 'OK'
        } else {
            Write-Log "Nao havia perfil a remover." 'OK'
        }
    }
    elseif ($perfilPath) {
        Write-Log "Perfil preservado em '$perfilPath'. Use -RemoveProfile para apaga-lo." 'AVISO'
    }

    Write-Log "=== SUCESSO ===" 'OK'
    Write-Host ""
    Write-Host "Administradores locais restantes:" -ForegroundColor Gray
    Get-LocalGroupMember -SID 'S-1-5-32-544' | Select-Object Name, ObjectClass | Format-Table -AutoSize
    Write-Host "Log: $logPath" -ForegroundColor DarkGray

    if ($KeepOpen) { Write-Host ""; Read-Host "Pressione ENTER para fechar" | Out-Null }
    exit 0
}
catch {
    Write-Log $_.Exception.Message 'ERRO'
    if ($KeepOpen) { Write-Host ""; Read-Host "Pressione ENTER para fechar" | Out-Null }
    exit 1
}
