<#
.SYNOPSIS
    Lista as contas de usuario locais da maquina, com destaque para os administradores.

.DESCRIPTION
    Somente leitura - nao altera nada e NAO exige elevacao.

    Para cada conta mostra: nome, se esta habilitada, se e administrador local,
    se e conta interna do Windows, ultimo logon, situacao da senha e se ja existe
    pasta de perfil.

    A associacao ao grupo Administradores e resolvida pelo SID S-1-5-32-544,
    entao funciona em Windows de qualquer idioma.

.PARAMETER AdminsOnly
    Lista apenas as contas que pertencem ao grupo Administradores local.

.PARAMETER IncludeBuiltIn
    Inclui as contas internas do Windows (RID < 1000: Administrador, Convidado,
    DefaultAccount, WDAGUtilityAccount). Por padrao elas ficam de fora.

.PARAMETER Detailed
    Saida em lista detalhada (inclui SID, caminho do perfil, descricao e todos os
    grupos locais de cada conta) em vez da tabela resumida.

.PARAMETER AsObject
    Devolve objetos em vez de imprimir. Util para encadear:
    .\listar-usuarios.ps1 -AsObject | Where-Object Admin | Export-Csv contas.csv

.EXAMPLE
    .\listar-usuarios.ps1
    Tabela com as contas reais da maquina (sem as internas do Windows).

.EXAMPLE
    .\listar-usuarios.ps1 -AdminsOnly
    Apenas os administradores locais.

.EXAMPLE
    .\listar-usuarios.ps1 -IncludeBuiltIn -Detailed
    Tudo, em formato detalhado, incluindo contas internas e grupos.

.NOTES
    Requer Windows 10/11 ou Server 2016+ (modulo Microsoft.PowerShell.LocalAccounts).
    Codigos de saida: 0 = sucesso | 1 = erro.
#>

[CmdletBinding()]
param(
    [switch] $AdminsOnly,
    [switch] $IncludeBuiltIn,
    [switch] $Detailed,
    [switch] $AsObject
)

$ErrorActionPreference = 'Stop'

try {
    # --- membros do grupo Administradores (via SID, independe do idioma) ------
    $adminGroup = Get-LocalGroup -SID 'S-1-5-32-544'
    $adminSids  = @{}
    foreach ($m in Get-LocalGroupMember -Group $adminGroup.Name) {
        $adminSids[$m.SID.Value] = $true
    }

    # --- perfis existentes ----------------------------------------------------
    $perfis = @{}
    try {
        foreach ($p in Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue) {
            $perfis[$p.SID] = $p.LocalPath
        }
    } catch { }

    # --- grupos locais, so quando -Detailed (evita custo desnecessario) -------
    $gruposPorSid = @{}
    if ($Detailed) {
        foreach ($g in Get-LocalGroup) {
            foreach ($m in (Get-LocalGroupMember -Group $g.Name -ErrorAction SilentlyContinue)) {
                if (-not $gruposPorSid.ContainsKey($m.SID.Value)) {
                    $gruposPorSid[$m.SID.Value] = New-Object System.Collections.Generic.List[string]
                }
                $gruposPorSid[$m.SID.Value].Add($g.Name)
            }
        }
    }

    # --- monta o resultado ----------------------------------------------------
    $contas = foreach ($u in (Get-LocalUser | Sort-Object Name)) {
        $sid = $u.SID.Value
        $rid = [int]($sid -split '-')[-1]

        $senha = if ($u.PasswordLastSet -eq $null)      { 'nunca definida' }
                 elseif ($u.PasswordExpires -eq $null)  { 'nao expira' }
                 else                                   { "expira $($u.PasswordExpires.ToString('yyyy-MM-dd'))" }

        [pscustomobject]@{
            Nome        = $u.Name
            Habilitado  = $u.Enabled
            Admin       = [bool]$adminSids[$sid]
            Interna     = ($rid -lt 1000)
            UltimoLogon = if ($u.LastLogon) { $u.LastLogon.ToString('yyyy-MM-dd HH:mm') } else { 'nunca' }
            Senha       = $senha
            Perfil      = if ($perfis.ContainsKey($sid)) { $perfis[$sid] } else { '(sem perfil)' }
            NomeCompleto= $u.FullName
            Descricao   = $u.Description
            SID         = $sid
            RID         = $rid
            Grupos      = if ($gruposPorSid.ContainsKey($sid)) { ($gruposPorSid[$sid] | Sort-Object) -join ', ' } else { '' }
        }
    }

    # --- filtros --------------------------------------------------------------
    if (-not $IncludeBuiltIn) { $contas = $contas | Where-Object { -not $_.Interna } }
    if ($AdminsOnly)          { $contas = $contas | Where-Object { $_.Admin } }
    $contas = @($contas)

    # --- saida ----------------------------------------------------------------
    if ($AsObject) { $contas; exit 0 }

    if ($contas.Count -eq 0) {
        Write-Host "Nenhuma conta corresponde aos filtros informados." -ForegroundColor Yellow
        if (-not $IncludeBuiltIn) {
            Write-Host "Dica: use -IncludeBuiltIn para incluir as contas internas do Windows." -ForegroundColor DarkGray
        }
        exit 0
    }

    Write-Host ""
    Write-Host "Contas locais em $env:COMPUTERNAME" -ForegroundColor Cyan
    $filtros = @()
    if ($AdminsOnly)      { $filtros += 'somente administradores' }
    if (-not $IncludeBuiltIn) { $filtros += 'contas internas ocultas' }
    if ($filtros) { Write-Host "Filtros: $($filtros -join ' | ')" -ForegroundColor DarkGray }
    Write-Host ""

    if ($Detailed) {
        $contas | Format-List Nome, NomeCompleto, Descricao, Habilitado, Admin, Interna,
                              UltimoLogon, Senha, Perfil, Grupos, SID
    }
    else {
        $contas |
            Select-Object @{n='Nome';e={$_.Nome}},
                          @{n='Ativa';e={ if ($_.Habilitado) { 'sim' } else { 'nao' } }},
                          @{n='Admin';e={ if ($_.Admin) { 'SIM' } else { '' } }},
                          @{n='Ultimo logon';e={$_.UltimoLogon}},
                          @{n='Senha';e={$_.Senha}},
                          @{n='Perfil';e={ if ($_.Perfil -eq '(sem perfil)') { 'nao criado' } else { 'ok' } }} |
            Format-Table -AutoSize
    }

    # --- resumo ---------------------------------------------------------------
    $totalAdmins = @($contas | Where-Object { $_.Admin }).Count
    $adminsAtivos = @($contas | Where-Object { $_.Admin -and $_.Habilitado }).Count
    Write-Host ("Total: {0} conta(s) | {1} administrador(es), {2} habilitado(s)." -f $contas.Count, $totalAdmins, $adminsAtivos) -ForegroundColor Gray
    if (-not $Detailed) {
        Write-Host "Use -Detailed para ver SID, perfil e grupos." -ForegroundColor DarkGray
    }
    Write-Host ""

    exit 0
}
catch {
    Write-Host "ERRO: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
