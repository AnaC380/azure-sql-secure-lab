#Requires -Version 7.0

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

    [string]$ExpectedLocation = "brazilsouth",

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ExpectedSubscriptionId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:FailureCount = 0
$script:WarningCount = 0

#
# Validation helpers
#

function Write-ValidationSuccess {

    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host "[OK] $Message"
}

function Write-ValidationFailure {

    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $script:FailureCount++

    Write-Host "[FAIL] $Message"
}

function Write-ValidationWarning {

    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $script:WarningCount++

    Write-Host "[WARN] $Message"
}

function Test-ExpectedTags {

    param(
        [Parameter(Mandatory)]
        [string]$ResourceLabel,

        [Parameter()]
        [object]$ActualTags,

        [Parameter(Mandatory)]
        [hashtable]$ExpectedTags
    )

    foreach ($Tag in $ExpectedTags.GetEnumerator()) {

        if (
            $null -ne $ActualTags -and
            $ActualTags.ContainsKey($Tag.Key) -and
            $ActualTags[$Tag.Key] -eq $Tag.Value
        ) {

            Write-ValidationSuccess `
                "$ResourceLabel tag $($Tag.Key) = $($Tag.Value)"
        }
        else {

            Write-ValidationFailure `
                "$ResourceLabel tag ausente ou incorreta: $($Tag.Key)"
        }
    }
}

#
# Header
#

Write-Host ""
Write-Host "===================================================="
Write-Host " DIO Azure SQL Secure Lab - Environment Validation"
Write-Host "===================================================="
Write-Host ""

#
# Azure context
#

Write-Host "[INFO] Verificando contexto Azure..."

try {

    $Context = Get-AzContext `
        -ErrorAction Stop
}
catch {

    throw "Não foi possível consultar o contexto Azure."
}

if (-not $Context) {

    throw @"
Nenhum contexto Azure ativo foi encontrado.

Execute primeiro:

.\infra\powershell\01-connect-azure.ps1
"@
}

Write-ValidationSuccess `
    "Contexto Azure ativo."

#
# Expected subscription
#

if (
    -not [string]::IsNullOrWhiteSpace(
        $ExpectedSubscriptionId
    )
) {

    try {

        $ExpectedGuid = `
            [guid]$ExpectedSubscriptionId
    }
    catch {

        throw `
            "ExpectedSubscriptionId não possui formato GUID válido."
    }

    if (
        $Context.Subscription.Id -eq
        $ExpectedGuid.ToString()
    ) {

        Write-ValidationSuccess `
            "Subscription ativa corresponde à esperada."
    }
    else {

        Write-ValidationFailure `
            "Subscription ativa não corresponde à esperada."
    }
}

#
# Resource Group
#

Write-Host ""
Write-Host "[INFO] Verificando Resource Group..."

try {

    $ResourceGroup = `
        Get-AzResourceGroup `
            -Name $ResourceGroupName `
            -ErrorAction Stop

    Write-ValidationSuccess `
        "Resource Group encontrado: $ResourceGroupName"
}
catch {

    throw `
        "Resource Group não encontrado: $ResourceGroupName"
}

if (
    $ResourceGroup.Location -eq
    $ExpectedLocation
) {

    Write-ValidationSuccess `
        "Região do Resource Group: $ExpectedLocation"
}
else {

    Write-ValidationWarning `
        "Região encontrada: $($ResourceGroup.Location)"
}

#
# SQL logical server
#

Write-Host ""
Write-Host "[INFO] Verificando Azure SQL logical server..."

try {

    $SqlServer = `
        Get-AzSqlServer `
            -ResourceGroupName $ResourceGroupName `
            -ServerName $ServerName `
            -ErrorAction Stop

        Write-ValidationSuccess `
            "SQL logical server esperado encontrado."
}
catch {

    throw `
        "SQL logical server esperado não encontrado."
}

if (
    $SqlServer.Location -eq
    $ExpectedLocation
) {

    Write-ValidationSuccess `
       "SQL Server localizado na região esperada: $ExpectedLocation."
}
else {

    Write-ValidationFailure `
        "SQL Server em região inesperada: $($SqlServer.Location)"
}

#
# TLS
#

Write-Host ""
Write-Host "[INFO] Verificando configuração TLS..."

if (
    $SqlServer.MinimalTlsVersion -eq
    "1.2"
) {

    Write-ValidationSuccess `
        "TLS mínimo configurado como 1.2."
}
else {

    Write-ValidationFailure `
        "TLS mínimo diferente de 1.2: $($SqlServer.MinimalTlsVersion)"
}

#
# Database
#

Write-Host ""
Write-Host "[INFO] Verificando Azure SQL Database..."

try {

    $Database = `
        Get-AzSqlDatabase `
            -ResourceGroupName $ResourceGroupName `
            -ServerName $ServerName `
            -DatabaseName $DatabaseName `
            -ErrorAction Stop

    Write-ValidationSuccess `
        "Database encontrada: $DatabaseName"
}
catch {

    throw `
        "Database não encontrada: $DatabaseName"
}

if (
    $Database.Status -in @(
        "Online",
        "Paused"
    )
) {

    Write-ValidationSuccess `
        "Status da database aceito: $($Database.Status)"
}
else {

    Write-ValidationFailure `
        "Status inesperado: $($Database.Status)"
}

Write-Host `
    "[INFO] Service Objective: $($Database.CurrentServiceObjectiveName)"

Write-Host `
    "[INFO] Capacidade máxima: $($Database.Capacity) vCores"

Write-Host `
    "[INFO] Capacidade mínima: $($Database.MinimumCapacity) vCore"

Write-Host `
    "[INFO] Auto-pause: $($Database.AutoPauseDelayInMinutes) minutos"

#
# Database configuration
#

Write-Host ""
Write-Host "[INFO] Verificando configuração da database..."

if (
    $Database.Edition -eq
    "GeneralPurpose"
) {

    Write-ValidationSuccess `
        "Service tier: GeneralPurpose."
}
else {

    Write-ValidationFailure `
        "Service tier inesperado: $($Database.Edition)"
}

if (
    $Database.CurrentServiceObjectiveName -eq
    "GP_S_Gen5_2"
) {

    Write-ValidationSuccess `
        "Service Objective configurado como GP_S_Gen5_2."
}
else {

    Write-ValidationWarning `
        "Service Objective encontrado: $($Database.CurrentServiceObjectiveName)"
}

$ExpectedMaximumSize = 32GB

if (
    [int64]$Database.MaxSizeBytes -eq
    $ExpectedMaximumSize
) {

    Write-ValidationSuccess `
        "Tamanho máximo configurado em 32 GB."
}
else {

    $MaximumSizeGB = `
        [math]::Round(
            $Database.MaxSizeBytes / 1GB,
            2
        )

    Write-ValidationFailure `
        "Tamanho máximo inesperado: $MaximumSizeGB GB."
}

if (
    $Database.CurrentBackupStorageRedundancy -eq
    "Local"
) {

    Write-ValidationSuccess `
        "Redundância de backup configurada como Local."
}
else {

    Write-ValidationFailure `
        "Redundância de backup inesperada: $($Database.CurrentBackupStorageRedundancy)"
}

if (
    $Database.MinimumCapacity -eq
    0.5
) {

    Write-ValidationSuccess `
        "Capacidade mínima configurada em 0.5 vCore."
}
else {

    Write-ValidationFailure `
        "Capacidade mínima inesperada: $($Database.MinimumCapacity)"
}

if (
    $Database.AutoPauseDelayInMinutes -eq
    60
) {

    Write-ValidationSuccess `
        "Auto-pause configurado para 60 minutos."
}
else {

    Write-ValidationFailure `
        "Auto-pause inesperado: $($Database.AutoPauseDelayInMinutes)"
}

#
# Transparent Data Encryption
#

Write-Host ""
Write-Host "[INFO] Verificando Transparent Data Encryption..."

try {

    $Tde = `
        Get-AzSqlDatabaseTransparentDataEncryption `
            -ResourceGroupName $ResourceGroupName `
            -ServerName $ServerName `
            -DatabaseName $DatabaseName `
            -ErrorAction Stop

    if (
        $Tde.State -eq
        "Enabled"
    ) {

        Write-ValidationSuccess `
            "TDE está habilitado."
    }
    else {

        Write-ValidationFailure `
            "TDE está no estado: $($Tde.State)"
    }
}
catch {

    Write-ValidationFailure `
        "Não foi possível consultar TDE."
}

#
# Azure SQL Free Limit
#

Write-Host ""
Write-Host "[INFO] Verificando Azure SQL Free Limit..."

if (
    $Database.UseFreeLimit -eq
    $true
) {

    Write-ValidationSuccess `
        "Free Limit habilitado."
}
else {

    Write-ValidationFailure `
        "Free Limit NÃO está habilitado."
}

if (
    $Database.FreeLimitExhaustionBehavior -eq
    "AutoPause"
) {

    Write-ValidationSuccess `
        "Free Limit Exhaustion Behavior = AutoPause."
}
else {

    Write-ValidationFailure `
        "Exhaustion Behavior inesperado: $($Database.FreeLimitExhaustionBehavior)"
}

#
# Microsoft Entra-only
#

Write-Host ""
Write-Host "[INFO] Verificando Microsoft Entra-only..."

try {

    $EntraAuthentication = `
        Get-AzSqlServerActiveDirectoryOnlyAuthentication `
            -ResourceGroupName $ResourceGroupName `
            -ServerName $ServerName `
            -ErrorAction Stop

    if (
        $EntraAuthentication.AzureADOnlyAuthentication -eq
        $true
    ) {

        Write-ValidationSuccess `
            "Microsoft Entra-only authentication está habilitada."
    }
    else {

        Write-ValidationFailure `
            "Microsoft Entra-only authentication NÃO está habilitada."
    }
}
catch {

    Write-ValidationFailure `
        "Não foi possível consultar Entra-only authentication."
}

#
# Network
#

Write-Host ""
Write-Host "[INFO] Verificando acesso de rede..."

Write-Host `
    "[INFO] PublicNetworkAccess: $($SqlServer.PublicNetworkAccess)"

if (
    $SqlServer.PublicNetworkAccess -eq
    "Enabled"
) {

    Write-Host `
        "[INFO] Endpoint público habilitado."
}
else {

    Write-ValidationWarning `
        "Public Network Access não está habilitado."
}

#
# Firewall
#

Write-Host ""
Write-Host "[INFO] Verificando regras de firewall..."

$FirewallQuerySucceeded = $false
$FirewallRules = @()
$AllowAzureServicesRules = @()
$ClientFirewallRules = @()

try {

    $FirewallRules = @(
        Get-AzSqlServerFirewallRule `
            -ResourceGroupName $ResourceGroupName `
            -ServerName $ServerName `
            -ErrorAction Stop
    )

    $FirewallQuerySucceeded = $true
}
catch {

    Write-ValidationFailure `
        "Não foi possível consultar regras de firewall."
}

if ($FirewallQuerySucceeded) {

    Write-Host `
        "[INFO] Total de regras server-level: $($FirewallRules.Count)"

    #
    # Reject generic Allow Azure Services rule
    #

    $AllowAzureServicesRules = @(
        $FirewallRules |
            Where-Object {
                $_.StartIpAddress -eq "0.0.0.0" -and
                $_.EndIpAddress -eq "0.0.0.0"
            }
    )

    if (
        $AllowAzureServicesRules.Count -eq
        0
    ) {

        Write-ValidationSuccess `
            "Acesso genérico de serviços Azure não está habilitado."
    }
    else {

        Write-ValidationFailure `
            "Foi encontrada regra 0.0.0.0 -> 0.0.0.0."
    }

    #
    # Client firewall rules
    #

    $ClientFirewallRules = @(
        $FirewallRules |
            Where-Object {
                -not (
                    $_.StartIpAddress -eq "0.0.0.0" -and
                    $_.EndIpAddress -eq "0.0.0.0"
                )
            }
    )

    if (
        $SqlServer.PublicNetworkAccess -eq
        "Enabled"
    ) {

        if (
            $ClientFirewallRules.Count -eq
            1
        ) {

            Write-ValidationSuccess `
                "Exatamente uma regra de firewall para cliente está configurada."
        }
        else {

            Write-ValidationFailure `
                "Esperada exatamente 1 regra de cliente; encontradas: $($ClientFirewallRules.Count)"
        }
    }

    foreach (
        $FirewallRule in
        $ClientFirewallRules
    ) {

        if (
            $FirewallRule.StartIpAddress -eq
            $FirewallRule.EndIpAddress
        ) {

            Write-ValidationSuccess `
                "Regra '$($FirewallRule.FirewallRuleName)' limitada a um único IPv4."

            Write-Host `
                "[INFO] IP da regra não exibido."
        }
        else {

            Write-ValidationFailure `
                "Regra '$($FirewallRule.FirewallRuleName)' permite intervalo de IP."
        }
    }

    if (
        $SqlServer.PublicNetworkAccess -eq "Enabled" -and
        $ClientFirewallRules.Count -eq 1 -and
        $AllowAzureServicesRules.Count -eq 0 -and
        $ClientFirewallRules[0].StartIpAddress -eq
            $ClientFirewallRules[0].EndIpAddress
    ) {

        Write-ValidationSuccess `
            "Acesso público restrito a uma única regra single-IP."
    }
}
else {

    Write-Host `
        "[INFO] Validação detalhada do firewall não foi executada porque a consulta falhou."
}

#
# Governance tags
#

Write-Host ""
Write-Host "[INFO] Verificando tags de governança..."

$ExpectedTags = @{
    Environment        = "Lab"
    Project            = "dio-azure-sql-secure-lab"
    Purpose            = "Learning"
    DataClassification = "NonSensitive"
    Lifecycle          = "Temporary"
}

Write-Host ""
Write-Host "[INFO] Validando tags da Database..."

Test-ExpectedTags `
    -ResourceLabel "Database" `
    -ActualTags $Database.Tags `
    -ExpectedTags $ExpectedTags

Write-Host ""
Write-Host "[INFO] Validando tags do SQL logical server..."

Test-ExpectedTags `
    -ResourceLabel "SQL Server" `
    -ActualTags $SqlServer.Tags `
    -ExpectedTags $ExpectedTags

#
# Summary
#

Write-Host ""
Write-Host "===================================================="
Write-Host " Validation Summary"
Write-Host "===================================================="
Write-Host ""
Write-Host "[INFO] Falhas: $script:FailureCount"
Write-Host "[INFO] Avisos: $script:WarningCount"
Write-Host ""

if (
    $script:FailureCount -gt
    0
) {

    throw `
        "A validação encontrou $script:FailureCount falha(s)."
}

Write-Host "===================================================="
Write-Host " Azure SQL environment validated successfully."
Write-Host " Nenhuma configuração Azure foi alterada."
Write-Host "===================================================="
Write-Host ""