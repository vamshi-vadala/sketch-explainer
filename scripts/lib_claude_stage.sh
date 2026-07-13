# lib_claude_stage.sh — run one scoped, bounded Claude stage and record its cost.
# Sourced by run_scheduled.sh. Uses python3 (no jq dependency) to parse JSON.
#
# Each stage is deliberately constrained up front (model + max-turns + allowed tools)
# so a runaway loop is structurally impossible — see run_scheduled.sh header.
#
# run_claude_stage <stage> <model> <max_turns> <allowed_tools> <prompt> sets globals:
#   STAGE_RESULT — the model's .result text
#   STAGE_COST   — .total_cost_usd for this stage
#   STAGE_TURNS  — .num_turns for this stage
# and accumulates TOTAL_COST (caller must initialize to 0).
#
# Requires these globals from the caller: TOTAL_COST, COST_LOG, TOPIC, COST_CEILING.

run_claude_stage() {
    local stage="$1" model="$2" max_turns="$3" allowed_tools="$4" prompt="$5"
    local raw parsed

    # No --dangerously-skip-permissions: in headless --print mode any tool outside
    # the allowlist is denied, so a reasoning stage physically cannot git-push or publish.
    # Prompt goes via stdin, not a positional arg: --allowedTools is variadic and would
    # otherwise swallow the prompt as a tool name ("Input must be provided ..." error).
    raw=$(printf '%s' "$prompt" | claude --print --output-format json \
        --model "$model" \
        --max-turns "$max_turns" \
        --allowedTools "$allowed_tools") || {
        echo "FATAL: claude stage '$stage' failed to run" >&2
        exit 1
    }

    # Parse JSON with python3. Base64 the result text so newlines/quotes survive
    # the shell round-trip; emit eval-able assignments for the numeric fields.
    parsed=$(printf '%s' "$raw" | python3 -c '
import sys, json, base64
try:
    d = json.load(sys.stdin)
except Exception as e:
    sys.stderr.write("json parse error: %s\n" % e); sys.exit(1)
sub = d.get("subtype", "") or ""
# Abort on any error result — crucially error_max_turns, which means the stage was
# cut off mid-work. A truncated post must never reach publish.
if d.get("is_error") or sub.startswith("error"):
    sys.stderr.write("claude result error (subtype=%s)\n" % sub); sys.exit(1)
res = d.get("result", "") or ""
print("STAGE_RESULT_B64=" + base64.b64encode(res.encode()).decode())
print("STAGE_COST=" + repr(float(d.get("total_cost_usd", 0) or 0)))
print("STAGE_TURNS=" + str(int(d.get("num_turns", 0) or 0)))
') || {
        echo "FATAL: could not parse claude JSON for stage '$stage'" >&2
        exit 1
    }

    eval "$parsed"
    STAGE_RESULT=$(printf '%s' "$STAGE_RESULT_B64" | base64 -d)

    # Accumulate cost and append an observability line.
    TOTAL_COST=$(python3 -c "print(repr($TOTAL_COST + $STAGE_COST))")
    printf '[%s] stage=%-5s model=%s turns=%s cost=$%s cumulative=$%s topic="%s"\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$stage" "$model" "$STAGE_TURNS" \
        "$STAGE_COST" "$TOTAL_COST" "$TOPIC" >> "$COST_LOG"
}

# check_ceiling — inter-stage circuit breaker. Abort before the next stage/publish
# if cumulative spend crossed COST_CEILING. This only limits blast on a bad stage;
# the real guard is the up-front model/turn/tool bounds above.
check_ceiling() {
    local over
    over=$(python3 -c "print(1 if $TOTAL_COST > $COST_CEILING else 0)")
    if [ "$over" = "1" ]; then
        printf '[%s] ABORT cost=$%s > ceiling=$%s topic="%s"\n' \
            "$(date '+%Y-%m-%d %H:%M:%S')" "$TOTAL_COST" "$COST_CEILING" "$TOPIC" >> "$COST_LOG"
        echo "FATAL: cumulative cost \$$TOTAL_COST exceeded ceiling \$$COST_CEILING — aborting before further stages/publish" >&2
        exit 1
    fi
}
