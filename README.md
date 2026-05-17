# AI Catalyst — Claude Code Skills

A collection of Claude Code skills for content creation, visual explanation, and social media publishing.

## Skills

### sketch-explainer
Turns any topic into a whiteboard-style explainer diagram and AI-generated image. Chooses the best diagram format automatically (iceberg, flowchart, swim lanes, etc.), produces a structured spec and image prompt, then calls the image-generator skill to render it.

### image-generator
Standalone image generation skill. Accepts a topic slug and prompt, calls the Gemini API, and saves the image to disk. Can be called independently by any skill or agent.

### linkedin-post
Researches any topic on the internet first, then writes a professional LinkedIn post with a strong hook, insightful body, hyphen bullets, proper spacing, and up to 3 hashtags. Never writes before researching.

### linkedin-post-creator
Publishes and schedules LinkedIn posts via the Zernio API. Supports text-only posts, image posts, and scheduled publishing. Account ID and API keys are stored in the shared gitignored config — no manual parameters needed.

## Diagram Formats (sketch-explainer)

| Format | Best for |
|---|---|
| **Swim Lanes** | Layered systems, protocol stacks (DNS, HTTPS, JWT) |
| **Flowchart** | Decisions, branching logic, troubleshooting |
| **Linear Steps** | How-to guides, tutorials, step-by-step processes |
| **Grid / Matrix** | Comparisons, pros/cons, 2×2 frameworks |
| **Wheel / Radial** | Cycles, feedback loops, hub + attributes |
| **Timeline** | History, project phases, chronological progression |
| **Iceberg** | Visible vs. hidden, surface symptoms vs. root causes |

## Setup

### 1. Configure API keys

Create `.claude/skills/config.env` — this file is gitignored and never committed:

```
GEMINI_API_KEY=your-gemini-key-here
ZERNIO_API_KEY=your-zernio-key-here
LINKEDIN_ACCOUNT_ID=your-linkedin-account-id-here
```

- **Gemini key**: [aistudio.google.com](https://aistudio.google.com) — requires billing enabled for image generation
- **Zernio key**: [zernio.com](https://zernio.com) → Settings → API Keys
- **LinkedIn account ID**: run `list_accounts.ps1` after connecting LinkedIn in Zernio

### 2. Connect LinkedIn to Zernio

Go to [zernio.com](https://zernio.com) → Settings → Connected Accounts → Add LinkedIn. Then run:

```powershell
& ".claude\skills\linkedin-post-creator\scripts\list_accounts.ps1"
```

Copy the LinkedIn account ID into `config.env`.

### 3. Use the skills

```
/sketch-explainer wealth creation
/sketch-explainer will AI take over humanity

/linkedin-post AI agents replacing jobs
/linkedin-post the future of remote work

/linkedin-post-creator    ← publishes to LinkedIn via Zernio
```

## Example Topics

| Topic | Skill | Format |
|---|---|---|
| `wealth creation` | sketch-explainer | Iceberg |
| `will AI take over humanity` | sketch-explainer | Flowchart |
| `how JWT authentication works` | sketch-explainer | Swim Lanes |
| `AI agents replacing jobs` | linkedin-post | Research → post |
| `post this to LinkedIn now` | linkedin-post-creator | Publish via Zernio |

## File Structure

```
.claude/skills/
  config.env                            ← shared API keys (gitignored, never commit)
  sketch-explainer/
    SKILL.md
    references/                         ← format specs (flowchart, iceberg, etc.)
  image-generator/
    SKILL.md
    scripts/
      generate_image.ps1                ← Gemini API caller
  linkedin-post/
    SKILL.md                            ← research + write LinkedIn posts
  linkedin-post-creator/
    SKILL.md
    scripts/
      list_accounts.ps1                 ← find your LinkedIn account ID
      post_linkedin.ps1                 ← publish or schedule via Zernio
```

## Reference Image

The target whiteboard style is based on this "How HTTPS Works" explainer:

![Reference](test/image.png)
