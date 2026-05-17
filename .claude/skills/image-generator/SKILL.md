---
name: image-generator
description: Generates an AI image from a text prompt using the Gemini API. Use this skill when any other skill or agent needs to produce an image from a prompt. Accepts a topic slug (for the filename) and a full image prompt. Returns the saved image path. Trigger phrases: "generate image", "create image", "run image generator", or when called programmatically by another skill.
---

# Image Generator

Generate an image from a text prompt using the Gemini API and save it to disk.

## Arguments

Arguments are passed as free text. Parse out:
- `topic-slug` — kebab-case label used in the output filename (e.g. `wealth-creation`)
- `prompt` — the full image generation prompt text

If a `prompt-file` path is provided instead of inline prompt text, read the prompt from that file.

## Step 1: Resolve Paths

Derive all paths from the base directory for this skill:

- Prompt file: `<base-dir>/generated-images/<topic-slug>-prompt.txt`
- Script: `<base-dir>/scripts/generate_image.ps1`
- Output: `<base-dir>/generated-images/<topic-slug>-<timestamp>.png`
- API key: `.claude/skills/config.env` (shared across all skills, with skill-local `<base-dir>/config.env` as override)

Create the `generated-images/` directory if it does not exist.

## Step 2: Save Prompt to File

Save the prompt text to:
```
<base-dir>/generated-images/<topic-slug>-prompt.txt
```

## Step 3: Run the Generation Script

```powershell
& "<base-dir>/scripts/generate_image.ps1" -TopicSlug "<topic-slug>" -PromptFile "<base-dir>/generated-images/<topic-slug>-prompt.txt"
```

The script reads `GEMINI_API_KEY` from `<base-dir>/config.env` and saves the image to `<base-dir>/generated-images/<topic-slug>-<timestamp>.png`.

## Step 4: Report the Result

Tell the caller the full saved image path.

If the script fails, report the error clearly so the caller can act on it.

**Requirements:** `GEMINI_API_KEY` must be set in `.claude/skills/config.env` (shared) or `<base-dir>/config.env` (skill-local override). Billing must be enabled on the associated Google Cloud project.
