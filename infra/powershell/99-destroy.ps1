#Requires -Version 7.0

[CmdletBinding(
    SupportsShouldProcess = $true,
    ConfirmImpact = "High"
)]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ServerName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseName,

    [string]$ExpectedSubscriptionId = "",

    [string]$ConfirmationText = "",

    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-ExpectedSubscription {

    param(
        [string]$ExpectedSubscriptionId,

        [bool]$RequireExpectedSubscription = $false
    )

    $CurrentContext = Get-AzContext `
        -ErrorAction Stop

    if (-not $CurrentContext) {
        throw "Nenhum contexto Azure ativo foi encontrado."
    }

    if (
        $RequireExpectedSubscription -and
        [string]::IsNullOrWhiteSpace(
            $ExpectedSubscriptionId
        )
    ) {
        throw @"
SECURITY: operação destrutiva solicitada,
mas -ExpectedSubscriptionId não foi informado.

Nenhum recurso será excluído.
"@
    }

    if (
        -not [string]::IsNullOrWhiteSpace(
            $ExpectedSubscriptionId
        )
    ) {

        try {
            $ExpectedGuid = [guid]$ExpectedSubscriptionId
        }
        catch {
            throw "ExpectedSubscriptionId não possui formato GUID válido."
        }

        if (
            $CurrentContext.Subscription.Id -ne
            $ExpectedGuid.ToString()
        ) {
            throw @"
SECURITY: subscription ativa não corresponde
à subscription esperada.

Nenhum recurso será excluído.
"@
        }
    }

    return $CurrentContext
}

Write-Host ""
Write-Host "===================================================="
Write-Host " DIO Azure SQL Secure Lab - Protected Cleanup"
Write-Host "===================================================="
Write-Host ""

if ($Apply) {
    Write-Host "[MODE] APPLY"
    Write-Host "[DANGER] Exclusão permanente poderá ocorrer."
}
else {
    Write-Host "[MODE] PLAN / DRY-RUN"
    Write-Host "[INFO] Nenhum recurso será excluído."
}

#
# Context
#

$Context = Assert-ExpectedSubscription `
    -ExpectedSubscriptionId $ExpectedSubscriptionId `
    -RequireExpectedSubscription $Apply.IsPresent

Write-Host "[OK] Contexto Azure ativo."

if (
    -not [string]::IsNullOrWhiteSpace(
        $ExpectedSubscriptionId
    )
) {
    Write-Host "[OK] Subscription ativa validada."
}

#
# Resource Group
#

Write-Host ""
Write-Host "[INFO] Verificando Resource Group..."

try {

    $ResourceGroup = `
        Get-AzResourceGroup `
            -ErrorAction Stop |
        Where-Object {
            $_.ResourceGroupName -eq
                $ResourceGroupName
        } |
        Select-Object -First 1
}
catch {
    throw "SECURITY: falha ao consultar Resource Groups."
}

if (-not $ResourceGroup) {

    Write-Host "[OK] Resource Group não existe."
    Write-Host "[SKIP] Nenhuma exclusão necessária."

    return
}

Write-Host "[OK] Resource Group encontrado: $ResourceGroupName"

#
# SQL Server
#

Write-Host ""
Write-Host "[INFO] Verificando identidade do laboratório..."

try {

    $SqlServer = `
        Get-AzSqlServer `
            -ResourceGroupName $ResourceGroupName `
            -ErrorAction Stop `
            -WhatIf:$false |
        Where-Object {
            $_.ServerName -eq $ServerName
        } |
        Select-Object -First 1
}
catch {
    throw "SECURITY: falha ao consultar SQL logical servers."
}

if (-not $SqlServer) {
    throw @"
SECURITY: SQL logical server esperado não encontrado.

Cleanup bloqueado.
"@
}

Write-Host "[OK] SQL logical server esperado encontrado."

#
# Databases
#

try {

    $SqlDatabases = @(
        Get-AzSqlDatabase `
            -ResourceGroupName $ResourceGroupName `
            -ServerName $ServerName `
            -ErrorAction Stop `
            -WhatIf:$false
    )
}
catch {
    throw "SECURITY: falha ao consultar databases."
}

$Database = @(
    $SqlDatabases |
        Where-Object {
            $_.DatabaseName -eq $DatabaseName
        }
) |
    Select-Object -First 1

if (-not $Database) {
    throw @"
SECURITY: database esperada não encontrada.

Cleanup bloqueado.
"@
}

Write-Host "[OK] Azure SQL Database esperada encontrada."

$AllowedDatabaseNames = @(
    "master",
    $DatabaseName
)

$UnexpectedDatabases = @(
    $SqlDatabases |
        Where-Object {
            $_.DatabaseName -notin
                $AllowedDatabaseNames
        }
)

if ($UnexpectedDatabases.Count -gt 0) {

    Write-Host "[FAIL] Databases inesperadas encontradas:"

    $UnexpectedDatabases |
        Select-Object DatabaseName |
        Format-Table -AutoSize

    throw @"
SECURITY: databases inesperadas encontradas.

Cleanup bloqueado.
"@
}

Write-Host `
    "[OK] Apenas as databases esperadas foram encontradas."

#
# Ownership tags
#

Write-Host ""
Write-Host "[INFO] Verificando tags de proteção..."

$RequiredTags = @{
    Project   = "dio-azure-sql-secure-lab"
    Lifecycle = "Temporary"
}

foreach ($Tag in $RequiredTags.GetEnumerator()) {

    if (
        $null -eq $SqlServer.Tags -or
        -not $SqlServer.Tags.ContainsKey($Tag.Key) -or
        $SqlServer.Tags[$Tag.Key] -ne $Tag.Value
    ) {
        throw "SECURITY: tag inválida no SQL Server: $($Tag.Key)"
    }

    if (
        $null -eq $Database.Tags -or
        -not $Database.Tags.ContainsKey($Tag.Key) -or
        $Database.Tags[$Tag.Key] -ne $Tag.Value
    ) {
        throw "SECURITY: tag inválida na Database: $($Tag.Key)"
    }

    Write-Host `
        "[OK] Tag de proteção validada: $($Tag.Key)"
}

#
# Complete RG inventory
#

Write-Host ""
Write-Host "[INFO] Inventariando Resource Group..."

try {

    $RgResources = @(
        Get-AzResource `
            -ResourceGroupName $ResourceGroupName `
            -ErrorAction Stop
    )
}
catch {
    throw "SECURITY: falha ao inventariar o Resource Group."
}

if ($RgResources.Count -eq 0) {
    throw @"
SECURITY: nenhum recurso foi retornado pelo inventário.

Cleanup bloqueado.
"@
}

Write-Host `
    "[INFO] Recursos encontrados: $($RgResources.Count)"

$AllowedResourceIds = @(
    $SqlServer.ResourceId
)

$AllowedResourceIds += @(
    $SqlDatabases |
        Where-Object {
            $_.DatabaseName -in
                $AllowedDatabaseNames
        } |
        ForEach-Object {
            $_.ResourceId
        }
)

$UnexpectedResources = @(
    $RgResources |
        Where-Object {
            $_.ResourceId -notin
                $AllowedResourceIds
        }
)

if ($UnexpectedResources.Count -gt 0) {

    Write-Host ""
    Write-Host "[FAIL] Recursos inesperados encontrados:"

    $UnexpectedResources |
        Select-Object `
            Name,
            ResourceType |
        Format-Table -AutoSize

    throw @"
SECURITY: o Resource Group contém recursos
fora da allowlist do laboratório.

Cleanup bloqueado.
"@
}

Write-Host `
    "[OK] Inventário completo corresponde à allowlist do laboratório."

#
# Resource Locks
#

Write-Host ""
Write-Host "[INFO] Verificando Resource Locks..."

try {

    $ResourceLocks = @(
        Get-AzResourceLock `
            -ResourceGroupName $ResourceGroupName `
            -ErrorAction Stop
    )
}
catch {
    throw "SECURITY: falha ao consultar Resource Locks."
}

if ($ResourceLocks.Count -gt 0) {

    Write-Host "[FAIL] Resource Locks encontrados:"

    $ResourceLocks |
        Select-Object `
            Name,
            LockLevel |
        Format-Table -AutoSize

    throw @"
SECURITY: existem Resource Locks.

O script não removerá locks automaticamente.
Cleanup bloqueado.
"@
}

Write-Host "[OK] Nenhum Resource Lock encontrado."

#
# Dry-run
#

Write-Host ""
Write-Host "[INFO] Resource Group elegível para cleanup."
Write-Host "[INFO] Inventário e tags foram validados."

if (-not $Apply) {

    Write-Host ""
    Write-Host "===================================================="
    Write-Host " Cleanup plan completed."
    Write-Host " Nenhum recurso Azure foi excluído."
    Write-Host "===================================================="
    Write-Host ""

    return
}

#
# Explicit text confirmation
#

if ($ConfirmationText -cne $ResourceGroupName) {

    throw @"
SECURITY: confirmação textual inválida.

Para permitir a exclusão, informe exatamente:

-ConfirmationText "$ResourceGroupName"
"@
}

Write-Host "[DANGER] Confirmação textual validada."

if (
    $PSCmdlet.ShouldProcess(
        $ResourceGroupName,
        "Excluir Resource Group e todos os recursos contidos nele"
    )
) {

    Remove-AzResourceGroup `
        -Name $ResourceGroupName `
        -ErrorAction Stop

    Write-Host ""
    Write-Host "[OK] Solicitação de exclusão enviada."
}
