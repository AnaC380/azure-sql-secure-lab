#Requires -Version 7.0

[CmdletBinding(
    SupportsShouldProcess = $true,
    ConfirmImpact = "High"
)]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [string]$Location = "brazilsouth",

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ServerName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseName,

    [string]$ExternalAdminName = "",

    [string]$ExternalAdminSid = "",

    [string]$ExpectedSubscriptionId = "",

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
SECURITY: operação de alteração solicitada,
mas -ExpectedSubscriptionId não foi informado.

Nenhum recurso será alterado.
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
            throw "SECURITY: ExpectedSubscriptionId não possui formato GUID válido."
        }

        if (
            $CurrentContext.Subscription.Id -ne
            $ExpectedGuid.ToString()
        ) {
            throw @"
SECURITY: a subscription ativa não corresponde
à subscription esperada.

Nenhum recurso será alterado.
"@
        }
    }

    return $CurrentContext
}

$Tags = @{
    Environment        = "Lab"
    Project            = "dio-azure-sql-secure-lab"
    Purpose            = "Learning"
    DataClassification = "NonSensitive"
    Lifecycle          = "Temporary"
}

Write-Host ""
Write-Host "===================================================="
Write-Host " DIO Azure SQL Secure Lab - Deployment"
Write-Host "===================================================="
Write-Host ""

if ($Apply) {
    Write-Host "[MODE] APPLY"
    Write-Host "[WARN] Recursos ausentes poderão ser criados."
}
else {
    Write-Host "[MODE] PLAN / DRY-RUN"
    Write-Host "[INFO] Nenhum recurso será criado ou alterado."
}

#
# Azure context
#

Write-Host ""
Write-Host "[INFO] Verificando contexto Azure..."

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

    throw @"
SECURITY: falha ao consultar Resource Groups.

A ausência do recurso não pôde ser confirmada.
O deployment foi interrompido.
"@
}

if ($ResourceGroup) {

    Write-Host "[OK] Resource Group já existe: $ResourceGroupName"
    Write-Host "[SKIP] Nenhuma criação necessária."

    if ($ResourceGroup.Location -ne $Location) {
        throw "Resource Group encontrado em região inesperada: $($ResourceGroup.Location)"
    }
}
else {

    Write-Host "[PLAN] Resource Group ausente."
    Write-Host "[PLAN] Seria criado em: $Location"

    if ($Apply) {

        if (
            $PSCmdlet.ShouldProcess(
                $ResourceGroupName,
                "Criar Resource Group em $Location"
            )
        ) {

            $ResourceGroup = New-AzResourceGroup `
                -Name $ResourceGroupName `
                -Location $Location `
                -Tag $Tags `
                -ErrorAction Stop

            Write-Host "[OK] Resource Group criado."
        }
    }
}

#
# SQL logical server
#

Write-Host ""
Write-Host "[INFO] Verificando SQL logical server..."

$SqlServer = $null

if ($ResourceGroup) {

    try {

        $SqlServer = `
            Get-AzSqlServer `
                -ResourceGroupName $ResourceGroupName `
                -ErrorAction Stop |
            Where-Object {
                $_.ServerName -eq $ServerName
            } |
            Select-Object -First 1
    }
    catch {

        throw @"
SECURITY: falha ao consultar Azure SQL logical servers.

A ausência do servidor não pôde ser confirmada.
O deployment foi interrompido.
"@
    }
}

if ($SqlServer) {

    Write-Host "[OK] SQL logical server esperado já existe."

    #
    # Security baseline for existing server
    #

    if ($SqlServer.MinimalTlsVersion -ne "1.2") {

        throw @"
SECURITY: o SQL logical server existente
não exige TLS mínimo 1.2.

O deployment foi interrompido.
"@
    }

    Write-Host `
        "[OK] Servidor existente exige TLS mínimo 1.2."

    try {

        $ExistingEntraOnlyAuthentication = `
            Get-AzSqlServerActiveDirectoryOnlyAuthentication `
                -ResourceGroupName $ResourceGroupName `
                -ServerName $ServerName `
                -ErrorAction Stop
    }
    catch {

        throw @"
SECURITY: não foi possível validar
Microsoft Entra-only authentication
no SQL logical server existente.

O deployment foi interrompido.
"@
    }

    if (
        $ExistingEntraOnlyAuthentication.AzureADOnlyAuthentication `
            -ne $true
    ) {

        throw @"
SECURITY: o SQL logical server existente
não utiliza Microsoft Entra-only authentication.

O deployment foi interrompido.
"@
    }

    Write-Host `
        "[OK] Servidor existente utiliza Microsoft Entra-only."

    Write-Host `
        "[SECURITY] Baseline do servidor existente validado."

    Write-Host "[SKIP] Nenhuma criação necessária."
}
else {

    Write-Host "[PLAN] SQL logical server ausente."
    Write-Host "[PLAN] Microsoft Entra-only será exigido."
    Write-Host "[PLAN] TLS mínimo: 1.2"
    Write-Host "[PLAN] PublicNetworkAccess: Enabled"
    Write-Host "[PLAN] Firewall será configurado separadamente."

    if ($Apply) {

        if (-not $ResourceGroup) {
            throw "Resource Group não está disponível."
        }

        if (
            [string]::IsNullOrWhiteSpace(
                $ExternalAdminName
            )
        ) {
            throw @"
Para criar o SQL logical server,
informe -ExternalAdminName.

Não grave esse valor diretamente no script.
"@
        }

        $NewServerParameters = @{
            ResourceGroupName = $ResourceGroupName
            Location = $Location
            ServerName = $ServerName
            ServerVersion = "12.0"
            ExternalAdminName = $ExternalAdminName
            EnableActiveDirectoryOnlyAuthentication = $true
            MinimalTlsVersion = "1.2"
            PublicNetworkAccess = "Enabled"
            Tags = $Tags
            ErrorAction = "Stop"
        }

        if (
            -not [string]::IsNullOrWhiteSpace(
                $ExternalAdminSid
            )
        ) {

            try {
                $NewServerParameters["ExternalAdminSID"] = `
                    [guid]$ExternalAdminSid
            }
            catch {
                throw "ExternalAdminSid não possui formato GUID válido."
            }
        }

        if (
            $PSCmdlet.ShouldProcess(
                "Azure SQL logical server esperado",
                "Criar Azure SQL logical server com Microsoft Entra-only"
)
        ) {

            $SqlServer = New-AzSqlServer `
                @NewServerParameters

            Write-Host "[OK] SQL logical server criado."
        }
    }
}

#
# Azure SQL Database
#

Write-Host ""
Write-Host "[INFO] Verificando Azure SQL Database..."

$Database = $null

if ($SqlServer) {

    try {

        $Database = `
            Get-AzSqlDatabase `
                -ResourceGroupName $ResourceGroupName `
                -ServerName $ServerName `
                -ErrorAction Stop |
            Where-Object {
                $_.DatabaseName -eq $DatabaseName
            } |
            Select-Object -First 1
    }
    catch {

        throw @"
SECURITY: falha ao consultar Azure SQL Databases.

A ausência da database não pôde ser confirmada.
O deployment foi interrompido.
"@
    }
}

if ($Database) {

    Write-Host "[OK] Database já existe: $DatabaseName"
    Write-Host "[SKIP] Nenhuma criação necessária."
}
else {

    Write-Host "[PLAN] Azure SQL Database ausente."
    Write-Host "[PLAN] GeneralPurpose / Serverless / Gen5 / 2 vCores"
    Write-Host "[PLAN] MinimumCapacity: 0.5"
    Write-Host "[PLAN] Auto-pause: 60 minutos"
    Write-Host "[PLAN] MaxSize: 32 GB"
    Write-Host "[PLAN] Backup redundancy: Local"
    Write-Host "[PLAN] Free Limit: Enabled"
    Write-Host "[PLAN] Exhaustion: AutoPause"
    Write-Host "[SECURITY] Nenhum fallback pago será utilizado."

    if ($Apply) {

        if (-not $SqlServer) {
            throw "SQL logical server não está disponível."
        }

        if (
            $PSCmdlet.ShouldProcess(
                $DatabaseName,
                "Criar Azure SQL Database usando Free Limit e AutoPause"
            )
        ) {

            $Database = New-AzSqlDatabase `
                -ResourceGroupName $ResourceGroupName `
                -ServerName $ServerName `
                -DatabaseName $DatabaseName `
                -Edition "GeneralPurpose" `
                -VCore 2 `
                -ComputeGeneration "Gen5" `
                -ComputeModel "Serverless" `
                -MinimumCapacity 0.5 `
                -AutoPauseDelayInMinutes 60 `
                -MaxSizeBytes 32GB `
                -BackupStorageRedundancy "Local" `
                -CollationName "SQL_Latin1_General_CP1_CI_AS" `
                -Tags $Tags `
                -UseFreeLimit `
                -FreeLimitExhaustionBehavior "AutoPause" `
                -ErrorAction Stop

            Write-Host "[OK] Azure SQL Database criada."
        }
    }
}

Write-Host ""
Write-Host "===================================================="

if ($Apply) {
    Write-Host " Deployment processing completed."
    Write-Host " Execute 03-validate.ps1 para validar o ambiente."
}
else {
    Write-Host " Deployment plan completed."
    Write-Host " Nenhuma configuração Azure foi alterada."
}

Write-Host "===================================================="
Write-Host ""
