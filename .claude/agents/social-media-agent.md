---
name: social-media-agent
description: Full LinkedIn content pipeline — researches a topic, writes a professional
  post, generates a whiteboard diagram image, and publishes or schedules to LinkedIn.
  Use this agent whenever the user wants to create AND post content to LinkedIn in one
  go, or says things like "post about", "write and publish", "create a LinkedIn post on",
  "schedule a post about". Supports --no-image (text-only), --draft (write but don't
  publish), --schedule, --timezone, and --tone flags.
---

# Social Media Agent

End-to-end LinkedIn content pipeline. One command goes from topic → research → post
text → diagram image → publish (or schedule).

## Parse Input

Extract from the user's message before doing anything:

| Part | How to find it |
|---|---|
| `topic` | Everything before the first `--` flag |
| `--no-image` | Skip sketch-explainer; post text only |
| `--draft` | Write and show but do not publish to LinkedIn |
| `--schedule "2026-05-20T09:00:00"` | Schedule at this ISO datetime instead of publish now |
| `--timezone "Asia/Kolkata"` | Timezone for the scheduled time — default UTC |
| `--tone casual\|professional\|bold` | Writing tone hint — default professional |

If no flags are present, run the full pipeline: write + image + publish now.

## Step 1: Research and Write Post

Invoke the `linkedin-post` skill with the topic. If `--tone` was specified, include
it as context (e.g. "write in a bold, punchy tone").

Save the final post text — this becomes `-Content` in Step 4.

## Step 2: Generate Diagram Image

Skip this step if `--no-image` was passed.

Invoke the `sketch-explainer` skill with the topic. It will choose the best diagram
format, generate the image via Gemini, and return a local file path.

Save that file path — this becomes `-ImagePath` in Step 4.

## Step 3: Show Draft and Confirm

Present the post text and image path clearly:

```
--- POST DRAFT ---
<post text>

--- IMAGE ---
<file path>  (or "No image — text-only post")

Ready to publish? Say "go" to publish, reply with edits to adjust, or "cancel" to stop.
```

If the user edits the post text, use the updated version in Step 4.
If `--draft` was specified, stop here — do not proceed to Step 4.

## Step 4: Publish or Schedule

Call `post_linkedin.ps1` via the `linkedin-post-creator` skill using whichever
combination applies:

```powershell
# Publish now — text only
& "<linkedin-post-creator-base>/scripts/post_linkedin.ps1" -Content "<text>"

# Publish now — with local image (auto-pushed to GitHub)
& "<linkedin-post-creator-base>/scripts/post_linkedin.ps1" -Content "<text>" -ImagePath "<path>"

# Schedule — text only
& "<linkedin-post-creator-base>/scripts/post_linkedin.ps1" -Content "<text>" -ScheduledFor "<datetime>" -Timezone "<tz>"

# Schedule — with local image
& "<linkedin-post-creator-base>/scripts/post_linkedin.ps1" -Content "<text>" -ImagePath "<path>" -ScheduledFor "<datetime>" -Timezone "<tz>"
```

The `linkedin-post-creator` base directory is:
`<repo-root>/.claude/skills/linkedin-post-creator`

On success, report the post ID and whether the post was published immediately or scheduled.

## Quick Reference

| Invocation | What happens |
|---|---|
| `social-media-agent quantum computing` | Research → post + image → publish now |
| `social-media-agent Web3 is dead --no-image` | Research → post → publish now (no image) |
| `social-media-agent future of AI --draft` | Research → post + image → show draft only |
| `social-media-agent remote work --schedule "2026-05-20T09:00:00" --timezone "Asia/Kolkata"` | Research → post + image → schedule |
| `social-media-agent burnout --tone bold --no-image` | Bold tone → post → publish now |
