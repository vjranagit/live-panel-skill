# Qwen live panel

A weak-model wrapper for local LLMs, tuned on qwen3.8-27b, that turns a short JSON brief into an animated live-panel diagram and poster. The renderer and assets are included in this fork.

## Install

Install Python 3, FFmpeg (`ffmpeg` and `ffprobe`), and Chromium/Chrome, then run:

```sh
./scripts/setup.sh
```

If the browser is not on `PATH`, set `CHROME` to its executable path when rendering.

## Use

Copy `templates/content.json`, replace its text with your topic, and render it:

```sh
./scripts/make.sh templates/content.json output
```

Prompt pattern: “Use the qwen-live-panel skill to make a clear animated panel about [topic]. Save the content JSON, MP4, and poster in [output directory].”

## Results

Best version: qwen-live-panel-v2. The AI critic scored attempts 1, 2, and 3 at 5.3, 6.0, and 5.5 out of 10 respectively; attempt 2 is the retained best. These scores are an AI critic's assessment, not benchmarks.

Example: [`examples/live-panel.png`](examples/live-panel.png), generated from [`examples/content.json`](examples/content.json).

The upstream repository is MIT licensed (see the root `LICENSE` and `NOTICE`); upstream licenses for included font and icon assets are retained in their asset directories.
