# generate_image.ps1 — Generate a sketch explainer image via Gemini REST API
# No Python or pip required. Uses PowerShell built-ins only.
#
# Usage:
#   .\generate_image.ps1 -TopicSlug "wealth-creation" -PromptFile "path\to\prompt.txt"
#   .\generate_image.ps1 -TopicSlug "wealth-creation" -Prompt "full prompt text"

param(
    [Parameter(Mandatory)][string]$TopicSlug,
    [string]$PromptFile,
    [string]$Prompt
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

# --- Resolve API key: skill-local config.env → shared skills config.env → env var → GCP Secret Manager ---
$skillDir = Split-Path $PSScriptRoot -Parent
$sharedDir = Split-Path $skillDir -Parent
$configCandidates = @(
    (Join-Path $skillDir "config.env"),   # skill-local override
    (Join-Path $sharedDir "config.env")   # shared across all skills
)
$apiKey = ""
foreach ($configPath in $configCandidates) {
    if (Test-Path $configPath) {
        foreach ($line in Get-Content $configPath) {
            if ($line -match "^GEMINI_API_KEY=(.+)$") {
                $val = $matches[1].Trim()
                if ($val -and $val -ne "your-api-key-here") { $apiKey = $val; break }
            }
        }
    }
    if ($apiKey) { break }
}
if (-not $apiKey) { $apiKey = $env:GEMINI_API_KEY }
if (-not $apiKey) { $apiKey = Get-GcpSecret "gemini-api-key" }
if (-not $apiKey) {
    Write-Error "GEMINI_API_KEY not found. Set it in .claude/skills/config.env, as an env var, or in GCP Secret Manager as 'gemini-api-key'."
    exit 1
}

# --- Resolve prompt ---
if ($PromptFile) {
    $promptText = Get-Content $PromptFile -Raw -Encoding UTF8
} elseif ($Prompt) {
    $promptText = $Prompt
} else {
    Write-Error "Provide -PromptFile or -Prompt."
    exit 1
}
$promptText = $promptText.Trim()

# --- Output path ---
$outputDir = Join-Path (Split-Path $PSScriptRoot -Parent) "generated-images"
if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir | Out-Null }
$slug = ($TopicSlug -replace "[^\w-]", "-").ToLower().TrimEnd("-")
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputPath = Join-Path $outputDir "$slug-$timestamp.png"

# --- Call Gemini API ---
$body = @{
    contents = @(
        @{ parts = @(@{ text = $promptText }) }
    )
} | ConvertTo-Json -Depth 6 -Compress

$url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-image-preview:generateContent?key=$apiKey"

Write-Host "Topic  : $slug"
Write-Host "Prompt : $($promptText.Length) chars"
Write-Host "Calling: gemini-3.1-flash-image-preview ..."

$response = Invoke-RestMethod -Uri $url -Method POST -ContentType "application/json; charset=utf-8" -Body $body

# --- Extract and save image ---
$saved = $false
foreach ($part in $response.candidates[0].content.parts) {
    if ($part.PSObject.Properties["inlineData"]) {
        $bytes = [Convert]::FromBase64String($part.inlineData.data)
        [System.IO.File]::WriteAllBytes($outputPath, $bytes)
        Write-Host "Saved  : $outputPath"
        $saved = $true
        break
    }
    if ($part.PSObject.Properties["text"]) {
        Write-Host "[model]: $($part.text)"
    }
}

if (-not $saved) {
    Write-Error "No image returned by the API. Check the prompt or your API quota."
    exit 1
}
