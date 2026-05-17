---
name: sketch-explainer
description: Generates whiteboard-style sketch explainer diagrams for any topic — technical or non-technical. Automatically selects the best diagram format (swim lanes, flowchart, linear steps, grid/matrix, wheel/radial, or timeline) based on the topic's natural structure. Use this skill when the user wants to explain a concept visually in a hand-drawn whiteboard style, asks for an "Excalidraw diagram", wants to "sketch how X works", needs a visual explainer for any topic, or wants diagram prompts for AI image tools (Midjourney, DALL-E, Excalidraw AI). Always trigger for: "sketch explainer for X", "make a diagram of X", "whiteboard-style explainer", "how does X work diagram", or any request for a visual layered breakdown in a simple illustrated style.
---

# Sketch Explainer

Turn any topic into two things: a **structured diagram spec** and an **AI image prompt**, always in the Excalidraw whiteboard aesthetic — Virgil handwriting font, pastel fills, emoji icon boxes, clean white background, hand-drawn feel.

What changes between topics is the **layout format**. A step-by-step skill becomes Linear Steps. A layered protocol becomes Swim Lanes. A decision tree becomes a Flowchart. The colors and whiteboard style never change.

## Step 1: Choose the Right Format

Read the topic and pick the format that best reveals its natural structure. Ask yourself: what *shape* does this topic have?

| If the topic has… | Use |
|---|---|
| Parallel layers or simultaneous system tiers | **Swim Lanes** |
| Decisions, branches, or "if X then Y" logic | **Flowchart** |
| A strict numbered sequence (tutorial, how-to) | **Linear Steps** |
| Two dimensions to compare or cross-reference | **Grid / Matrix** |
| A repeating cycle or central concept + attributes | **Wheel / Radial** |
| Chronological phases or evolution over time | **Timeline** |
| A visible surface and hidden depth beneath | **Iceberg** |

State the chosen format at the top of your output: `**Format: [Name]**`

Then read the matching reference file for its spec and prompt template:

- `references/swim-lanes.md` — layered systems, protocol stacks, multi-stakeholder processes
- `references/flowchart.md` — decisions, troubleshooting, conditional logic
- `references/linear-steps.md` — numbered sequences, tutorials, how-to guides
- `references/grid-matrix.md` — comparisons, pros/cons, 2×2 frameworks
- `references/wheel-radial.md` — cycles, feedback loops, central concept + attributes
- `references/timeline.md` — history, project phases, chronological progression
- `references/iceberg.md` — visible vs. hidden, surface symptoms vs. root causes, "more than meets the eye"

## Step 2: Build the Content

Following the reference file's structure, identify the key components of the topic (layers, steps, nodes, cells, segments) and populate them with:
- **Labels** — bold uppercase, ≤4 words
- **Boxes/Nodes** — emoji + short label (≤3 words each)
- **Taglines** — one plain-English sentence per element, under 15 words

## Step 3: Write the Output

Produce two clearly separated sections following the reference file's output format:

**Part 1 — Diagram Spec:** The structured breakdown of every element in the chosen format.

**Part 2 — AI Image Prompt:** A single paragraph (150–250 words) describing the full image. Always end with the universal style block from the reference file.

## Step 4: Generate the Image

After writing the output, invoke the `image-generator` skill using the Skill tool:

```
skill: image-generator
args:
  topic-slug: <topic-slug>
  prompt: <full Part 2 AI Image Prompt>
```

The image-generator skill handles saving the prompt, calling the API, and returning the saved image path.

Tell the user the saved image path when done.

---

## Universal Style Rules (never change these)

| Property | Value |
|---|---|
| Font | Virgil (Excalidraw handwriting) |
| Background | Clean white |
| Mint | `#d0f0c0` |
| Gold | `#fff3cd` |
| Orange | `#ffe0b2` |
| Blue | `#dce8f5` |
| Lavender | `#f3e8fd` |
| Effect | Slight hand-drawn border on all shapes |
| No | Gradients · shadows · photorealism |
| Icons | Simple flat emoji, one per box/node |

Cycle through the color palette for the structural elements of your chosen format (lanes, steps, nodes, cells, segments) — mint first, then gold, orange, blue, lavender, repeat.
