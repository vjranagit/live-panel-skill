#!/usr/bin/env bash
# Runtime dependencies are system tools; install them with your OS package manager.
set -euo pipefail
for tool in python3 ffmpeg ffprobe; do
  command -v "$tool" >/dev/null || { printf 'Missing required executable: %s\n' "$tool" >&2; exit 1; }
done
python3 - <<'PY'
import shutil
from pathlib import Path
candidates = [shutil.which("chromium"), shutil.which("chromium-browser"), shutil.which("google-chrome"), shutil.which("chrome")]
candidates = [p for p in candidates if p and Path(p).is_file()]
if not candidates:
    raise SystemExit("Missing Chromium/Chrome. Install a Chromium browser and set CHROME=/path/to/chromium.")
print("Runtime dependencies are available.")
PY
