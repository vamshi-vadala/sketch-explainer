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
# GENERATE and PUBLISH are separated so you preview and publish the SAME artifact once,
# never regenerating (regeneration wastes spend AND ships a different post than you saw).
# Generate always saves the post+image to drafts/<slug-timestamp>/; publish loads it,
# validates it, and posts it with zero LLM cost. Every publish path runs validate_draft,
# so a short / refusal / hashtag-less / broken-image post can never reach LinkedIn.
#
# Usage:
#   ./scripts/run_scheduled.sh "topic"              # generate + validate + publish (cron one-shot)
#   DRY_RUN=1 ./scripts/run_scheduled.sh "topic"    # generate + save draft, do NOT publish (preview)
#   PUBLISH_DRAFT=drafts/xyz ./scripts/run_scheduled.sh   # publish that exact draft, no LLM cost
# Env:
#   NO_IMAGE=1      text-only post (skip image stages)
#   COST_CEILING=N  abort before next stage/publish if cumulative spend exceeds $N (default 0.30)
# Pause switch: create scripts/.pipeline-disabled to halt without editing crontab.
#
# Review-then-publish (no waste, ships what you saw):
#   DRY_RUN=1 ./scripts/run_scheduled.sh "AI agents"      # -> prints draft dir
#   # eyeball drafts/<dir>/post.txt
#   PUBLISH_DRAFT=drafts/<dir> ./scripts/run_scheduled.sh # -> posts it, $0
#
# Cron: 0 17 * * 0 /home/vadala_vamshi/sketch-explainer/scripts/run_scheduled.sh "generate a post on latest AI buzz most viewed in last 3 days" >> /home/vadala_vamshi/linkedin-post.log 2>&1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT="personalassistant-501418"

COST_LOG="${COST_LOG:-$REPO_DIR/linkedin-cost.log}"
COST_CEILING="${COST_CEILING:-0.30}"
DRAFTS_DIR="$REPO_DIR/drafts"
HAIKU="claude-haiku-4-5-20251001"
TOTAL_COST=0

# shellcheck source=lib_claude_stage.sh
. "$SCRIPT_DIR/lib_claude_stage.sh"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
abort() {
    printf '[%s] ABORT %s topic="%s"\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "${TOPIC:-<publish-draft>}" >> "$COST_LOG"
    echo "FATAL: $1 — not publishing" >&2
    exit 1
}

# --- Content gate: the reason a half-baked post can't ship ---
# Runs before EVERY publish (one-shot and PUBLISH_DRAFT). Cheap structural checks that
# catch the failure modes automation can silently produce: truncated/empty copy, a model
# refusal, missing hashtags, or a failed (tiny) image render.
validate_draft() {
    local post="$1" img="$2" want_img="$3" len
    len=${#post}
    [ "$len" -ge 150 ]  || abort "post too short (${len} chars, need >=150)"
    [ "$len" -le 3000 ] || abort "post too long (${len} chars, LinkedIn max ~3000)"
    printf '%s' "$post" | grep -q '#' || abort "post has no hashtag"
    case "$post" in
        "I'm sorry"*|"I am sorry"*|"I cannot"*|"I can't"*|"I apologize"*|"As an AI"*|"Sorry,"*|"Error"*)
            abort "post looks like a model refusal/error" ;;
    esac
    if [ "$want_img" = "1" ]; then
        [ -n "$img" ] && [ -f "$img" ] || abort "expected image missing: ${img:-<empty>}"
        local sz; sz=$(wc -c < "$img")
        [ "$sz" -ge 5000 ] || abort "image suspiciously small (${sz} bytes) — likely a failed render"
    fi
}

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

setup_git_auth() {
    # The helper fetches the token from Secret Manager at call time — the token is NEVER
    # written into ~/.gitconfig (no plaintext secret at rest) and rotation is picked up for
    # free. x-access-token is GitHub's universal token username (verified: it pushes cleanly);
    # the earlier "Invalid username or token" came from a stale helper feeding a real login.
    # --replace-all collapses any pre-existing/duplicate helpers to this single value.
    git config --global --replace-all "credential.https://github.com.helper" \
        '!f() { echo username=x-access-token; echo password=$(gcloud secrets versions access latest --secret=AILinkedInPost-Github-token --project='"$PROJECT"'); }; f'
    # Drop any hard-set username left by older versions (it overrides the helper's username).
    git config --global --unset-all 'credential.https://github.com.username' 2>/dev/null || true
}

publish() {
    local post="$1" img="$2"
    local post_script="$REPO_DIR/.claude/skills/linkedin-post-creator/scripts/post_linkedin.ps1"
    log "Publishing to LinkedIn"
    if [ -n "$img" ]; then
        pwsh -File "$post_script" -Content "$post" -ImagePath "$img"
    else
        pwsh -File "$post_script" -Content "$post"
    fi
}

# =========================================================================
# MODE A: publish an already-generated draft — no LLM, no regeneration cost.
# =========================================================================
if [ -n "$PUBLISH_DRAFT" ]; then
    DRAFT="$PUBLISH_DRAFT"
    [ -d "$DRAFT" ] || { echo "FATAL: draft dir not found: $DRAFT" >&2; exit 1; }
    [ -f "$DRAFT/post.txt" ] || { echo "FATAL: no post.txt in $DRAFT" >&2; exit 1; }
    POST=$(cat "$DRAFT/post.txt")
    IMG_PATH=""; WANT_IMG=0
    if [ -s "$DRAFT/image_path" ]; then IMG_PATH=$(cat "$DRAFT/image_path"); WANT_IMG=1; fi

    log "Publishing saved draft: $DRAFT"
    validate_draft "$POST" "$IMG_PATH" "$WANT_IMG"
    setup_git_auth
    cd "$REPO_DIR"
    publish "$POST" "$IMG_PATH"
    printf '[%s] PUBLISHED draft=%s cost=$0 published=yes\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$DRAFT" >> "$COST_LOG"
    log "Done. Published saved draft with no LLM cost."
    exit 0
fi

# =========================================================================
# MODE B: generate (stages 1-3) → save draft → validate → publish (unless DRY_RUN).
# =========================================================================
TOPIC="${1:?Usage: run_scheduled.sh \"topic\"  (or PUBLISH_DRAFT=<dir> run_scheduled.sh)}"

# --- Stage 0: secrets + git auth + pull ---
log "Fetching secrets from GCP Secret Manager..."
export ANTHROPIC_API_KEY=$(fetch_secret Linkedin-post-generator)
setup_git_auth

log "Pulling latest skills from GitHub..."
cd "$REPO_DIR"
git pull origin main

# --- Stage 1: research + write copy (LLM, scoped, bounded) ---
log "Stage 1: writing post for topic: $TOPIC"
run_claude_stage "write" "$HAIKU" 10 "WebSearch,WebFetch,Read,Skill" \
"Use the linkedin-post skill to research and write a LinkedIn post about: ${TOPIC}. Output ONLY the final post text, wrapped between <<<POST>>> and <<<ENDPOST>>> markers. No preamble, no explanation, no research-source note."

POST=$(printf '%s' "$STAGE_RESULT" | python3 -c '
import sys, re
t = sys.stdin.read()
m = re.search(r"<<<POST>>>(.*?)<<<ENDPOST>>>", t, re.S)
sys.stdout.write((m.group(1) if m else t).strip())
')
[ -n "$POST" ] || abort "stage 1 produced empty post"
check_ceiling

# --- Stage 2 + 3: image (skipped if NO_IMAGE) ---
IMG_PATH=""; WANT_IMG=0; IMG_SLUG=""
if [ -z "$NO_IMAGE" ]; then
    WANT_IMG=1
    log "Stage 2: designing image prompt"
    run_claude_stage "image" "$HAIKU" 6 "Read,Skill" \
"Use the sketch-explainer skill to design a whiteboard diagram that matches the LinkedIn post below. Do NOT generate the image — stop after producing the prompt. Output ONLY strict JSON of the form {\"slug\":\"<short-kebab-topic>\",\"prompt\":\"<full 150-250 word image prompt>\"}. Topic: ${TOPIC}. Post: ${POST}"

    parsed=$(printf '%s' "$STAGE_RESULT" | python3 -c '
import sys, json, base64, re
t = sys.stdin.read()
m = re.search(r"\{.*\}", t, re.S)   # tolerate stray prose / code fences
d = json.loads(m.group(0) if m else t)
print("IMG_SLUG_B64=" + base64.b64encode(d["slug"].encode()).decode())
print("IMG_PROMPT_B64=" + base64.b64encode(d["prompt"].encode()).decode())
') || abort "could not parse image JSON from stage 2"
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
    [ -n "$IMG_PATH" ] || abort "image render produced no saved path"
fi

# --- Save the draft (self-describing record; what publish will consume verbatim) ---
slug="${IMG_SLUG:-$(printf '%s' "$TOPIC" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-' | cut -c1-40)}"
DRAFT="$DRAFTS_DIR/${slug}-$(date '+%Y%m%d-%H%M%S')"
mkdir -p "$DRAFT"
printf '%s' "$POST" > "$DRAFT/post.txt"
printf '%s' "$IMG_PATH" > "$DRAFT/image_path"
log "Draft saved: $DRAFT"

# --- Validate before any publish decision ---
validate_draft "$POST" "$IMG_PATH" "$WANT_IMG"

if [ -n "$DRY_RUN" ]; then
    log "DRY_RUN — draft generated and validated, NOT published."
    echo "----- POST -----"; echo "$POST"
    echo "----- IMAGE -----"; echo "${IMG_PATH:-<none, text-only>}"
    echo ""
    echo "To publish this exact draft (no regeneration, \$0):"
    echo "  PUBLISH_DRAFT=\"$DRAFT\" $0"
    printf '[%s] DRY_RUN draft=%s total=$%s published=no topic="%s"\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$DRAFT" "$TOTAL_COST" "$TOPIC" >> "$COST_LOG"
    log "Done (dry run). Total LLM cost: \$$TOTAL_COST"
    exit 0
fi

# --- Publish the draft we just generated (one generation, no waste) ---
publish "$POST" "$IMG_PATH"
printf '[%s] PUBLISHED draft=%s total=$%s published=yes topic="%s"\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$DRAFT" "$TOTAL_COST" "$TOPIC" >> "$COST_LOG"
log "Done. Total LLM cost: \$$TOTAL_COST"
