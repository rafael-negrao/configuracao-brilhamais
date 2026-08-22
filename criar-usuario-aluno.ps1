<#
.SYNOPSIS
    Cria a conta local de uma turma de alunos, no formato aluno_<turma>_<ano>.

.DESCRIPTION
    Variante do criar-usuario-admin.ps1 voltada para uso em sala de aula.

    O nome da conta e montado a partir da turma e do ano:
        Turma 3A, ano 2026  ->  aluno_3A_2026

    A senha padrao tambem deriva do ano:
        Ano 2026  ->  Aluno@2026

    Essa senha e proposital: curta, facil de ditar em voz alta e igual para
    todas as turmas do mesmo ano. Ela satisfaz a politica de complexidade
    padrao do Windows (maiuscula, minuscula, numero e simbolo), mas NAO e
    uma senha forte - veja a secao de seguranca abaixo.

    Script idempotente: se a conta ja existir, apenas redefine a senha e os
    dados. Faz auto-elevacao (UAC) quando necessario e grava log ao lado do
    script.

.PARAMETER Turma
    Identificador da turma. Aceita letras, numeros e hifen (ex: 3A, 1B, 101,
    INFO-2). Ate 9 caracteres, para o nome final caber no limite de 20 do
    Windows.

.PARAMETER Ano
    Ano letivo. Padrao: ano corrente. Aceita de 2000 a 2100.

.PARAMETER Password
    Sobrescreve a senha padrao Aluno@<ano>.

.PARAMETER TipoConta
    'Administrador' (padrao) coloca a conta no grupo Administradores.
    'Padrao' coloca no grupo Usuarios, sem privilegio administrativo.

.PARAMETER ExigirTrocaSenha
    Marca a senha como expirada, obrigando o aluno a definir uma nova no
    primeiro logon. Desligado por padrao.

.PARAMETER Force
    Nao pede confirmacao.

.EXAMPLE
    .\criar-usuario-aluno.ps1 -Turma 3A
    Cria aluno_3A_<ano corrente> com senha Aluno@<ano corrente>, como administrador.

.EXAMPLE
    .\criar-usuario-aluno.ps1 -Turma 3A -Ano 2026
    Cria aluno_3A_2026 com senha Aluno@2026.

.EXAMPLE
    .\criar-usuario-aluno.ps1 -Turma 1B -TipoConta Padrao
    Cria a conta sem privilegio de administrador.

.EXAMPLE
    '3A','3B','1A' | ForEach-Object { .\criar-usuario-aluno.ps1 -Turma $_ -Ano 2026 -Force }
    Cria varias turmas de uma vez.

.NOTES
    SEGURANCA: uma senha previsivel como Aluno@2026 e adequada a um laboratorio
    de aula, onde a prioridade e o aluno conseguir entrar. NAO use esse padrao
    em maquina com acesso remoto habilitado (RDP), exposta na internet, ou que
    guarde dados de terceiros. Combinar senha previsivel com privilegio de
    administrador amplia bastante o estrago possivel - considere
    -TipoConta Padrao quando o aluno nao precisar instalar programas.

    Requer Windows 10/11 ou Server 2016+ (modulo Microsoft.PowerShell.LocalAccounts).
    Codigos de saida: 0 = sucesso | 1 = erro | 2 = cancelado.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidatePattern('^[A-Za-z0-9\-]{1,9}$')]
    [string] $Turma,

    [ValidateRange(2000, 2100)]
    [int] $Ano = (Get-Date).Year,

    [string] $Password,

    [ValidateSet('Administrador', 'Padrao')]
    [string] $TipoConta = 'Administrador',

    [switch] $ExigirTrocaSenha,

    [switch] $Force,

    # Uso interno: mantem a janela elevada aberta para exibir o resultado.
    [switch] $KeepOpen
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- log ------
$scriptDir  = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$scriptPath = $PSCommandPath
$logName    = if ($scriptPath) { [IO.Path]::GetFileNameWithoutExtension($scriptPath) } else { 'criar-usuario-aluno' }
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

# ------------------------------------------------- nome da conta e senha ---
$UserName = "aluno_${Turma}_${Ano}"
if (-not $Password) { $Password = "Aluno@$Ano" }

if ($UserName.Length -gt 20) {
    Write-Log "O nome '$UserName' tem $($UserName.Length) caracteres; o limite do Windows e 20. Use uma turma mais curta." 'ERRO'
    exit 1
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
                 '-Turma', "`"$Turma`"",
                 '-Ano', "$Ano",
                 '-TipoConta', "$TipoConta",
                 '-Password', "`"$Password`"")
    if ($ExigirTrocaSenha) { $argList += '-ExigirTrocaSenha' }
    if ($Force)            { $argList += '-Force' }
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
    Write-Log "=== Inicio | turma '$Turma' | ano $Ano | conta '$UserName' | tipo $TipoConta ==="

    # Grupo alvo, resolvido por SID (independe do idioma do Windows) ----------
    $groupSid   = if ($TipoConta -eq 'Administrador') { 'S-1-5-32-544' } else { 'S-1-5-32-545' }
    $groupName  = (Get-LocalGroup -SID $groupSid).Name

    $existing = Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue

    # Confirmacao ------------------------------------------------------------
    if (-not $Force) {
        Write-Host ""
        Write-Host "  Conta  : $UserName"        -ForegroundColor Cyan
        Write-Host "  Turma  : $Turma / $Ano"    -ForegroundColor Cyan
        Write-Host "  Senha  : $Password"        -ForegroundColor Cyan
        Write-Host "  Grupo  : $groupName"       -ForegroundColor Cyan
        if ($existing) {
            Write-Host "  Aviso  : a conta JA EXISTE - a senha sera redefinida." -ForegroundColor Yellow
        }
        if ($TipoConta -eq 'Administrador') {
            Write-Host "  Aviso  : conta com privilegio de ADMINISTRADOR e senha previsivel." -ForegroundColor Yellow
        }
        Write-Host ""
        $resp = Read-Host "Confirma? (S/N)"
        if ($resp -notmatch '^[SsYy]') {
            Write-Log "Operacao cancelada pelo usuario. Nada foi alterado." 'AVISO'
            if ($KeepOpen) { Write-Host ""; Read-Host "Pressione ENTER para fechar" | Out-Null }
            exit 2
        }
    }

    $securePw    = ConvertTo-SecureString $Password -AsPlainText -Force
    $fullName    = "Aluno $Turma/$Ano"
    $description = "Conta de aluno - turma $Turma, ano letivo $Ano"

    # Criar ou atualizar -----------------------------------------------------
    if ($existing) {
        Set-LocalUser -Name $UserName -Password $securePw `
                      -FullName $fullName -Description $description
        Write-Log "Conta '$UserName' ja existia - senha e dados atualizados." 'OK'
    }
    else {
        New-LocalUser -Name $UserName -Password $securePw `
                      -FullName $fullName -Description $description `
                      -AccountNeverExpires -PasswordNeverExpires | Out-Null
        Write-Log "Conta '$UserName' criada." 'OK'
    }

    if (-not $ExigirTrocaSenha) {
        Set-LocalUser -Name $UserName -PasswordNeverExpires $true
    }

    # Grupo ------------------------------------------------------------------
    $jaMembro = Get-LocalGroupMember -Group $groupName |
                Where-Object { $_.Name -like "*\$UserName" }
    if ($jaMembro) {
        Write-Log "Ja era membro de '$groupName'." 'OK'
    }
    else {
        Add-LocalGroupMember -Group $groupName -Member $UserName
        Write-Log "Adicionado ao grupo '$groupName'." 'OK'
    }

    # Se virou conta padrao, tirar de Administradores -------------------------
    if ($TipoConta -eq 'Padrao') {
        $adminName = (Get-LocalGroup -SID 'S-1-5-32-544').Name
        $eraAdmin = Get-LocalGroupMember -Group $adminName |
                    Where-Object { $_.Name -like "*\$UserName" }
        if ($eraAdmin) {
            Remove-LocalGroupMember -Group $adminName -Member $UserName
            Write-Log "Removido do grupo '$adminName' (conta agora e padrao)." 'OK'
        }
    }

    Enable-LocalUser -Name $UserName
    Write-Log "Conta habilitada." 'OK'

    # Troca de senha no primeiro logon ---------------------------------------
    if ($ExigirTrocaSenha) {
        $adsi = [ADSI]"WinNT://./$UserName,user"
        $adsi.PasswordExpired = 1
        $adsi.SetInfo()
        Write-Log "O aluno tera de definir uma nova senha no primeiro logon." 'OK'
    }

    # Resumo -----------------------------------------------------------------
    Write-Log "=== SUCESSO ===" 'OK'
    Write-Host ""
    Write-Host "  ------------------------------------------" -ForegroundColor Green
    Write-Host "   Entregar ao aluno:"                        -ForegroundColor Green
    Write-Host ""
    Write-Host "     Usuario : $UserName"                     -ForegroundColor White
    Write-Host "     Senha   : $Password"                     -ForegroundColor White
    Write-Host ""
    Write-Host "  ------------------------------------------" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Turma $Turma / $Ano | grupo: $groupName" -ForegroundColor Gray
    if ($ExigirTrocaSenha) {
        Write-Host "  Sera pedida a troca da senha no primeiro logon." -ForegroundColor Gray
    }
    Write-Host "  O perfil C:\Users\$UserName sera criado no primeiro logon." -ForegroundColor DarkGray
    Write-Host "  Log: $logPath" -ForegroundColor DarkGray

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
    if ($securePw) { $securePw.Dispose() }
}
