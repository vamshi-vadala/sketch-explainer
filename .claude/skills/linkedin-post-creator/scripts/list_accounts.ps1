# list_accounts.ps1 — List all Zernio connected accounts, highlighting LinkedIn ones
# Usage: .\list_accounts.ps1

$ErrorActionPreference = "Stop"

# --- Resolve API key from shared config ---
$skillDir = Split-Path $PSScriptRoot -Parent
$sharedDir = Split-Path $skillDir -Parent
$configCandidates = @(
    (Join-Path $skillDir "config.env"),
    (Join-Path $sharedDir "config.env")
)
$apiKey = ""
foreach ($configPath in $configCandidates) {
    if (Test-Path $configPath) {
        foreach ($line in Get-Content $configPath) {
            if ($line -match "^ZERNIO_API_KEY=(.+)$") {
                $val = $matches[1].Trim()
                if ($val -and $val -notlike "your-*") { $apiKey = $val; break }
            }
        }
    }
    if ($apiKey) { break }
}
if (-not $apiKey) { $apiKey = $env:ZERNIO_API_KEY }
if (-not $apiKey) {
    Write-Error "ZERNIO_API_KEY not found. Add it to .claude/skills/config.env"
    exit 1
}

# --- Call Zernio accounts endpoint ---
$headers = @{ Authorization = "Bearer $apiKey" }
$response = Invoke-RestMethod -Uri "https://zernio.com/api/v1/accounts" -Method GET -Headers $headers

Write-Host ""
Write-Host "Connected Accounts:" -ForegroundColor Cyan
Write-Host "-------------------"

$linkedInAccounts = @()
foreach ($account in $response.accounts) {
    $isLinkedIn = $account.platform -eq "linkedin"
    $marker = if ($isLinkedIn) { " <-- LinkedIn" } else { "" }
    Write-Host "  ID       : $($account._id)$marker" -ForegroundColor $(if ($isLinkedIn) { "Green" } else { "White" })
    Write-Host "  Platform : $($account.platform)"
    if ($account.name) { Write-Host "  Name     : $($account.name)" }
    Write-Host ""
    if ($isLinkedIn) { $linkedInAccounts += $account }
}

if ($linkedInAccounts.Count -eq 0) {
    Write-Host "No LinkedIn accounts connected. Connect one at zernio.com -> Settings -> Connected Accounts." -ForegroundColor Yellow
} elseif ($linkedInAccounts.Count -eq 1) {
    Write-Host "LinkedIn Account ID: $($linkedInAccounts[0]._id)" -ForegroundColor Green
    Write-Host "Use this as -AccountId when posting." -ForegroundColor Green
}
