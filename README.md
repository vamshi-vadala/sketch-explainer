# Sketch Explainer — Claude Code Skill

A Claude Code skill that turns any topic into a whiteboard-style explainer diagram and AI image prompt.

## What it does

Give it a topic, and it automatically:
1. Chooses the best diagram format based on the topic's natural structure
2. Produces a structured **Diagram Spec** — every lane, step, node, or cell
3. Produces an **AI Image Prompt** ready to paste into Midjourney, DALL-E, or Excalidraw AI
4. Optionally generates the image directly using the Gemini API

## Diagram Formats

| Format | Best for |
|---|---|
| **Swim Lanes** | Layered systems, protocol stacks (DNS, HTTPS, JWT) |
| **Flowchart** | Decisions, branching logic, troubleshooting |
| **Linear Steps** | How-to guides, tutorials, step-by-step skills |
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

## Image Generation

The skill can generate images automatically using the Gemini API (`gemini-3.1-flash-image-preview`).

**Setup:**
1. Add your Gemini API key to `.claude/skills/sketch-explainer/config.env`
2. Run the generation script after producing a prompt:

```powershell
& ".claude\skills\sketch-explainer\scripts\generate_image.ps1" -TopicSlug "your-topic" -PromptFile "path\to\prompt.txt"
```

> Requires billing enabled on your Google AI account for image generation.

## Example Topics

- `how JWT authentication works` → Swim Lanes
- `how to crack a joke on stage` → Linear Steps
- `wealth creation` → Iceberg
- `should I use microservices` → Flowchart
- `the water cycle` → Wheel / Radial
- `history of the internet` → Timeline

## Reference Image

The target style is based on this "How HTTPS Works" explainer:

![Reference](test/image.png)
