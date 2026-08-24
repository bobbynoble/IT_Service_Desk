Write-Host "=== Register the Entra app for the Device Health Check Agent ===" -ForegroundColor Cyan
Write-Host "Requires: Azure CLI (az) installed and an account with permission to" -ForegroundColor DarkGray
Write-Host "create app registrations and grant admin consent (e.g. Global Admin or" -ForegroundColor DarkGray
Write-Host "Privileged Role Administrator)." -ForegroundColor DarkGray

$appDisplayName = "IT Service Desk - Device Health Check Agent"
$graphAppId = "00000003-0000-0000-c000-000000000000"  # Microsoft Graph's well-known app ID, same in every tenant
$requiredRoles = @("DeviceManagementManagedDevices.Read.All")
# Uncomment if you want to resolve devices by the owner's display name too:
# $requiredRoles += "User.Read.All"

Write-Host "`n=== Step 1: Sign in ===" -ForegroundColor Cyan
az login | Out-Null
$tenantId = az account show --query tenantId -o tsv
Write-Host "Using tenant: $tenantId" -ForegroundColor Yellow

Write-Host "`n=== Step 2: Create (or reuse) the app registration ===" -ForegroundColor Cyan
$existing = az ad app list --display-name $appDisplayName --query "[0]" -o json | ConvertFrom-Json
if ($existing) {
    $appId = $existing.appId
    Write-Host "App already exists: $appId" -ForegroundColor Yellow
} else {
    $app = az ad app create --display-name $appDisplayName --sign-in-audience AzureADMyOrg -o json | ConvertFrom-Json
    $appId = $app.appId
    Write-Host "Created app: $appId" -ForegroundColor Green
}

# Ensure a service principal exists for this app (needed for consent to apply)
az ad sp create --id $appId 2>$null | Out-Null

Write-Host "`n=== Step 3: Add Microsoft Graph application permissions ===" -ForegroundColor Cyan
# Resolve each permission's GUID from Graph's own service principal rather than
# hardcoding IDs that could be wrong or change - safer and self-verifying.
$graphSp = az ad sp show --id $graphAppId -o json | ConvertFrom-Json
$apiPermissions = @()
foreach ($roleName in $requiredRoles) {
    $role = $graphSp.appRoles | Where-Object { $_.value -eq $roleName }
    if (-not $role) {
        Write-Host "  ! Could not find application permission '$roleName' on Microsoft Graph - skipping" -ForegroundColor Red
        continue
    }
    Write-Host "  Adding $roleName ($($role.id))" -ForegroundColor Yellow
    az ad app permission add --id $appId --api $graphAppId --api-permissions "$($role.id)=Role" | Out-Null
}

Write-Host "`n=== Step 4: Grant admin consent ===" -ForegroundColor Cyan
try {
    az ad app permission admin-consent --id $appId
    Write-Host "Admin consent granted" -ForegroundColor Green
} catch {
    Write-Host "Could not grant admin consent automatically (needs Global Admin / Privileged Role Admin)." -ForegroundColor Yellow
    Write-Host "Grant it manually: Entra portal -> App registrations -> $appDisplayName -> API permissions -> Grant admin consent" -ForegroundColor Yellow
}

Write-Host "`n=== Step 5: Create a client secret ===" -ForegroundColor Cyan
$secret = az ad app credential reset --id $appId --append --display-name "device-health-agent-secret" --years 1 --query password -o tsv

Write-Host "`n=== Done ===" -ForegroundColor Green
Write-Host "Save these somewhere secure (e.g. a password manager) - the secret will" -ForegroundColor Yellow
Write-Host "not be shown again:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Application (client) ID : $appId"
Write-Host "  Directory (tenant) ID   : $tenantId"
Write-Host "  Client secret           : $secret"
Write-Host ""
Write-Host "Next: use these values when creating the 'Intune Device Health' custom" -ForegroundColor Cyan
Write-Host "connector - see copilot-agent/Device-Health-Check-agent.md section 3." -ForegroundColor Cyan
