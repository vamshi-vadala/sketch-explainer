#!/bin/bash
# run_scheduled.sh — deterministic orchestrator for the scheduled LinkedIn pipeline.
#
# The shell owns the flow, git auth, and publishing. The LLM is invoked ONLY for the
# two reasoning steps (write copy, design image prompt) — each on Haiku, turn-capped,
# and restricted to read/research tools so it cannot git-push or publish. Rendering and
# publishing are direct pwsh calls with fixed arguments: no LLM discretion in the
# side-effecting path. This is both the cost fix (a $6 Opus loop is now impossible) and
# the blast-radius fix. See scripts/lib_claude_stage.sh for the stage runner.
#
# Usage: ./scripts/run_scheduled.sh "topic or research directive"
# Env:
#   DRY_RUN=1       run stages 0-3, print the would-be post, do NOT publish
#   NO_IMAGE=1      skip image (stages 2-3), publish text-only
#   COST_CEILING=1  abort before next stage/publish if cumulative spend exceeds this ($)
# Pause switch: create scripts/.pipeline-disabled to halt without editing crontab.
#
# Cron: 0 17 * * 0 /home/vadala_vamshi/sketch-explainer/scripts/run_scheduled.sh "generate a post on latest AI buzz most viewed in last 3 days" >> /home/vadala_vamshi/linkedin-post.log 2>&1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT="personalassistant-501418"

TOPIC="${1:?Usage: run_scheduled.sh \"topic\"}"
COST_LOG="${COST_LOG:-$REPO_DIR/linkedin-cost.log}"
COST_CEILING="${COST_CEILING:-1.00}"
HAIKU="claude-haiku-4-5-20251001"
TOTAL_COST=0

# shellcheck source=lib_claude_stage.sh
. "$SCRIPT_DIR/lib_claude_stage.sh"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# --- Pause switch: lets a run be halted without touching crontab ---
if [ -f "$SCRIPT_DIR/.pipeline-disabled" ]; then
    log "Pipeline disabled (scripts/.pipeline-disabled present) — exiting."
    exit 0
fi

fetch_secret() {
    local name="$1" value
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

# --- Stage 0: secrets + git auth + pull ---
log "Fetching secrets from GCP Secret Manager..."
export ANTHROPIC_API_KEY=$(fetch_secret Linkedin-post-generator)
export GITHUB_TOKEN=$(fetch_secret AILinkedInPost-Github-token)
GITHUB_USERNAME=$(fetch_secret github-username)

# Configure git auth for GitHub pushes (needed for image uploads).
# Use a fixed-key credential helper so re-runs overwrite cleanly — embedding the
# token in an insteadOf URL creates a new config key per token and leaves stale
# (empty-token) rules behind, which silently breaks auth on later runs.
git config --global "credential.https://github.com.helper" \
    "!f() { echo username=${GITHUB_USERNAME}; echo password=${GITHUB_TOKEN}; }; f"
# Remove any legacy insteadOf rules left by earlier versions of this script
git config --global --remove-section 'url.https://'"${GITHUB_USERNAME}"':'"${GITHUB_TOKEN}"'@github.com/' 2>/dev/null || true

log "Pulling latest skills from GitHub..."
cd "$REPO_DIR"
git pull origin main

# --- Stage 1: research + write copy (LLM, scoped, bounded) ---
log "Stage 1: writing post for topic: $TOPIC"
run_claude_stage "write" "$HAIKU" 8 "WebSearch,WebFetch,Read,Skill" \
"Use the linkedin-post skill to research and write a LinkedIn post about: ${TOPIC}. Output ONLY the final post text, wrapped between <<<POST>>> and <<<ENDPOST>>> markers. No preamble, no explanation, no research-source note."

POST=$(printf '%s' "$STAGE_RESULT" | python3 -c '
import sys, re
t = sys.stdin.read()
m = re.search(r"<<<POST>>>(.*?)<<<ENDPOST>>>", t, re.S)
sys.stdout.write((m.group(1) if m else t).strip())
')
if [ -z "$POST" ]; then
    echo "FATAL: stage 1 produced empty post" >&2
    exit 1
fi
check_ceiling

# --- Stage 2 + 3: image (skipped if NO_IMAGE) ---
IMG_PATH=""
if [ -z "$NO_IMAGE" ]; then
    log "Stage 2: designing image prompt"
    run_claude_stage "image" "$HAIKU" 4 "Read,Skill" \
"Use the sketch-explainer skill to design a whiteboard diagram that matches the LinkedIn post below. Do NOT generate the image — stop after producing the prompt. Output ONLY strict JSON of the form {\"slug\":\"<short-kebab-topic>\",\"prompt\":\"<full 150-250 word image prompt>\"}. Topic: ${TOPIC}. Post: ${POST}"

    parsed=$(printf '%s' "$STAGE_RESULT" | python3 -c '
import sys, json, base64, re
t = sys.stdin.read()
m = re.search(r"\{.*\}", t, re.S)   # tolerate stray prose / code fences
d = json.loads(m.group(0) if m else t)
print("IMG_SLUG_B64=" + base64.b64encode(d["slug"].encode()).decode())
print("IMG_PROMPT_B64=" + base64.b64encode(d["prompt"].encode()).decode())
') || { echo "FATAL: could not parse image JSON from stage 2" >&2; exit 1; }
    eval "$parsed"
    IMG_SLUG=$(printf '%s' "$IMG_SLUG_B64" | base64 -d)
    IMG_PROMPT=$(printf '%s' "$IMG_PROMPT_B64" | base64 -d)
    check_ceiling

    log "Stage 3: rendering image (slug=$IMG_SLUG)"
    GEN="$REPO_DIR/.claude/skills/image-generator/scripts/generate_image.ps1"
    # 2>&1: capture Write-Host (PowerShell information stream) so the "Saved : <path>" line is seen
    render_out=$(pwsh -File "$GEN" -TopicSlug "$IMG_SLUG" -Prompt "$IMG_PROMPT" 2>&1)
    echo "$render_out"
    IMG_PATH=$(printf '%s\n' "$render_out" | sed -n 's/^Saved *: *//p' | tail -n1)
    if [ -z "$IMG_PATH" ]; then
        echo "FATAL: image render produced no saved path" >&2
        exit 1
    fi
fi

# --- Stage 4: publish (deterministic; skipped on DRY_RUN) ---
POST_SCRIPT="$REPO_DIR/.claude/skills/linkedin-post-creator/scripts/post_linkedin.ps1"

if [ -n "$DRY_RUN" ]; then
    log "DRY_RUN — not publishing. Would post:"
    echo "----- POST -----"
    echo "$POST"
    echo "----- IMAGE -----"
    echo "${IMG_PATH:-<none, text-only>}"
    printf '[%s] DRY_RUN total=$%s published=no topic="%s"\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$TOTAL_COST" "$TOPIC" >> "$COST_LOG"
    log "Done (dry run). Total LLM cost: \$$TOTAL_COST"
    exit 0
fi

log "Stage 4: publishing to LinkedIn"
if [ -n "$IMG_PATH" ]; then
    pwsh -File "$POST_SCRIPT" -Content "$POST" -ImagePath "$IMG_PATH"
else
    pwsh -File "$POST_SCRIPT" -Content "$POST"
fi

printf '[%s] PUBLISHED total=$%s published=yes topic="%s"\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$TOTAL_COST" "$TOPIC" >> "$COST_LOG"
log "Done. Total LLM cost: \$$TOTAL_COST"
