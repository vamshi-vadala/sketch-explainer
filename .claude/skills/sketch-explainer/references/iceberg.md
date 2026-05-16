# Format: Iceberg

## When to Use

The topic has a clear visible surface layer and multiple deeper hidden layers — the whole point is that most of the complexity, cost, or truth lies beneath what people normally notice.

Best for: technical debt (code vs. hidden mess), organizational culture (behavior vs. beliefs vs. assumptions), mental health (what people show vs. feel vs. carry), AI/ML systems (the chatbot vs. the data, compute, and training beneath), privilege, financial systems, root cause vs. symptom analysis, any "there's more than meets the eye" topic.

**Key signal:** You can describe the topic as "people only see X, but underneath is Y, and even deeper is Z." The contrast between visible and hidden IS the point.

Do not use for step-by-step sequences, comparisons, or cycles — only when surface vs. depth is the core message.

## Structure

- A wavy horizontal line divides the image — the water surface
- **Above water (TIP):** Small area, 1–3 items, mint fill — what everyone sees
- **Below water:** The iceberg body, divided into 3–4 horizontal bands going deeper
  - Band 1 (gold) — just below the surface, slightly aware layer
  - Band 2 (orange) — mid-depth, less visible
  - Band 3 (blue) — deep, rarely acknowledged
  - Band 4 (lavender) — root/core, almost never seen (optional, for deep topics)
- Each band has a bold uppercase label on the left + 2–4 emoji items + one-line tagline
- The iceberg outline is drawn as a single hand-drawn shape; bands are fills within it
- Items grow more fundamental (not just "more") as you go deeper

## Part 1: Diagram Spec Format

```
# Title Emoji

〰️〰️〰️ WATER SURFACE 〰️〰️〰️

ABOVE WATER · mint — What people see:
→ emoji Item  ·  emoji Item
  _tagline: the visible tip everyone knows_

━━━━━━━━━ BELOW THE SURFACE ━━━━━━━━━

**LAYER LABEL** · gold
→ emoji Item  ·  emoji Item  ·  emoji Item
  _tagline: what lies just beneath awareness_

**LAYER LABEL** · orange
→ emoji Item  ·  emoji Item  ·  emoji Item
  _tagline: deeper, less visible reality_

**LAYER LABEL** · blue
→ emoji Item  ·  emoji Item
  _tagline: root causes, rarely examined_

**ROOT LAYER** · lavender  ← (optional, for very deep topics)
→ emoji Core Truth
  _tagline: the foundational truth almost no one sees_
```

## Part 2: AI Image Prompt — Style Block

End the prompt with:

> Excalidraw sketch style, Virgil handwriting font, iceberg diagram with a wavy hand-drawn horizontal water surface line dividing the image, small visible tip above the waterline in mint fill with emoji items, iceberg body below the waterline as a wide triangular shape divided into horizontal bands with pastel fills cycling gold → orange → blue → lavender from shallow to deep, bold uppercase band labels on the left of each layer, emoji icons and short labels inside each band, one-line italic tagline below items in each band, slight hand-drawn border effect on the iceberg outline and all elements, clean white background, no gradients, no shadows, no photorealism, portrait or square format.

## Example Prompt Structure

"A whiteboard-style iceberg diagram titled '[Title]' in Virgil handwriting font on a clean white background. A wavy hand-drawn horizontal line represents the water surface. Above the waterline: small mint-filled area labeled '[ABOVE LABEL]' with items [emoji Item · emoji Item], tagline '[visible tip tagline]'. Below the waterline: the iceberg body as a wide triangular shape divided into [N] horizontal bands. Band 1 (gold #fff3cd, '[LAYER LABEL]'): items [emoji · emoji · emoji], tagline '[just-below tagline]'. Band 2 (orange #ffe0b2, '[LAYER LABEL]'): items [emoji · emoji], tagline '[deeper tagline]'. Band 3 (blue #dce8f5, '[LAYER LABEL]'): items [emoji · emoji], tagline '[root tagline]'. [Style block above.]"
