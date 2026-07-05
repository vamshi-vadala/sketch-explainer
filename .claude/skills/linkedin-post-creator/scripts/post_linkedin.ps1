# post_linkedin.ps1 — Publish or schedule a LinkedIn post via Zernio API
#
# Usage:
#   .\post_linkedin.ps1 -AccountId "<id>" -Content "Post text"
#   .\post_linkedin.ps1 -AccountId "<id>" -Content "Post text" -ImageUrl "https://..."
#   .\post_linkedin.ps1 -AccountId "<id>" -Content "Post text" -ImagePath "C:\path\to\image.png"
#   .\post_linkedin.ps1 -AccountId "<id>" -Content "Post text" -ScheduledFor "2026-05-20T14:00:00" -Timezone "Asia/Kolkata"
#   .\post_linkedin.ps1 -AccountId "<id>" -Content "Post text" -ImagePath "C:\path\to\image.png" -ScheduledFor "2026-05-20T14:00:00" -Timezone "UTC"
#
# ImagePath: local file path — automatically committed to GitHub and converted to a raw public URL.
# ImageUrl:  already-public URL — used directly.

param(
    [string]$AccountId,
    [Parameter(Mandatory)][string]$Content,
    [string]$ImageUrl,
    [string]$ImagePath,
    [string]$ScheduledFor,
    [string]$Timezone = "UTC"
)

$ErrorActionPreference = "Stop"

# --- GCP Secret Manager fallback (used on VM; silently skipped if gcloud unavailable) ---
function Get-GcpSecret([string]$Name) {
    try {
        $val = & gcloud secrets versions access latest --secret=$Name --project=personalassistant-501418 2>$null
        if ($LASTEXITCODE -eq 0 -and $val) { return $val.Trim() }
    } catch {}
    return $null
}

# --- Resolve API key from shared config → env var → GCP Secret Manager ---
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
if (-not $apiKey) { $apiKey = Get-GcpSecret "zernio-api-key" }
if (-not $apiKey) {
    Write-Error "ZERNIO_API_KEY not found. Add it to .claude/skills/config.env, as an env var, or in GCP Secret Manager as 'zernio-api-key'."
    exit 1
}

# Fall back to config-stored account ID if not passed as parameter
if (-not $AccountId) { $AccountId = $defaultAccountId }
if (-not $AccountId) { $AccountId = $env:LINKEDIN_ACCOUNT_ID }
if (-not $AccountId) { $AccountId = Get-GcpSecret "linkedin-account-id" }
if (-not $AccountId) {
    Write-Error "AccountId not provided and LINKEDIN_ACCOUNT_ID not set in config.env, env var, or GCP Secret Manager as 'linkedin-account-id'."
    exit 1
}

# --- Publish local image to GitHub and resolve public URL ---
if ($ImagePath) {
    if (-not (Test-Path $ImagePath)) {
        Write-Error "ImagePath not found: $ImagePath"
        exit 1
    }

    # Find repo root and remote URL
    $repoRoot = & git -C $PSScriptRoot rev-parse --show-toplevel 2>&1
    if ($LASTEXITCODE -ne 0) { Write-Error "Not inside a git repo — cannot publish image"; exit 1 }

    $remoteUrl = & git -C $repoRoot remote get-url origin 2>&1
    if ($remoteUrl -match "github\.com[:/](.+?)(?:\.git)?$") {
        $ownerRepo = $matches[1]
    } else {
        Write-Error "Could not parse GitHub owner/repo from remote: $remoteUrl"
        exit 1
    }

    # Copy image into assets/linkedin/ in the repo
    $assetsDir = Join-Path $repoRoot "assets\linkedin"
    if (-not (Test-Path $assetsDir)) { New-Item -ItemType Directory -Path $assetsDir | Out-Null }

    $filename  = Split-Path $ImagePath -Leaf
    $destPath  = Join-Path $assetsDir $filename
    Copy-Item $ImagePath $destPath -Force

    # Commit and push (skip if nothing changed — image already there)
    $relativePath = "assets/linkedin/$filename"
    & git -C $repoRoot add $relativePath | Out-Null
    $status = & git -C $repoRoot status --porcelain $relativePath
    if ($status) {
        & git -C $repoRoot commit -m "Add image for LinkedIn post: $filename" | Out-Null
        & git -C $repoRoot push origin HEAD | Out-Null
        Write-Host "  Pushed image to GitHub: $relativePath" -ForegroundColor DarkCyan
    } else {
        Write-Host "  Image already in GitHub: $relativePath" -ForegroundColor DarkCyan
    }

    $branch   = & git -C $repoRoot rev-parse --abbrev-ref HEAD
    $ImageUrl = "https://raw.githubusercontent.com/$ownerRepo/$branch/$relativePath"
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
Write-Host "  Image    : $(if ($ImageUrl) { $ImageUrl } elseif ($ImagePath) { $ImagePath } else { "None" })"
Write-Host "  Content  : $($Content.Substring(0, [Math]::Min(80, $Content.Length)))$(if ($Content.Length -gt 80) { '...' })"
Write-Host ""

# --- Call Zernio API ---
$headers = @{
    Authorization  = "Bearer $apiKey"
    "Content-Type" = "application/json"
}

$response = Invoke-RestMethod -Uri "https://zernio.com/api/v1/posts" -Method POST -Headers $headers -Body $json

# --- Report result ---
$postId  = $response.post._id
$postUrl = $response.post.platforms[0].platformPostUrl
if ($ScheduledFor) {
    Write-Host "Scheduled!" -ForegroundColor Green
    Write-Host "  Post ID      : $postId"
    Write-Host "  Scheduled for: $ScheduledFor ($Timezone)"
} else {
    Write-Host "Published!" -ForegroundColor Green
    Write-Host "  Post ID : $postId"
    if ($postUrl) { Write-Host "  Post URL: $postUrl" -ForegroundColor Cyan }
}
