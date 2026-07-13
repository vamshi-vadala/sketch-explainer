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
# HITL Model B (publish-unless-vetoed): the default generate run SCHEDULES the post
# SCHEDULE_HOURS out via Zernio and sends a Telegram notification, giving a review/veto
# window. It auto-publishes at that time unless you cancel/edit it in Zernio.
#
# Usage:
#   ./scripts/run_scheduled.sh "topic"              # generate + validate + SCHEDULE + notify (cron)
#   PUBLISH_NOW=1 ./scripts/run_scheduled.sh "topic"      # generate + publish immediately (no wait)
#   DRY_RUN=1 ./scripts/run_scheduled.sh "topic"    # generate + save draft, do NOT publish (preview)
#   PUBLISH_DRAFT=drafts/xyz ./scripts/run_scheduled.sh   # publish that exact draft now, no LLM cost
#   PUBLISH_DRAFT=drafts/xyz SCHEDULE_HOURS=2 ./scripts/run_scheduled.sh  # SCHEDULE that draft (Model B), $0
# Env:
#   SCHEDULE_HOURS=N  how far out to schedule (default 36; 0 = publish now)
#   TIMEZONE=Area/City  timezone for the scheduled time (default UTC)
#   NO_IMAGE=1        text-only post (skip image stages)
#   COST_CEILING=N    abort before next stage/publish if cumulative spend exceeds $N (default 0.30)
# Notify secrets (best-effort, never abort): linkedin-bot-token, telegram-chat-id.
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

    # Self-heal stray URL rewrites: an old `url."https://user:@github.com/".insteadOf`
    # silently rewrites every github.com URL to embed a username + empty password, which
    # makes git bypass the helper and fail with "Invalid username or token". Strip any such
    # github.com insteadOf rule so the clean URL always flows through the helper above.
    git config --global --get-regexp 'url\..*github\.com.*\.insteadof' 2>/dev/null \
        | awk '{print $1}' | sort -u | while read -r key; do
            git config --global --unset-all "$key" 2>/dev/null || true
        done
    # Self-heal embedded credentials baked into the origin remote URL (same failure mode:
    # a revoked token frozen in the URL wins over the helper). Reset to the canonical HTTPS URL.
    origin_url=$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null || true)
    case "$origin_url" in
        *@github.com/*)
            git -C "$REPO_DIR" remote set-url origin \
                "https://github.com/${origin_url#*@github.com/}" 2>/dev/null || true
            ;;
    esac
}

POST_SCRIPT="$REPO_DIR/.claude/skills/linkedin-post-creator/scripts/post_linkedin.ps1"

publish() {
    local post="$1" img="$2"
    log "Publishing to LinkedIn (now)"
    if [ -n "$img" ]; then
        pwsh -File "$POST_SCRIPT" -Content "$post" -ImagePath "$img"
    else
        pwsh -File "$POST_SCRIPT" -Content "$post"
    fi
}

# Model B: schedule the post out into the future via Zernio, giving a review/veto window.
# Captures the Zernio post id + resolved image URL (emitted as ZERNIO_* markers by the .ps1)
# into globals so notify_telegram can build a working Cancel button. Output is re-emitted so
# it still lands in the cron log.
ZERNIO_POST_ID=""
ZERNIO_IMAGE_URL=""
schedule_post() {
    local post="$1" img="$2" when="$3" tz="$4" out
    log "Scheduling LinkedIn post for $when $tz"
    if [ -n "$img" ]; then
        out=$(pwsh -File "$POST_SCRIPT" -Content "$post" -ImagePath "$img" -ScheduledFor "$when" -Timezone "$tz")
    else
        out=$(pwsh -File "$POST_SCRIPT" -Content "$post" -ScheduledFor "$when" -Timezone "$tz")
    fi
    local rc=$?
    printf '%s\n' "$out"                       # keep the human-readable output in the log
    [ $rc -eq 0 ] || return $rc                # propagate a real scheduling failure
    ZERNIO_POST_ID=$(printf '%s\n'  "$out" | sed -n 's/^ZERNIO_POST_ID=//p'  | tr -d '\r' | head -1)
    ZERNIO_IMAGE_URL=$(printf '%s\n' "$out" | sed -n 's/^ZERNIO_IMAGE_URL=//p' | tr -d '\r' | head -1)
}

# Best-effort phone notification. NEVER aborts the run — the post is already scheduled by the
# time we notify, so a failed/absent Telegram secret must not turn a good schedule into an error.
# Sends the image as a real photo (sendPhoto) with the auto-publish time up top and a ❌ Cancel
# button. The button's callback carries "cancel:<postId>:<epoch>"; the veto bot (telegram_veto_bot.py)
# deletes the scheduled Zernio post on tap, and refuses once <epoch> has passed (already live).
notify_telegram() {
    local post="$1" img_url="$2" when="$3" tz="$4" hours="$5" post_id="$6"
    local bot chat epoch header preview budget caption reply_markup base
    bot=$(gcloud secrets versions access latest --secret=linkedin-bot-token --project="$PROJECT" 2>/dev/null) \
        || { log "WARNING: linkedin-bot-token unavailable — skipping Telegram notify"; return 0; }
    chat=$(gcloud secrets versions access latest --secret=telegram-chat-id --project="$PROJECT" 2>/dev/null) \
        || { log "WARNING: telegram-chat-id unavailable — skipping Telegram notify"; return 0; }

    # Epoch of the scheduled publish instant (interpreted in the same zone we gave Zernio).
    epoch=$(TZ="$tz" date -d "$when" +%s 2>/dev/null || echo 0)

    # Caption: prominent publish time, then the post preview. Telegram photo captions cap at
    # 1024 chars; LinkedIn posts run longer, so truncate the preview to fit under the limit.
    header=$(printf '⏰ Auto-publishes: %s %s (in %sh)\nTap ❌ below to cancel — otherwise it goes live.\n\n' "$when" "$tz" "$hours")
    preview="$post"
    budget=$(( 1000 - ${#header} ))
    if [ ${#preview} -gt $budget ]; then
        preview="${preview:0:$((budget-34))}…(full text in the scheduled post)"
    fi
    caption="${header}${preview}"

    reply_markup=$(printf '{"inline_keyboard":[[{"text":"❌ Cancel this post","callback_data":"cancel:%s:%s"}]]}' "$post_id" "$epoch")
    base="https://api.telegram.org/bot${bot}"

    if [ -n "$img_url" ] && [ -n "$post_id" ]; then
        if curl -s -o /dev/null "${base}/sendPhoto" \
            --data-urlencode "chat_id=${chat}" \
            --data-urlencode "photo=${img_url}" \
            --data-urlencode "caption=${caption}" \
            --data-urlencode "reply_markup=${reply_markup}"; then
            log "Telegram photo + veto button sent"
        else
            log "WARNING: Telegram sendPhoto failed (post is still scheduled)"
        fi
    else
        # No image or no post id to cancel — fall back to a text notice (still with a button if we have an id).
        if curl -s -o /dev/null "${base}/sendMessage" \
            --data-urlencode "chat_id=${chat}" \
            --data-urlencode "text=${caption}" \
            ${post_id:+--data-urlencode "reply_markup=${reply_markup}"} \
            -d disable_web_page_preview=true; then
            log "Telegram notification sent"
        else
            log "WARNING: Telegram send failed (post is still scheduled)"
        fi
    fi
    return 0
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

    log "Resuming saved draft (no LLM cost): $DRAFT"
    validate_draft "$POST" "$IMG_PATH" "$WANT_IMG"
    setup_git_auth
    cd "$REPO_DIR"

    # Default is publish-now (the documented PUBLISH_DRAFT contract). Opt into Model B by
    # setting SCHEDULE_HOURS>0: the SAME saved artifact flows through schedule_post + notify,
    # i.e. the full Mode B schedule/veto path at $0 — used to resume a schedule after a
    # mid-run failure without regenerating. PUBLISH_NOW=1 forces immediate publish.
    A_SCHEDULE_HOURS="${SCHEDULE_HOURS:-0}"
    TIMEZONE="${TIMEZONE:-UTC}"
    if [ -z "$PUBLISH_NOW" ] && [ "$A_SCHEDULE_HOURS" != "0" ]; then
        WHEN=$(TZ="$TIMEZONE" date -d "+${A_SCHEDULE_HOURS} hours" '+%Y-%m-%dT%H:%M:%S')
        schedule_post "$POST" "$IMG_PATH" "$WHEN" "$TIMEZONE"
        notify_telegram "$POST" "$ZERNIO_IMAGE_URL" "$WHEN" "$TIMEZONE" "$A_SCHEDULE_HOURS" "$ZERNIO_POST_ID"
        printf '[%s] SCHEDULED draft=%s for=%s %s cost=$0 published=scheduled\n' \
            "$(date '+%Y-%m-%d %H:%M:%S')" "$DRAFT" "$WHEN" "$TIMEZONE" >> "$COST_LOG"
        log "Done (scheduled saved draft for $WHEN $TIMEZONE, notified). No LLM cost."
    else
        publish "$POST" "$IMG_PATH"
        printf '[%s] PUBLISHED draft=%s cost=$0 published=yes\n' \
            "$(date '+%Y-%m-%d %H:%M:%S')" "$DRAFT" >> "$COST_LOG"
        log "Done. Published saved draft with no LLM cost."
    fi
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

# --- Model B (default): schedule the draft out into the future + notify, so there is a
#     review/veto window in Zernio. PUBLISH_NOW=1 (or SCHEDULE_HOURS=0) posts immediately. ---
SCHEDULE_HOURS="${SCHEDULE_HOURS:-36}"
TIMEZONE="${TIMEZONE:-UTC}"

if [ -n "$PUBLISH_NOW" ] || [ "$SCHEDULE_HOURS" = "0" ]; then
    publish "$POST" "$IMG_PATH"
    printf '[%s] PUBLISHED draft=%s total=$%s published=now topic="%s"\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$DRAFT" "$TOTAL_COST" "$TOPIC" >> "$COST_LOG"
    log "Done (published now). Total LLM cost: \$$TOTAL_COST"
else
    # Wall-clock in TIMEZONE so it matches the -Timezone we pass to Zernio.
    WHEN=$(TZ="$TIMEZONE" date -d "+${SCHEDULE_HOURS} hours" '+%Y-%m-%dT%H:%M:%S')
    schedule_post "$POST" "$IMG_PATH" "$WHEN" "$TIMEZONE"
    notify_telegram "$POST" "$ZERNIO_IMAGE_URL" "$WHEN" "$TIMEZONE" "$SCHEDULE_HOURS" "$ZERNIO_POST_ID"
    printf '[%s] SCHEDULED draft=%s for=%s %s total=$%s published=scheduled topic="%s"\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$DRAFT" "$WHEN" "$TIMEZONE" "$TOTAL_COST" "$TOPIC" >> "$COST_LOG"
    log "Done (scheduled for $WHEN $TIMEZONE, notified). Total LLM cost: \$$TOTAL_COST"
fi
