---
name: linkedin-post-creator
description: Publishes or schedules LinkedIn posts via the Zernio API. Supports text-only posts, posts with images, and scheduled publishing. Use this skill whenever the user wants to publish a post to LinkedIn, post with an image, schedule a LinkedIn post, or run a test post. Trigger on: "post to LinkedIn", "publish LinkedIn post", "schedule LinkedIn post", "test post", "post with image", or any request to actually send content to LinkedIn.
---

# LinkedIn Post Creator

Publish or schedule LinkedIn posts via the Zernio API. Three modes available:

- **Text post** — publish a text-only post immediately
- **Image post** — publish a post with an image immediately
- **Scheduled post** — schedule a post (text or image) for a future time

## Step 1: Read Configuration

Load the API key from `.claude/skills/config.env` (the shared skills config file). Look for `ZERNIO_API_KEY`.

## Step 2: Get LinkedIn Account ID

If the user hasn't provided a LinkedIn account ID, run the list accounts script to find it:

```powershell
& "<base-dir>/scripts/list_accounts.ps1"
```

This lists all connected Zernio accounts and shows the LinkedIn one. Use the `_id` field as the `accountId` for posting. If multiple LinkedIn accounts are found, ask the user which to use.

## Step 3: Determine Post Mode

Ask the user (or infer from their request) which mode they want:

| Mode | When to use |
|---|---|
| Text post now | User wants to publish immediately, no image |
| Image post now (URL) | User provides a public image URL |
| Image post now (local file) | User has a locally generated image file |
| Scheduled | User specifies a date/time |

**Local images**: pass `-ImagePath` with the local file path. The script will automatically commit the image to `assets/linkedin/` in the GitHub repo and use the raw URL — no manual hosting step needed.

## Step 4: Run the Post Script

```powershell
# Text post (publish immediately)
& "<base-dir>/scripts/post_linkedin.ps1" -Content "<text>"

# Image post — public URL
& "<base-dir>/scripts/post_linkedin.ps1" -Content "<text>" -ImageUrl "<url>"

# Image post — local file (auto-published to GitHub)
& "<base-dir>/scripts/post_linkedin.ps1" -Content "<text>" -ImagePath "C:\full\path\to\image.png"

# Scheduled post
& "<base-dir>/scripts/post_linkedin.ps1" -Content "<text>" -ScheduledFor "2026-05-20T14:00:00" -Timezone "Asia/Kolkata"

# Scheduled image post — local file
& "<base-dir>/scripts/post_linkedin.ps1" -Content "<text>" -ImagePath "C:\path\to\image.png" -ScheduledFor "2026-05-20T14:00:00" -Timezone "Asia/Kolkata"
```

## Step 5: Report Result

On success, report the post ID returned by Zernio and confirm whether the post was published immediately or scheduled.

On failure, show the error clearly so the user can act on it.

## Key LinkedIn Rules (from Zernio docs)

- Max 3,000 characters per post
- Images: JPEG or PNG, max 8 MB, up to 20 per post
- For public image URLs: must be accessible without auth — Wikipedia, Google Drive, and authenticated sources fail. Use Unsplash, Cloudinary, S3, or raw GitHub (`raw.githubusercontent.com`)
- For local images: use `-ImagePath` — the script commits to GitHub automatically and constructs the raw URL
- Do NOT mix images and videos in the same post
- If content includes a URL, place it in `firstComment` to avoid LinkedIn reach suppression (40–50% penalty)
- LinkedIn rejects duplicate content — identical text cannot be posted twice
- First ~210 characters are visible before "see more"

## Requirements

- `ZERNIO_API_KEY` in `.claude/skills/config.env`
- `LINKEDIN_ACCOUNT_ID` in `.claude/skills/config.env` (run `list_accounts.ps1` once to find it)
- LinkedIn account connected in Zernio (Settings → Connected Accounts)

These are stored in the shared gitignored config file and never committed to the repo.
