#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================"
Write-Host " DIO Azure SQL Secure Lab - Pre-requisites"
Write-Host "============================================"
Write-Host ""

#
# PowerShell
#

Write-Host "[INFO] Verificando PowerShell..."

$PowerShellVersion = $PSVersionTable.PSVersion

Write-Host "[INFO] Versão detectada: $PowerShellVersion"

if ($PowerShellVersion.Major -lt 7) {
    throw "PowerShell 7 ou superior é obrigatório."
}

Write-Host "[OK] PowerShell compatível."

#
# Az module
#

Write-Host ""
Write-Host "[INFO] Verificando módulo Az..."

$AzModule = Get-Module `
    -ListAvailable `
    -Name Az |
    Sort-Object Version -Descending |
    Select-Object -First 1

if (-not $AzModule) {
    throw "O módulo Az não está instalado."
}

Write-Host "[OK] Módulo Az encontrado."
Write-Host "[INFO] Versão Az: $($AzModule.Version)"

#
# Required cmdlets
#

Write-Host ""
Write-Host "[INFO] Verificando cmdlets Azure..."

$RequiredCommands = @(
    "Connect-AzAccount",
    "Get-AzContext",
    "Get-AzSubscription",
    "Set-AzContext",
    "New-AzResourceGroup",
    "Get-AzResourceGroup",
    "Get-AzResource",
    "Get-AzResourceLock",
    "New-AzSqlServer",
    "Get-AzSqlServer",
    "New-AzSqlServerFirewallRule",
    "Get-AzSqlServerFirewallRule",
    "Set-AzSqlServerFirewallRule",
    "Remove-AzSqlServerFirewallRule",
    "Get-AzSqlServerActiveDirectoryOnlyAuthentication",
    "New-AzSqlDatabase",
    "Get-AzSqlDatabase",
    "Get-AzSqlDatabaseTransparentDataEncryption",
    "Remove-AzResourceGroup"
)

foreach ($CommandName in $RequiredCommands) {

    $Command = Get-Command `
        -Name $CommandName `
        -ErrorAction SilentlyContinue

    if (-not $Command) {
        throw "Cmdlet obrigatório não encontrado: $CommandName"
    }

    Write-Host "[OK] $CommandName"
}

#
# New-AzSqlServer capabilities
#

Write-Host ""
Write-Host "[INFO] Verificando suporte do New-AzSqlServer..."

$NewSqlServerCommand = Get-Command `
    -Name "New-AzSqlServer" `
    -ErrorAction Stop

$RequiredServerParameters = @(
    "ServerVersion",
    "ExternalAdminName",
    "ExternalAdminSID",
    "EnableActiveDirectoryOnlyAuthentication",
    "MinimalTlsVersion",
    "PublicNetworkAccess",
    "Tags"
)

foreach ($ParameterName in $RequiredServerParameters) {

    if (
        -not $NewSqlServerCommand.Parameters.ContainsKey(
            $ParameterName
        )
    ) {
        throw "O parâmetro -$ParameterName não está disponível em New-AzSqlServer."
    }

    Write-Host "[OK] Parâmetro disponível: -$ParameterName"
}

#
# New-AzSqlDatabase capabilities
#

Write-Host ""
Write-Host "[INFO] Verificando suporte da Azure SQL Database..."

$NewSqlDatabaseCommand = Get-Command `
    -Name "New-AzSqlDatabase" `
    -ErrorAction Stop

$RequiredDatabaseParameters = @(
    "Edition",
    "VCore",
    "ComputeGeneration",
    "ComputeModel",
    "AutoPauseDelayInMinutes",
    "MinimumCapacity",
    "MaxSizeBytes",
    "BackupStorageRedundancy",
    "CollationName",
    "Tags",
    "UseFreeLimit",
    "FreeLimitExhaustionBehavior"
)

foreach ($ParameterName in $RequiredDatabaseParameters) {

    if (
        -not $NewSqlDatabaseCommand.Parameters.ContainsKey(
            $ParameterName
        )
    ) {
        throw "O parâmetro -$ParameterName não está disponível em New-AzSqlDatabase."
    }

    Write-Host "[OK] Parâmetro disponível: -$ParameterName"
}

Write-Host ""
Write-Host "============================================"
Write-Host " Ambiente local validado com sucesso."
Write-Host " Nenhum recurso Azure foi criado."
Write-Host "============================================"
Write-Host ""
