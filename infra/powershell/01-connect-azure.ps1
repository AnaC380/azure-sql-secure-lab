#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================"
Write-Host " DIO Azure SQL Secure Lab - Azure Connection"
Write-Host "============================================"
Write-Host ""

Write-Host "[INFO] Verificando contexto Azure existente..."

$CurrentContext = Get-AzContext -ErrorAction SilentlyContinue

if (-not $CurrentContext) {

    Write-Host "[INFO] Nenhuma sessão Azure ativa encontrada."
    Write-Host "[INFO] Iniciando autenticação..."

    Connect-AzAccount | Out-Null
}
else {

    Write-Host "[OK] Contexto Azure existente encontrado."
    Write-Host "[INFO] Conta Azure autenticada."
}

Write-Host ""
Write-Host "[INFO] Consultando assinaturas disponíveis..."

$Subscriptions = @(
    Get-AzSubscription |
        Where-Object State -eq "Enabled"
)

if ($Subscriptions.Count -eq 0) {
    throw "Nenhuma assinatura Azure habilitada foi encontrada para esta conta."
}

Write-Host ""
Write-Host "Assinaturas habilitadas:"
Write-Host ""

for ($Index = 0; $Index -lt $Subscriptions.Count; $Index++) {

    Write-Host "[$Index] $($Subscriptions[$Index].Name)"
}

Write-Host ""

if ($Subscriptions.Count -eq 1) {

    $SelectedSubscription = $Subscriptions[0]

    Write-Host "[INFO] Apenas uma assinatura habilitada encontrada."
}
else {

    do {

        $Selection = Read-Host "Informe o número da assinatura que deseja utilizar"

        $IsValidSelection = (
            $Selection -match '^\d+$' -and
            [int]$Selection -ge 0 -and
            [int]$Selection -lt $Subscriptions.Count
        )

        if (-not $IsValidSelection) {
            Write-Warning "Seleção inválida."
        }

    } until ($IsValidSelection)

    $SelectedSubscription = $Subscriptions[[int]$Selection]
}

Write-Host ""
Write-Host "[INFO] Definindo contexto Azure..."

Set-AzContext `
    -SubscriptionId $SelectedSubscription.Id `
    -TenantId $SelectedSubscription.TenantId |
    Out-Null

$FinalContext = Get-AzContext

if (-not $FinalContext) {
    throw "Não foi possível obter o contexto Azure após a seleção."
}

if ($FinalContext.Subscription.Id -ne $SelectedSubscription.Id) {
    throw "A assinatura ativa não corresponde à assinatura selecionada."
}

Write-Host ""
Write-Host "============================================"
Write-Host " Contexto Azure configurado com sucesso."
Write-Host "============================================"
Write-Host ""
Write-Host "[OK] Conta Azure autenticada."
Write-Host "[OK] Assinatura: $($FinalContext.Subscription.Name)"
Write-Host "[OK] Tenant configurado."
Write-Host ""
Write-Host "[SECURITY] Nenhuma senha, token ou segredo foi gravado pelo script."
Write-Host "[INFO] Nenhum recurso Azure foi criado."
Write-Host ""