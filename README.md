# Sketch Explainer — Claude Code Skill

A Claude Code skill that turns any topic into a whiteboard-style explainer diagram and AI image, using a two-skill architecture: **sketch-explainer** builds the diagram spec and prompt, **image-generator** produces the image.

## Skills

### sketch-explainer
Chooses the best diagram format for a topic, produces a structured Diagram Spec and AI Image Prompt, then calls the image-generator skill to create the image.

### image-generator
Standalone image generation skill. Accepts a topic slug and prompt, calls the Gemini API, and saves the image to disk. Can be called independently by any skill or agent.

## Diagram Formats

| Format | Best for |
|---|---|
| **Swim Lanes** | Layered systems, protocol stacks (DNS, HTTPS, JWT) |
| **Flowchart** | Decisions, branching logic, troubleshooting |
| **Linear Steps** | How-to guides, tutorials, step-by-step processes |
| **Grid / Matrix** | Comparisons, pros/cons, 2×2 frameworks |
| **Wheel / Radial** | Cycles, feedback loops, hub + attributes |
| **Timeline** | History, project phases, chronological progression |
| **Iceberg** | Visible vs. hidden, surface symptoms vs. root causes |

## Style

All formats use the same Excalidraw whiteboard aesthetic:
- Virgil handwriting font
- Clean white background
- Pastel color palette: Mint · Gold · Orange · Blue · Lavender
- Emoji icon boxes with hand-drawn borders

## Setup

### 1. Add your Gemini API key

Create `.claude/skills/config.env` (shared across all skills — never commit this file):

```
GEMINI_API_KEY=your-key-here
```

Get a key at [aistudio.google.com](https://aistudio.google.com). Image generation requires billing enabled on your Google Cloud project.

### 2. Use the skill

```
/sketch-explainer wealth creation
/sketch-explainer will AI take over humanity
/sketch-explainer how JWT authentication works
```

To generate an image independently:

```
/image-generator
topic-slug: my-topic
prompt: <your full image prompt>
```

## Example Topics

| Topic | Format chosen |
|---|---|
| `how JWT authentication works` | Swim Lanes |
| `how to crack a joke on stage` | Linear Steps |
| `wealth creation` | Iceberg |
| `will AI take over humanity` | Flowchart |
| `the water cycle` | Wheel / Radial |
| `history of the internet` | Timeline |

## File Structure

```
.claude/skills/
  config.env                        ← shared API keys (gitignored, never commit)
  sketch-explainer/
    SKILL.md
    references/                     ← format specs (flowchart, iceberg, etc.)
  image-generator/
    SKILL.md
    scripts/
      generate_image.ps1            ← Gemini API caller (PowerShell, no deps)
```

## Reference Image

The target style is based on this "How HTTPS Works" explainer:

![Reference](test/image.png)
