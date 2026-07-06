#!/bin/bash
# run_scheduled.sh — fetch secrets from GCP Secret Manager and run a Claude scheduled task
# Usage: ./scripts/run_scheduled.sh "your prompt here"
# Cron:  0 17 * * 0 /home/vadala_vamshi/sketch-explainer/scripts/run_scheduled.sh "generate and publish a post on latest AI buzz that is most viewed in last 3 days" >> /home/vadala_vamshi/linkedin-post.log 2>&1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT="personalassistant-501418"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

fetch_secret() {
    local name="$1"
    local value
    value=$(gcloud secrets versions access latest --secret="$name" --project="$PROJECT") || {
        echo "FATAL: failed to fetch secret '$name' from Secret Manager" >&2
        exit 1
    }
    if [ -z "$value" ]; then
        echo "FATAL: secret '$name' returned empty value" >&2
        exit 1
    fi
    echo "$value"
}

log "Fetching secrets from GCP Secret Manager..."
export ANTHROPIC_API_KEY=$(fetch_secret anthropic-api-key)
export GITHUB_TOKEN=$(fetch_secret AILinkedInPost-Github-token)
GITHUB_USERNAME=$(fetch_secret github-username)

# Configure git to use the token for GitHub pushes (needed for image uploads)
git config --global url."https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"

log "Pulling latest skills from GitHub..."
cd "$REPO_DIR"
git pull origin main

log "Running Claude: $1"
claude --print --dangerously-skip-permissions "$1"

log "Done."
