# Format: Grid / Matrix

## When to Use

The topic involves comparison, categorization, or mapping things against two or more dimensions. The natural question is "how do these things compare?" or "where does X fall?"

Best for: pros/cons tables, X vs Y comparisons, feature matrices, 2×2 frameworks (urgency/importance, risk/reward, effort/impact), capability comparisons, option trade-offs.

**Key signal:** You can naturally describe the topic as a table — rows are one thing, columns are another.

## Structure

- 2–4 columns, 2–5 rows (keep cells readable)
- **Column headers:** Top row, blue fill (`#dce8f5`), bold uppercase label
- **Row headers:** Left column, gold fill (`#fff3cd`), bold uppercase label
- **Cells:** Remaining cells, each contains one emoji + ≤5 words; fill cycles mint → lavender → mint alternating by row
- **Corner cell:** Top-left, left blank or contains the diagram title/emoji
- Grid lines are hand-drawn style; cells are rounded-corner rectangles

Special case — **2×2 framework:** Four equal quadrants with axis labels on the edges (e.g., LOW/HIGH on X-axis, LOW/HIGH on Y-axis). Each quadrant gets one color and a bold label + emoji + one-line description.

## Part 1: Diagram Spec Format

Standard grid:
```
# Title Emoji

|            | COL HEADER A | COL HEADER B | COL HEADER C |
|------------|--------------|--------------|--------------|
| ROW 1      | emoji note   | emoji note   | emoji note   |
| ROW 2      | emoji note   | emoji note   | emoji note   |
| ROW 3      | emoji note   | emoji note   | emoji note   |
```

2×2 framework:
```
# Title Emoji

AXES: X = [dimension], Y = [dimension]

TOP-LEFT (mint): emoji **Label** — _description_
TOP-RIGHT (gold): emoji **Label** — _description_
BOTTOM-LEFT (lavender): emoji **Label** — _description_
BOTTOM-RIGHT (orange): emoji **Label** — _description_
```

## Part 2: AI Image Prompt — Style Block

End the prompt with:

> Excalidraw sketch style, Virgil handwriting font, grid table layout with hand-drawn borders, column headers in blue-filled rounded rectangles at the top, row labels in gold-filled cells on the left, content cells with emoji icons and short text in alternating mint and lavender fills, slight hand-drawn border effect on all cells, clean white background, no gradients, no shadows, no photorealism.

## Example Prompt Structure

"A whiteboard-style comparison grid titled '[Title]' in Virgil handwriting font on a clean white background. A [N]-column by [M]-row grid. Column headers (blue #dce8f5): '[A]', '[B]', '[C]'. Row labels (gold #fff3cd): '[Row 1]', '[Row 2]'. Cells alternate mint and lavender fills, each cell contains [emoji] and [≤5-word note]. [Style block above.]"
