---
name: qwen-live-panel
description: Create a looping animated system panel (MP4 + poster PNG) from a small JSON brief. Use for animated architecture, process, plant, or monitoring visuals.
---
# Qwen live panel
You write CONTENT only; the script does all layout (no x/y, sizes, colors).
1. Copy `templates/content.json` (a filled example) to `<content-file>` and replace every text with your topic; keep the same keys and shape.
2. `flow` = rows top to bottom (3-5) = the main forward path. Put parallel parts (cells, stations, workers, branches) side by side in one row (1-3 units); at least one row needs 2+ units.
3. A unit: `name` (≤11 chars) + `detail` (≤16 chars). Optional: `gauge` (≤6 chars, e.g. "fill") for anything holding a quantity (buffer, queue, tank, store); `log`: 1-3 topic events it reports (≤34 chars); `alert: true` for a fault, reject, or repair unit (drawn red).
4. Stops, alarms, retries, rework, and loops back are `side.items` (2-4), never flow rows: `side.name` ≤11 chars; item `name` ≤20 chars, `row` = index of the flow row it hits (top row = 0), `advice` = 2 lines ≤20 chars.
5. `counters`: 1-3 real topic metrics (`label`, `start`, per-second `rate`). Keep "illustrative" in `note`.
6. Run `scripts/make.sh <content-file> <out-dir>`. If it prints `FIX: ...`, do exactly that and rerun. Success prints `{"ok": true, ...}`.
7. Open `<out-dir>/poster.png` and check that labels are readable.
