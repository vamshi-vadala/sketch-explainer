# Format: Swim Lanes

## When to Use

The topic has multiple simultaneous layers, tiers, or stakeholder groups that operate in parallel. The natural question is "what's happening at each level?" — not "what happens next?"

Best for: protocol stacks (HTTP, DNS, TCP/IP), multi-party systems (client/server/database), "how does X work" topics with distinct abstraction levels, supply chains, multi-team workflows.

**Key signal:** You can describe the topic as "at the top level… and underneath that… and beneath that…"

## Structure

- 3–6 horizontal rows stacked vertically
- Each row = one layer, tier, or stakeholder group
- Rows flow top-to-bottom: most visible to user at top → deepest infrastructure at bottom
- Within each row: 3–5 pill boxes flow left-to-right showing a mini-sequence or related set
- Bold uppercase label on the left of each row
- One-line tagline below the boxes in each row
- Each row gets one color from the palette (cycle mint → gold → orange → blue → lavender)

## Part 1: Diagram Spec Format

```
# Title Emoji

**LABEL** · color
→ emoji Box  ·  emoji Box  ·  emoji Box  ·  emoji Box
  _tagline sentence_

**LABEL** · color
→ emoji Box  ·  emoji Box  ·  emoji Box
  _tagline sentence_
```

## Part 2: AI Image Prompt — Style Block

End the prompt with:

> Excalidraw sketch style, Virgil handwriting font, horizontal swim lanes stacked vertically, bold uppercase row labels flush to left margin, rounded rectangle pill boxes with emoji icons flowing left to right within each lane, one-line italic tagline below each lane's boxes, pastel fill backgrounds per lane, slight hand-drawn border effect on all boxes, clean white background, no gradients, no shadows, no photorealism, wide landscape format.

## Example Prompt Structure

"A whiteboard-style explainer diagram titled '[Title]' in Virgil handwriting font on a clean white background. Wide landscape format. [N] horizontal swim lanes stacked vertically. Lane 1 (mint #d0f0c0, '[LABEL]'): boxes [emoji Box · emoji Box · emoji Box], tagline: '[tagline].' Lane 2 (gold #fff3cd, '[LABEL]'): ... [continue for each lane]. [Style block above.]"
