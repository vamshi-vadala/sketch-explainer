# Format: Linear Steps

## When to Use

The topic is a strict numbered sequence — each step must happen before the next begins. The natural question is "what do I do first, second, third?"

Best for: tutorials, how-to guides, recipes, skill walkthroughs, onboarding processes, any "step-by-step" topic. This is the right format when the order is non-negotiable.

**Key signal:** You can write the topic as "Step 1… Step 2… Step 3…" and the meaning breaks if you reorder them.

## Structure

- 3–7 numbered step cards
- **≤5 steps:** Horizontal chain, cards connected left-to-right by arrows
- **6–7 steps:** Two-row layout (row 1: steps 1–4, row 2: steps 5–7, connected with a downward turn arrow)
- Each card contains: large number circle (top-left) + emoji icon + step title (bold) + one-line description
- Cards are rounded rectangles, each gets one color from the palette (cycle mint → gold → orange → blue → lavender → mint)
- Right-pointing arrows between cards; downward arrow at row break if two-row layout

## Part 1: Diagram Spec Format

```
# Title Emoji

① emoji **Step Name** · color
  _one-line description_
→
② emoji **Step Name** · color
  _one-line description_
→
③ emoji **Step Name** · color
  _one-line description_
```

List every step with its number, emoji, bold title, color, and one-line description.

## Part 2: AI Image Prompt — Style Block

End the prompt with:

> Excalidraw sketch style, Virgil handwriting font, horizontal chain of numbered step cards connected by right-pointing arrows, large circled number in the top-left corner of each card, emoji icon prominently inside each card, bold step title below the icon, short italic description below the title, rounded rectangle cards with pastel fill colors cycling through the palette, slight hand-drawn border effect on each card, clean white background, no gradients, no shadows, no photorealism, wide landscape format.

## Example Prompt Structure

"A whiteboard-style step-by-step explainer titled '[Title]' in Virgil handwriting font on a clean white background. Wide landscape format. [N] numbered step cards in a horizontal chain connected by right-pointing arrows. Card 1 (mint #d0f0c0): circled ①, [emoji] icon, bold '[Step Name]', description '[one-line text]'. Card 2 (gold #fff3cd): circled ②, [emoji], bold '[Step Name]', '[description]'. [Continue for each step.] [Style block above.]"
