# overlay.html contract (what render.js needs)

Start from `templates/starter.html` — it already implements all of this. Break a rule and the export fails or looks wrong.

## Must
1. **Stage**: one `#stage` element, exactly `1080×1920`, `overflow:hidden`. All visuals live inside it. Keep the `fit()` scaling (render.js disables it).
2. **One master timeline**: every animation is a GSAP tween/timeline nested in `master` (`gsap.timeline({paused: !!MODE})`). No CSS `@keyframes`/`transition`, no `setTimeout`/`setInterval`, no `<video>`, no `Math.random()`/`Date.now()` at play time (randomize at build time only). Reason: frames are rendered by seeking `master` — anything not on it won't move or will jitter.
3. **`window.RENDER = { seek: t => { master.time(t); }, ready: true }`** set at the end of `build()`. `seek` must **return nothing** (returning the timeline makes Puppeteer hang).
4. **Render modes** via `?render=`: `preview` → keep `#pv` (backdrop) but remove `#ui`; `1` → remove `#pv` and `#ui` and make `html, body` background **transparent**. Nothing opaque may cover the whole stage.
5. **Loops must be seamless**: infinite `repeat:-1` timelines whose end state equals their start state, so any `duration` works.
6. **Assets**: reference files by relative path inside the job folder (`img/product.png`, `fonts/…`). `gsap.min.js`, `job.js` and the bundled `fonts/LINESeedSansTH_*.otf` are added by render.js — don't copy them yourself. Google Fonts `<link>`s are fine (needs internet at render time). Wait for `document.fonts.ready` before `build()` and measure text after that.
7. **Intentional overflow** (tickers, text running off the edge): put `data-overflow-ok` on the container so the preview's overflow warning ignores it.
8. **Middle band clear**: leave a region where the user's footage shows (y 548–1440). Declare it in `job.json → checks.clearZone` so the verifier can test it.
9. **Top section ≤ top 2/7**: nothing visible (alpha ≥ 32) in y 548–1000 at any time. **Bottom section ≤ lowest 1/4**: nothing visible (alpha ≥ 32) in y 1000–1440 at any time — includes shadows, glows, gradient fades, overshoot of pop-in animations and cursors. render.js checks this automatically (WARN in preview, FAIL on export).

## job.json
```json
{
  "name": "foldy-overlay",
  "duration": 15,
  "fps": 30,
  "previewBackground": "/path/to/a/sample/clip-frame-or-photo.jpg",
  "previewAt": 5.2,
  "checks": {
    "clearZone": { "x": 100, "y": 760, "w": 880, "h": 480 },
    "reveal":   { "x": 540, "y": 1700, "at": 3 }
  }
}
```
- `previewAt`: time (s) shown in the preview PNGs — pick a moment where everything is on screen.
- `checks.clearZone` (required for custom designs): box that must stay fully transparent for the whole clip.
- `checks.topLimit` (optional, default 548 = 2/7 of 1920): bottom edge of the allowed top zone. `checks.bottomLimit` (optional, default 1440 = 3/4): top edge of the allowed bottom zone. Change them only when the user explicitly asks. `checks.bandSplit` (default 1000) decides whether stray content is reported as top or bottom.
- `sheet: true`: for non-overlay sheets (font-compare) — skips the zone checks.
- `checks.reveal` (optional): a point on an element that pops in later — must be transparent before `at` and solid ≥2.5 s after.

## What render.js does for you
- Previews (`-preview.png`, `-preview-transparent.png`), warnings for overflowing text and page errors.
- Deterministic frame-by-frame capture with real alpha.
- **Premultiplies colors + zeroes alpha < 4/255** before encoding → no white streaks at fade edges after CapCut export.
- HEVC-with-alpha `.mov` via Apple VideoToolbox (+ optional ProRes 4444 with `--prores`).
- Verification with Apple's decoder: alpha flag, clear zone transparent all clip, reveal timing, fringe risk.
