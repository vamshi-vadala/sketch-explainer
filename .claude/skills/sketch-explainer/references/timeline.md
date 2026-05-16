# Format: Timeline

## When to Use

The topic has a chronological progression — events, phases, or milestones that unfold over time. The natural question is "what happened when?" or "how did this evolve?"

Best for: history of X, evolution of a technology, project phases, "from invention to today" narratives, product roadmaps, life cycles, "before and after" stories with multiple stages.

**Key signal:** You can assign a date, era, or phase name to each element, and earlier things cause or lead to later things.

## Structure

- Horizontal axis (a bold hand-drawn line), left = earliest/start, right = latest/present
- 4–7 milestones marked with a circle/dot on the line
- Milestones alternate above and below the axis to avoid crowding
- Each milestone: dot on axis + vertical stem + rounded rectangle card
- Card contains: date/era label (small, top) + emoji icon + bold milestone name + one-line note
- Cards cycle through palette left-to-right: mint → gold → orange → blue → lavender

## Part 1: Diagram Spec Format

```
# Title Emoji

AXIS: [Start Era/Date] ──────────────────────► [End Era/Date]

Milestones (left to right):
① [Era/Date] emoji **Milestone Name** · color (above/below)
  _one-line note_

② [Era/Date] emoji **Milestone Name** · color (above/below)
  _one-line note_
```

Alternate above/below placement: odd milestones above the line, even below (or whatever avoids overlap).

## Part 2: AI Image Prompt — Style Block

End the prompt with:

> Excalidraw sketch style, Virgil handwriting font, horizontal timeline with a bold hand-drawn axis line running left to right, milestone markers as small filled circles on the line connected by short vertical stems to rounded rectangle annotation cards, cards alternating above and below the axis line, each card contains a small era/date label, emoji icon, bold milestone name, and brief italic note, cards use pastel fill colors cycling through the palette, clean white background, slight hand-drawn border effect on all cards, no gradients, no shadows, no photorealism, wide landscape format.

## Example Prompt Structure

"A whiteboard-style timeline titled '[Title]' in Virgil handwriting font on a clean white background. Wide landscape format. Bold horizontal axis from '[start]' to '[end]'. [N] milestone markers as filled circles on the line. Milestone 1 (mint #d0f0c0, above): era '[date]', [emoji] '[Milestone Name]', note '[one-line text]'. Milestone 2 (gold #fff3cd, below): era '[date]', [emoji] '[Milestone Name]'… [Style block above.]"
