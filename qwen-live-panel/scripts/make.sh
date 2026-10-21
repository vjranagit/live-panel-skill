#!/usr/bin/env bash
# make.sh content.json out-dir : validate content -> upstream scaffold (auto layout) -> MP4 + poster.
# Any content problem prints one line starting with "FIX:"; edit content.json and rerun.
set -euo pipefail
SKILL_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTENT=${1:?usage: make.sh content.json out-dir}
OUT=${2:?usage: make.sh content.json out-dir}
CHROME=${CHROME:-$(command -v chromium || command -v chromium-browser || command -v google-chrome || command -v chrome || true)}
[[ -n "$CHROME" ]] || CHROME="$HOME/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome"
fail() { echo "FIX: $*" >&2; exit 2; }
for b in python3 ffmpeg ffprobe; do command -v "$b" >/dev/null || fail "install $b"; done
test -x "$CHROME" || fail "set CHROME to an installed Chromium binary and rerun"
mkdir -p "$OUT"

# 1. validate content, build the upstream spec (content only; layout is done by scaffold.py)
python3 - "$CONTENT" "$OUT/spec.json" <<'PY'
import json, re, sys
def fix(msg): sys.exit("FIX: " + msg)
try:
    c = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception as e:
    fix(f"content is not valid JSON ({e}); copy templates/content.json and edit only the text")
def text(v, where, n):
    if not isinstance(v, str) or not v.strip(): fix(f"{where} must be a non-empty string")
    if len(v) > n: fix(f"{where} '{v}' has {len(v)} chars; max {n}")
    return v
def only(d, keys, where):
    if not isinstance(d, dict): fix(f"{where} must be an object")
    extra = set(d) - set(keys)
    if extra: fix(f"{where} has unknown key(s) {sorted(extra)}; allowed: {list(keys)} (no x/y/colors: layout is automatic)")
only(c, ["title", "titlebar", "flow", "side", "counters", "note"], "content")
for k in ("title", "titlebar", "flow", "side", "counters", "note"):
    if k not in c: fix(f"missing '{k}'; keep every key of templates/content.json")
text(c["title"], "title", 40); text(c["titlebar"], "titlebar", 30); text(c["note"], "note", 70)
if "illustrative" not in c["note"].lower(): fix("note must say the numbers are illustrative")
flow = c["flow"]
if not isinstance(flow, list) or not 3 <= len(flow) <= 5:
    fix("flow must be a list of 3-5 rows (top to bottom); merge or drop rows")
rows, logs = [], 0
for r, row in enumerate(flow):
    if not isinstance(row, list) or not 1 <= len(row) <= 3:
        fix(f"flow row {r} must be a list of 1-3 units; move extra units to another row")
    boxes = []
    for u in row:
        only(u, ["name", "detail", "gauge", "log", "alert"], f"flow row {r} unit")
        name = text(u.get("name"), f"flow row {r} name", 11)
        box = {"name": name, "lines": [text(u.get("detail"), f"'{name}' detail", 16)]}
        if "alert" in u:
            if u["alert"] is not True: fix(f"'{name}' alert must be true or left out")
            box["color"] = "rd"
        lg = u.get("log")
        if lg is not None:
            if not isinstance(lg, list) or not 1 <= len(lg) <= 3: fix(f"'{name}' log must be a list of 1-3 short event lines")
            lg = [text(m, f"'{name}' log line", 34) for m in lg]
            logs += 1
        if "gauge" in u:
            vals, s = [0.34, 0.52, 0.67, 0.86, 0.58, 0.41], 2 * sum("gauge" in b for b in sum(rows, []) + boxes)
            box["gauge"] = {"label": text(u["gauge"], f"'{name}' gauge", 6), "values": vals[s % 6:] + vals[:s % 6],
                            "threshold": 0.8, "above": "high", "below": "ok", "bad": "above", "log": lg or [name.lower()]}
        elif lg:
            box["lane"] = {"busy": "running", "done": ["done"], "log": lg}
        boxes.append(box)
    rows.append(boxes)
if max(len(r) for r in rows) < 2:
    fix("every row has one unit = a linear chain; put parallel parts (cells, branches, workers) side by side in one row")
if logs < 2: fix("give at least 2 units a 'log' list of topic events (not 'ok')")
side = c["side"]
only(side, ["name", "items"], "side")
items = side.get("items")
if not isinstance(items, list) or not 2 <= len(items) <= 4: fix("side.items must list 2-4 triggers (alarms, stops, retries, rework, loops back)")
rail_items = []
for it in items:
    only(it, ["name", "row", "advice"], "side item")
    nm = text(it.get("name"), "side item name", 20)
    if not isinstance(it.get("row"), int) or not 0 <= it["row"] < len(rows):
        fix(f"side item '{nm}' row must be a flow row index 0-{len(rows)-1} (the row it hits)")
    adv = it.get("advice")
    if not isinstance(adv, list) or len(adv) != 2: fix(f"side item '{nm}' advice must be exactly 2 short lines")
    rail_items.append({"name": nm, "row": it["row"], "adv": [text(a, f"'{nm}' advice", 20) for a in adv]})
counters = c["counters"]
if not isinstance(counters, list) or not 1 <= len(counters) <= 3: fix("counters must list 1-3 topic metrics")
cnt = []
for i, k in enumerate(counters):
    only(k, ["label", "start", "rate"], "counter")
    lab = text(k.get("label"), "counter label", 16)
    for f in ("start", "rate"):
        if not isinstance(k.get(f), (int, float)) or k[f] < 0: fix(f"counter '{lab}' {f} must be a number >= 0")
    cnt.append({"id": f"k{i}", "label": lab, "start": k["start"], "rate": k["rate"]})
spec = {"theme": "terminal-dark", "canvas": "4:5", "lang": "en", "title": c["title"], "titlebar": c["titlebar"],
        "rows": rows, "rail": {"name": text(side.get("name"), "side name", 11), "side": "left",
                               "onText": "active", "offText": "standby", "items": rail_items},
        "counters": cnt, "log": {"title": "event log · simulated", "rows": 4}, "note": c["note"]}
json.dump(spec, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False, indent=1)
PY

# 2. auto layout; any scaffold warning (content does not fit) is a failure
python3 "$SKILL_ROOT/scripts/scaffold.py" --spec "$OUT/spec.json" --out "$OUT/config.json" 2>"$OUT/scaffold.err" >/dev/null
if grep -q . "$OUT/scaffold.err"; then fail "$(head -n1 "$OUT/scaffold.err") (fewer rows/units/log lines)"; fi

# 3. detect wrapped/clipped text in the laid-out config; neutral wording for the trigger rail log
python3 - "$OUT/spec.json" "$OUT/config.json" <<'PY'
import json, sys
spec, cfg = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
CH = 12.6  # px per glyph at the dark theme's 21 px monospace
boxes = [e for e in cfg["elements"] if e["type"] == "box"][1:]  # [0] is the side rail
for row in spec["rows"]:
    for b in row:
        e = boxes.pop(0)
        shown = {l.get("t") for l in e["lines"] if isinstance(l, dict)}
        for s in (b["name"], b["lines"][0]):
            if s not in shown:
                fix = int((e["w"] - 34) / CH)
                sys.exit(f"FIX: '{s}' wraps in its box; max {fix} chars in this row (or move a unit to another row)")
rail = cfg["machines"]["rail"]
for it, src in zip(rail["items"], spec["rail"]["items"]):
    for got, want in [(it["name"], src["name"])] + list(zip(it["adv"], src["adv"])):
        if got != want:
            sys.exit(f"FIX: side text '{want}' is clipped; max {len(got) - 1} chars")
for m in cfg["machines"].values():
    lg = m.get("log") or {}
    if lg.get("who", "").endswith("…"):
        sys.exit(f"FIX: name '{lg['who'][:-1]}…' is clipped in the event log; max {len(lg['who']) - 1} chars")
    for msg in [x[0] if isinstance(x, list) else x for x in lg.get("msgs", [])]:
        if msg.endswith("…"):
            sys.exit(f"FIX: log line '{msg}' is clipped; max {len(msg) - 1} chars")
cols = next(e for e in cfg["elements"] if e["type"] == "log")["cols"]
longest = max(len(it["name"]) for it in rail["items"])
for k, word in (("start", "raised"), ("end", "cleared")):  # scaffold's default "woken"/"done, back on call" reads oddly for alarms
    m = "{name} · " + word
    rail["log"][k]["m"] = m if (longest + len(m) - 6) * CH <= cols[3]["x"] - cols[2]["x"] - 16 else "{name}"
json.dump(cfg, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False)
PY

# 4. render, poster, frame check (overlap/clip detector), output probe
env -u DISPLAY -u WAYLAND_DISPLAY python3 "$SKILL_ROOT/scripts/render.py" --chrome "$CHROME" --config "$OUT/config.json" --out "$OUT/live-panel.mp4" --html-out "$OUT/live-panel.html" >"$OUT/render.log" 2>&1 || fail "render failed; see $OUT/render.log"
ffmpeg -y -loglevel error -ss 3 -i "$OUT/live-panel.mp4" -frames:v 1 "$OUT/poster.png"
env -u DISPLAY -u WAYLAND_DISPLAY python3 "$SKILL_ROOT/scripts/check_frames.py" --config "$OUT/config.json" --out-dir "$OUT/checks" --repeat --chrome "$CHROME" >"$OUT/checks.log" 2>&1 \
  || fail "frame check found overlap/clipping ($(grep -m1 -v '^checked' "$OUT/checks.log" | cut -c1-120)); shorten text or use fewer units"
python3 - "$OUT" <<'PY'
import json, os, subprocess, sys
p = sys.argv[1]; mp4 = p + "/live-panel.mp4"; png = p + "/poster.png"
assert os.path.getsize(mp4) > 1000 and os.path.getsize(png) > 1000
w, h = map(int, subprocess.check_output(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height", "-of", "csv=s=x:p=0", mp4], text=True).strip().split("x"))
print(json.dumps({"ok": True, "mp4": os.path.abspath(mp4), "poster": os.path.abspath(png), "width": w, "height": h}))
PY
