# post_linkedin.ps1 — Publish or schedule a LinkedIn post via Zernio API
#
# Usage:
#   .\post_linkedin.ps1 -AccountId "<id>" -Content "Post text"
#   .\post_linkedin.ps1 -AccountId "<id>" -Content "Post text" -ImageUrl "https://..."
#   .\post_linkedin.ps1 -AccountId "<id>" -Content "Post text" -ScheduledFor "2026-05-20T14:00:00" -Timezone "Asia/Kolkata"
#   .\post_linkedin.ps1 -AccountId "<id>" -Content "Post text" -ImageUrl "https://..." -ScheduledFor "2026-05-20T14:00:00" -Timezone "UTC"

param(
    [string]$AccountId,
    [Parameter(Mandatory)][string]$Content,
    [string]$ImageUrl,
    [string]$ScheduledFor,
    [string]$Timezone = "UTC"
)

$ErrorActionPreference = "Stop"

# --- Resolve API key from shared config ---
$skillDir = Split-Path $PSScriptRoot -Parent
$sharedDir = Split-Path $skillDir -Parent
$configCandidates = @(
    (Join-Path $skillDir "config.env"),
    (Join-Path $sharedDir "config.env")
)
$apiKey = ""
$defaultAccountId = ""
foreach ($configPath in $configCandidates) {
    if (Test-Path $configPath) {
        foreach ($line in Get-Content $configPath) {
            if ($line -match "^ZERNIO_API_KEY=(.+)$") {
                $val = $matches[1].Trim()
                if ($val -and $val -notlike "your-*") { $apiKey = $val }
            }
            if ($line -match "^LINKEDIN_ACCOUNT_ID=(.+)$") {
                $defaultAccountId = $matches[1].Trim()
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

# Fall back to config-stored account ID if not passed as parameter
if (-not $AccountId) { $AccountId = $defaultAccountId }
if (-not $AccountId) {
    Write-Error "AccountId not provided and LINKEDIN_ACCOUNT_ID not set in config.env. Run list_accounts.ps1 to find your account ID."
    exit 1
}

# --- Build request body ---
$platform = @{
    platform  = "linkedin"
    accountId = $AccountId
}

$body = @{
    content   = $Content
    platforms = @($platform)
}

# Scheduling vs immediate
if ($ScheduledFor) {
    $body.scheduledFor = $ScheduledFor
    $body.timezone     = $Timezone
} else {
    $body.publishNow = $true
}

# Image attachment
if ($ImageUrl) {
    $body.mediaItems = @(@{ type = "image"; url = $ImageUrl })
}

$json = $body | ConvertTo-Json -Depth 6 -Compress

# --- Summary before posting ---
Write-Host ""
Write-Host "Posting to LinkedIn via Zernio..." -ForegroundColor Cyan
Write-Host "  Account  : $AccountId"
Write-Host "  Mode     : $(if ($ScheduledFor) { "Scheduled for $ScheduledFor ($Timezone)" } else { "Publish now" })"
Write-Host "  Image    : $(if ($ImageUrl) { $ImageUrl } else { "None" })"
Write-Host "  Content  : $($Content.Substring(0, [Math]::Min(80, $Content.Length)))$(if ($Content.Length -gt 80) { '...' })"
Write-Host ""

# --- Call Zernio API ---
$headers = @{
    Authorization  = "Bearer $apiKey"
    "Content-Type" = "application/json"
}

$response = Invoke-RestMethod -Uri "https://zernio.com/api/v1/posts" -Method POST -Headers $headers -Body $json

# --- Report result ---
$postId = $response.post._id
if ($ScheduledFor) {
    Write-Host "Scheduled!" -ForegroundColor Green
    Write-Host "  Post ID      : $postId"
    Write-Host "  Scheduled for: $ScheduledFor ($Timezone)"
} else {
    Write-Host "Published!" -ForegroundColor Green
    Write-Host "  Post ID: $postId"
}
