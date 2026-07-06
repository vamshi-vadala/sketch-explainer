#!/bin/bash
# run_scheduled.sh — fetch secrets from GCP Secret Manager and run a Claude scheduled task
# Usage: ./scripts/run_scheduled.sh "your prompt here"
# Cron:  0 17 * * 0 /home/vadala_vamshi/sketch-explainer/scripts/run_scheduled.sh "generate and publish a post on latest AI buzz that is most viewed in last 3 days" >> /home/vadala_vamshi/linkedin-post.log 2>&1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT="personalassistant-501418"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

log "Fetching secrets from GCP Secret Manager..."
export ANTHROPIC_API_KEY=$(gcloud secrets versions access latest --secret=anthropic-api-key --project=$PROJECT)
export GITHUB_TOKEN=$(gcloud secrets versions access latest --secret=github-token --project=$PROJECT)
GITHUB_USERNAME=$(gcloud secrets versions access latest --secret=github-username --project=$PROJECT)

# Configure git to use the token for GitHub pushes (needed for image uploads)
git config --global url."https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"

log "Pulling latest skills from GitHub..."
cd "$REPO_DIR"
git pull origin main

log "Running Claude: $1"
claude --dangerously-skip-permissions "$1"

log "Done."
