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

    [ValidateSet(
        "Audit",
        "Ensure",
        "Remove"
    )]
    [string]$Mode = "Audit",

    [string]$RuleName = "ClientIp-Workstation",

    [string]$ClientIpAddress = "",

    [string]$ExpectedSubscriptionId = "",

    [switch]$AllowNoClientAccess,

    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:FailureCount = 0

function Write-FirewallSuccess {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host "[OK] $Message"
}

function Write-FirewallFailure {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $script:FailureCount++

    Write-Host "[FAIL] $Message"
}

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
"@
        }
    }

    return $CurrentContext
}

function ConvertTo-ValidatedIPv4 {

    param(
        [Parameter(Mandatory)]
        [string]$IpAddress
    )

    [System.Net.IPAddress]$ParsedIp = $null

    $IsValid = [System.Net.IPAddress]::TryParse(
        $IpAddress,
        [ref]$ParsedIp
    )

    if (
        -not $IsValid -or
        $ParsedIp.AddressFamily -ne
            [System.Net.Sockets.AddressFamily]::InterNetwork
    ) {
        throw "O endereço informado não é um IPv4 válido."
    }

    $CanonicalIp = $ParsedIp.ToString()

    if ($CanonicalIp -eq "0.0.0.0") {
        throw "0.0.0.0 não é permitido como regra de cliente."
    }

    return $CanonicalIp
}

Write-Host ""
Write-Host "===================================================="
Write-Host " DIO Azure SQL Secure Lab - Firewall Management"
Write-Host "===================================================="
Write-Host ""

Write-Host "[INFO] Modo: $Mode"

if ($Apply) {
    Write-Host "[MODE] APPLY habilitado."
}
else {
    Write-Host "[MODE] Somente auditoria/planejamento."
}

#
# Context
#

$Context = Assert-ExpectedSubscription `
    -ExpectedSubscriptionId $ExpectedSubscriptionId `
    -RequireExpectedSubscription $Apply.IsPresent

Write-FirewallSuccess "Contexto Azure ativo."

if (
    -not [string]::IsNullOrWhiteSpace(
        $ExpectedSubscriptionId
    )
) {
    Write-FirewallSuccess `
        "Subscription ativa validada."
}

#
# Server
#

$SqlServer = Get-AzSqlServer `
    -ResourceGroupName $ResourceGroupName `
    -ServerName $ServerName `
    -ErrorAction Stop

Write-FirewallSuccess `
    "SQL logical server esperado encontrado."

Write-Host `
    "[INFO] PublicNetworkAccess: $($SqlServer.PublicNetworkAccess)"

#
# Firewall state
#

$FirewallRules = @(
    Get-AzSqlServerFirewallRule `
        -ResourceGroupName $ResourceGroupName `
        -ServerName $ServerName `
        -ErrorAction Stop
)

$AllowAzureServicesRules = @(
    $FirewallRules |
        Where-Object {
            $_.StartIpAddress -eq "0.0.0.0" -and
            $_.EndIpAddress -eq "0.0.0.0"
        }
)

$ClientRules = @(
    $FirewallRules |
        Where-Object {
            -not (
                $_.StartIpAddress -eq "0.0.0.0" -and
                $_.EndIpAddress -eq "0.0.0.0"
            )
        }
)

$BroadRules = @(
    $ClientRules |
        Where-Object {
            $_.StartIpAddress -ne
            $_.EndIpAddress
        }
)

Write-Host ""
Write-Host "[INFO] Regras server-level: $($FirewallRules.Count)"
Write-Host "[INFO] Regras de cliente: $($ClientRules.Count)"

if ($AllowAzureServicesRules.Count -gt 0) {
    Write-FirewallFailure `
        "Allow Azure Services está habilitado."
}

foreach ($Rule in $BroadRules) {
    Write-FirewallFailure `
        "Regra '$($Rule.FirewallRuleName)' permite intervalo de IP."
}

foreach ($Rule in $ClientRules) {

    if (
        $Rule.StartIpAddress -eq
        $Rule.EndIpAddress
    ) {
        Write-FirewallSuccess `
            "Regra '$($Rule.FirewallRuleName)' limitada a um único IPv4."
    }
}

#
# Audit
#

if ($Mode -eq "Audit") {

    if (
        $SqlServer.PublicNetworkAccess -eq "Enabled" -and
        $ClientRules.Count -ne 1
    ) {
        Write-FirewallFailure `
            "A política do laboratório exige exatamente uma regra de cliente."
    }

    Write-Host ""
    Write-Host "===================================================="
    Write-Host " Firewall Audit Summary"
    Write-Host "===================================================="
    Write-Host "[INFO] Falhas: $script:FailureCount"

    if ($script:FailureCount -gt 0) {
        throw "A auditoria encontrou configuração insegura."
    }

    Write-FirewallSuccess "Firewall validado."
    Write-Host "[INFO] Nenhum endereço IP foi exibido."
    Write-Host "[INFO] Nenhuma configuração Azure foi alterada."

    return
}

#
# Block modifications if existing state is unsafe
#

if (
    $AllowAzureServicesRules.Count -gt 0 -or
    $BroadRules.Count -gt 0
) {
    throw @"
SECURITY: existem regras de firewall inseguras.

Nenhuma alteração automática será feita
até que a configuração seja revisada.
"@
}

#
# Ensure
#

if ($Mode -eq "Ensure") {

    if ($SqlServer.PublicNetworkAccess -ne "Enabled") {
        throw "PublicNetworkAccess não está habilitado."
    }

    if ([string]::IsNullOrWhiteSpace($ClientIpAddress)) {
        throw "Informe -ClientIpAddress para usar Ensure."
    }

    if ($ClientRules.Count -gt 1) {
        throw @"
SECURITY: mais de uma regra de cliente foi encontrada.

Nenhuma nova regra será adicionada.
"@
    }

    $CanonicalIp = ConvertTo-ValidatedIPv4 `
        -IpAddress $ClientIpAddress

    if ($ClientRules.Count -eq 1) {

        $ExistingRule = $ClientRules[0]

        if (
            $ExistingRule.StartIpAddress -eq $CanonicalIp -and
            $ExistingRule.EndIpAddress -eq $CanonicalIp
        ) {
            Write-FirewallSuccess `
                "A única regra já corresponde ao IPv4 informado."

            Write-Host "[SKIP] Nenhuma alteração necessária."

            return
        }

        $ExistingRuleName = `
            $ExistingRule.FirewallRuleName

        Write-Host `
            "[PLAN] A regra existente será rotacionada para o novo IPv4."

        if (-not $Apply) {
            Write-Host "[INFO] Dry-run: nenhuma alteração realizada."
            return
        }

        if (
            $PSCmdlet.ShouldProcess(
                "regra de firewall '$ExistingRuleName'",
                "Rotacionar a única regra single-IP existente"
            )
        ) {

            Set-AzSqlServerFirewallRule `
                -ResourceGroupName $ResourceGroupName `
                -ServerName $ServerName `
                -FirewallRuleName $ExistingRuleName `
                -StartIpAddress $CanonicalIp `
                -EndIpAddress $CanonicalIp `
                -ErrorAction Stop |
                Out-Null

            Write-FirewallSuccess `
                "Regra single-IP rotacionada."
        }
    }
    else {

        Write-Host `
            "[PLAN] Uma única regra single-IP será criada."

        if (-not $Apply) {
            Write-Host "[INFO] Dry-run: nenhuma alteração realizada."
            return
        }

        if (
            $PSCmdlet.ShouldProcess(
                "regra de firewall '$RuleName'",
                "Criar a única regra single-IP do laboratório"
            )
        ) {

            New-AzSqlServerFirewallRule `
                -ResourceGroupName $ResourceGroupName `
                -ServerName $ServerName `
                -FirewallRuleName $RuleName `
                -StartIpAddress $CanonicalIp `
                -EndIpAddress $CanonicalIp `
                -ErrorAction Stop |
                Out-Null

            Write-FirewallSuccess `
                "Regra single-IP criada."
        }
    }

    #
    # Post-change validation
    #

    $PostChangeRules = @(
        Get-AzSqlServerFirewallRule `
            -ResourceGroupName $ResourceGroupName `
            -ServerName $ServerName `
            -ErrorAction Stop
    )

    $PostAllowAzure = @(
        $PostChangeRules |
            Where-Object {
                $_.StartIpAddress -eq "0.0.0.0" -and
                $_.EndIpAddress -eq "0.0.0.0"
            }
    )

    $PostClientRules = @(
        $PostChangeRules |
            Where-Object {
                -not (
                    $_.StartIpAddress -eq "0.0.0.0" -and
                    $_.EndIpAddress -eq "0.0.0.0"
                )
            }
    )

    if ($PostAllowAzure.Count -gt 0) {
        throw "SECURITY: Allow Azure Services detectado após alteração."
    }

    if ($PostClientRules.Count -ne 1) {
        throw "SECURITY: quantidade inesperada de regras após alteração."
    }

    if (
        $PostClientRules[0].StartIpAddress -ne $CanonicalIp -or
        $PostClientRules[0].EndIpAddress -ne $CanonicalIp
    ) {
        throw "SECURITY: validação pós-alteração do IPv4 falhou."
    }

    Write-FirewallSuccess `
        "Firewall pós-alteração possui exatamente uma regra single-IP."

    Write-Host "[SECURITY] IPv4 não exibido no console."

    return
}

#
# Remove
#

if ($Mode -eq "Remove") {

    $RuleToRemove = @(
        $ClientRules |
            Where-Object {
                $_.FirewallRuleName -eq $RuleName
            }
    )

    if ($RuleToRemove.Count -eq 0) {
        Write-FirewallSuccess `
            "A regra '$RuleName' não existe."

        Write-Host "[SKIP] Nenhuma alteração necessária."

        return
    }

    if (
        $ClientRules.Count -eq 1 -and
        -not $AllowNoClientAccess
    ) {
        throw @"
SECURITY: esta é a última regra de cliente.

A remoção bloquearia o acesso público do cliente.

Para fazer isso deliberadamente,
informe também -AllowNoClientAccess.
"@
    }

    Write-Host "[PLAN] Regra '$RuleName' será removida."

    if (-not $Apply) {
        Write-Host "[INFO] Dry-run: nenhuma alteração realizada."
        return
    }

    if (
        $PSCmdlet.ShouldProcess(
            "regra de firewall '$RuleName'",
            "Remover regra de firewall"
        )
    ) {

        Remove-AzSqlServerFirewallRule `
            -ResourceGroupName $ResourceGroupName `
            -ServerName $ServerName `
            -FirewallRuleName $RuleName `
            -ErrorAction Stop

        Write-FirewallSuccess `
            "Regra de firewall removida."
    }
}
