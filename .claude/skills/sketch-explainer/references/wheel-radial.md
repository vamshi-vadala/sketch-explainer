# Format: Wheel / Radial

## When to Use

The topic is a repeating cycle, a feedback loop, or a central concept surrounded by multiple related attributes or components that all connect back to the center.

Best for: natural cycles (water cycle, carbon cycle, seasons), agile/process loops (plan→build→test→release), core values or principles radiating from a central idea, anatomy of something (parts of X), continuous improvement cycles.

**Key signal:** You can describe the topic as "it starts here, loops back, and repeats" OR as "at the center is X, and surrounding it are A, B, C, D…"

## Two Sub-types

**Cycle wheel:** Nodes arranged in a circle, curved arrows between them showing the direction of flow. Best for processes that loop (water cycle, feedback loops, agile sprints).

**Radial/hub-and-spoke:** Central hub circle with spokes radiating outward to labeled nodes. Best for "anatomy of X" or "pillars of X" topics where all elements connect back to a center.

Choose whichever fits — state it: `Sub-type: Cycle` or `Sub-type: Hub & Spoke`

## Structure

- **Center/hub:** Large circle, orange fill (`#ffe0b2`), bold topic label + emoji
- **Outer nodes:** 4–8 rounded rectangles at the ends of spokes, cycling mint → gold → blue → lavender
- **Spokes:** Thin hand-drawn lines from center to each node
- **Cycle arrows (cycle sub-type):** Curved arrows between adjacent nodes, showing clockwise flow direction
- Each outer node: emoji + bold label + optional 1-line note below

## Part 1: Diagram Spec Format

```
# Title Emoji
Sub-type: [Cycle / Hub & Spoke]

CENTER: emoji **Core Concept** · orange

NODES (clockwise from top):
① emoji **Label** · color — _brief note_
② emoji **Label** · color — _brief note_
③ emoji **Label** · color — _brief note_
④ emoji **Label** · color — _brief note_
[Cycle arrows: ①→②→③→④→① for cycle sub-type]
```

## Part 2: AI Image Prompt — Style Block

End the prompt with:

> Excalidraw sketch style, Virgil handwriting font, radial diagram with a large central circle hub in orange fill, thin hand-drawn spokes radiating outward to rounded rectangle nodes in pastel fills cycling through the palette, emoji icon and bold label inside each outer node, [curved clockwise arrows between nodes for cycle sub-type], clean white background, simple flat emoji icons, slight hand-drawn border effect on hub and nodes, no gradients, no shadows, no photorealism.

## Example Prompt Structure

"A whiteboard-style radial diagram titled '[Title]' in Virgil handwriting font on a clean white background. Central orange circle hub labeled '[emoji] [Core Concept]'. [N] spokes radiating outward to rounded rectangle nodes: Node 1 (mint #d0f0c0) '[emoji] [Label]' with note '[brief note]', Node 2 (gold #fff3cd) '[emoji] [Label]'… [For cycle: curved arrows between nodes in clockwise order.] [Style block above.]"
