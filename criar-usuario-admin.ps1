<#
.SYNOPSIS
    Cria (ou reconfigura) um usuario local com perfil de administrador.

.DESCRIPTION
    Script idempotente: pode ser executado varias vezes na mesma maquina sem erro.
    - Cria o usuario se nao existir; se existir, apenas redefine a senha.
    - Adiciona ao grupo Administradores local via SID (S-1-5-32-544), funcionando
      em Windows de qualquer idioma.
    - Habilita a conta e define senha que nunca expira.
    - Faz auto-elevacao (UAC) caso nao esteja rodando como administrador.
    - Gera log ao lado do script (mesmo nome-base, extensao .log).

.PARAMETER UserName
    Nome do usuario local. Padrao: admin_brilhamais

.PARAMETER Password
    Senha em texto puro. Se omitida, o script solicita de forma segura.
    ATENCAO: ao usar este parametro com auto-elevacao, a senha trafega na linha
    de comando do processo elevado e fica visivel na lista de processos por
    alguns instantes. Para uso sensivel, execute o script a partir de um
    PowerShell ja elevado e deixe que ele solicite a senha.

.PARAMETER FullName
    Nome completo exibido. Padrao: Admin BrilhaMais

.PARAMETER Description
    Descricao da conta. Padrao: Conta administrativa local BrilhaMais

.PARAMETER PasswordExpires
    Se informado, a senha segue a politica de expiracao do sistema.
    Por padrao a senha nunca expira.

.EXAMPLE
    .\criar-usuario-admin.ps1
    Usa os padroes e solicita a senha interativamente.

.EXAMPLE
    .\criar-usuario-admin.ps1 -Password '<SENHA_AQUI>'
    Execucao desatendida com os demais valores padrao.
    Nunca versione uma senha real dentro deste arquivo.

.EXAMPLE
    .\criar-usuario-admin.ps1 -UserName 'suporte_bm' -Password $env:BM_ADMIN_PWD
    Cria outro usuario administrador lendo a senha de uma variavel de ambiente.

.NOTES
    Requer Windows 10/11 ou Server 2016+ (modulo Microsoft.PowerShell.LocalAccounts).
    Codigos de saida: 0 = sucesso | 1 = erro.
#>

[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string] $UserName = 'admin_brilhamais',

    [string] $Password,

    [string] $FullName = 'Admin BrilhaMais',

    [string] $Description = 'Conta administrativa local BrilhaMais',

    [switch] $PasswordExpires,

    # Uso interno: mantem a janela elevada aberta para exibir o resultado.
    [switch] $KeepOpen
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- log ------
$scriptDir  = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$scriptPath = $PSCommandPath
$logName    = if ($scriptPath) { [IO.Path]::GetFileNameWithoutExtension($scriptPath) } else { 'criar-usuario-admin' }
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
                 '-UserName', "`"$UserName`"",
                 '-FullName', "`"$FullName`"",
                 '-Description', "`"$Description`"")
    if ($Password)        { $argList += @('-Password', "`"$Password`"") }
    if ($PasswordExpires) { $argList += '-PasswordExpires' }
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
    Write-Log "=== Inicio | usuario alvo: '$UserName' | executando como: $($identity.Name) ==="

    # Senha ------------------------------------------------------------------
    if ($Password) {
        $securePw = ConvertTo-SecureString $Password -AsPlainText -Force
    }
    else {
        $securePw = Read-Host -Prompt "Digite a senha para '$UserName'" -AsSecureString
        $confirm  = Read-Host -Prompt "Confirme a senha" -AsSecureString

        $b1 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePw)
        $b2 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirm)
        try {
            $p1 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b1)
            $p2 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b2)
            if ([string]::IsNullOrWhiteSpace($p1)) { throw "A senha nao pode ser vazia." }
            if ($p1 -ne $p2)                       { throw "As senhas nao conferem." }
        }
        finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b1)
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b2)
        }
    }

    # Criar ou atualizar ------------------------------------------------------
    $existing = Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue

    if ($existing) {
        Set-LocalUser -Name $UserName -Password $securePw `
                      -FullName $FullName -Description $Description
        Write-Log "Usuario '$UserName' ja existia - senha e dados atualizados." 'OK'
    }
    else {
        $newParams = @{
            Name              = $UserName
            Password          = $securePw
            FullName          = $FullName
            Description       = $Description
            AccountNeverExpires = $true
        }
        if (-not $PasswordExpires) { $newParams['PasswordNeverExpires'] = $true }

        New-LocalUser @newParams | Out-Null
        Write-Log "Usuario '$UserName' criado." 'OK'
    }

    if (-not $PasswordExpires) {
        Set-LocalUser -Name $UserName -PasswordNeverExpires $true
    }

    # Grupo Administradores (via SID, independe do idioma) ---------------------
    $adminGroup = Get-LocalGroup -SID 'S-1-5-32-544'
    $isMember = Get-LocalGroupMember -Group $adminGroup.Name |
                Where-Object { $_.Name -like "*\$UserName" }

    if ($isMember) {
        Write-Log "Ja era membro do grupo '$($adminGroup.Name)'." 'OK'
    }
    else {
        Add-LocalGroupMember -Group $adminGroup.Name -Member $UserName
        Write-Log "Adicionado ao grupo '$($adminGroup.Name)'." 'OK'
    }

    # Habilitar ---------------------------------------------------------------
    Enable-LocalUser -Name $UserName
    Write-Log "Conta habilitada." 'OK'

    # Resumo ------------------------------------------------------------------
    $final = Get-LocalUser -Name $UserName
    Write-Log "=== SUCESSO ===" 'OK'
    Write-Host ""
    $final | Select-Object Name, FullName, Enabled, PasswordExpires, AccountExpires, Description |
        Format-List
    Write-Host "Perfil em C:\Users\$UserName sera criado no primeiro logon." -ForegroundColor DarkGray
    Write-Host "Log: $logPath" -ForegroundColor DarkGray

    if ($KeepOpen) { Write-Host ""; Read-Host "Pressione ENTER para fechar" | Out-Null }
    exit 0
}
catch {
    Write-Log $_.Exception.Message 'ERRO'
    if ($_.Exception.Message -match 'senha|password') {
        Write-Log "Verifique a politica de complexidade de senha da maquina (secpol.msc > Politicas de Senha)." 'AVISO'
    }
    if ($KeepOpen) { Write-Host ""; Read-Host "Pressione ENTER para fechar" | Out-Null }
    exit 1
}
finally {
    if ($securePw)     { $securePw.Dispose() }
    if ($confirm)      { $confirm.Dispose() }
    Remove-Variable Password -ErrorAction SilentlyContinue
}
