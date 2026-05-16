# Format: Flowchart

## When to Use

The topic involves decisions, branching paths, conditional logic, or troubleshooting. The natural question is "what happens *if*?" — not "what layer is this?"

Best for: decision trees, troubleshooting guides, "should I X?", approval processes, error handling flows, eligibility checks, signup or onboarding logic.

**Key signal:** You can describe the topic using "if… then…" or "it depends on…" sentences.

## Structure

- Top-to-bottom flow, 4–8 nodes total (keep it readable)
- **Start node:** Rounded rectangle, mint fill, label "START" or the entry condition
- **Action nodes:** Rectangles with pastel fill — one emoji + short action label
- **Decision nodes:** Diamond shapes, orange fill — a yes/no question, ≤6 words
- **End nodes:** Rounded rectangle, lavender fill — the outcome or result
- Arrows connect nodes; Yes/No branches label the two exits from every diamond
- Colors cycle mint → gold → orange (decisions) → blue → lavender (endings)

## Part 1: Diagram Spec Format

```
# Title Emoji

[START] 🟢 Starting Point · mint
↓
[ACTION] emoji Action Label · gold
↓
[DECISION] ❓ Yes/No Question? · orange
├─ YES → [ACTION] emoji Label · blue
└─ NO  → [ACTION] emoji Label · blue
         ↓
      [END] ✅ Outcome · lavender
```

Use indentation to show branching. List every node with its type tag [START / ACTION / DECISION / END], its emoji, label, and color.

## Part 2: AI Image Prompt — Style Block

End the prompt with:

> Excalidraw sketch style, Virgil handwriting font, top-to-bottom flowchart layout, rounded rectangle nodes for actions and endpoints with pastel fills, diamond-shaped nodes for decisions with orange fill, labeled arrows (Yes/No) branching from each decision, hand-drawn connector lines with arrowheads, clean white background, simple flat emoji icons inside each node, slight hand-drawn border effect, no gradients, no shadows, no photorealism.

## Example Prompt Structure

"A whiteboard-style flowchart titled '[Title]' in Virgil handwriting font on a clean white background. Top-to-bottom layout. Start node (mint, rounded rectangle): '[emoji] [label]'. Action node (gold): '[emoji] [label]'. Decision diamond (orange): '[question]?' with YES path leading to '[emoji] [label]' (blue) and NO path leading to '[emoji] [label]' (blue). End node (lavender): '[emoji] [outcome]'. [Style block above.]"
