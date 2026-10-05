---
name: promo-overlay
description: ออกแบบและสร้างไฟล์ overlay แนวตั้ง 9:16 พื้นหลังใส (.mov สำหรับมือถือ, HEVC + alpha) ไว้ซ้อนบนคลิปที่ถ่ายเอง เพื่อโปรโมทสินค้า บริการ หรือคอร์สเรียน — ดีไซน์ layout, สี, ฟอนต์ และ motion ใหม่ให้เหมาะกับสินค้าแต่ละตัว และยึด CI จากรูป reference ถ้ามีให้มา ใช้ทุกครั้งที่ผู้ใช้ส่งรูปสินค้า/บริการ/รูปโปรโมทคอร์ส แล้วขอ "overlay", "lower third", "แบนเนอร์ซ้อนคลิป", "กรอบคลิปพื้นหลังใส", "ทำ overlay .mov", "แบนเนอร์บน-ล่างคลิปแนวตั้ง", "ตัวซ้อนคลิป Reels/TikTok" แม้จะไม่ได้พูดชื่อ skill นี้ตรง ๆ ก็ตาม
---

# Promo overlay (9:16, transparent, for phones)

Make an animated **transparent overlay .mov** that the user puts on top of their own vertical clip (CapCut / iPhone editors) to sell a product, service or course. **Design it fresh for each product** — layout, colors, fonts, decoration and motion all follow the product and any reference images. Only the technical pipeline is fixed.

Works on **macOS, Windows and Linux (incl. Claude Cowork)** — same output everywhere. Below, `<SKILL>` = the folder containing this SKILL.md (e.g. `~/.claude/skills/promo-overlay` in Claude Code; in Cowork use wherever the skill is mounted).

**One-time setup on a machine** (the first render also does this automatically):
```bash
cd <SKILL>/scripts && npm install && node render.js --setup
```
`--setup` downloads a static FFmpeg for the OS and, if no Chrome/Edge is installed, a headless Chromium. If `<SKILL>` is read-only (Cowork skill mount), first copy the whole folder somewhere writable (`cp -r <SKILL> ~/promo-overlay-skill`) and use that copy as `<SKILL>`. Linux without browser libraries: `npx playwright-core install-deps chromium` (needs sudo/apt).

Files in this skill:
- `references/design-guide.md` — how to read refs into a CI brief, 8 layout patterns and when to use them, Thai font list, motion, safe zones, content rules. **Read it every time.**
- `references/contract.md` — what overlay.html must do so render.js can export it. **Read before writing HTML.**
- `templates/starter.html` — skeleton implementing the contract (hook top + bottom-quarter panel with product image); copy it and design on top.
- `templates/font-compare/` — font-match sheet: renders the hook in ~23 Thai fonts under a crop of the reference headline.
- `templates/card-bottom/` + `references/card-bottom-config.md` — the original approved design, config-driven (use only when the user wants "แบบเดิม" or a quick proven layout).
- `scripts/render.js` — preview + export + verify. `scripts/check_alpha.swift` — verifier.
- `fonts/` — LINE Seed Sans TH (bundled automatically).

## Workflow

1. **Look at every image** the user sent (Read tool). Separate the **product image(s)** (what to sell — content and the picture to show) from **reference images** (how it should look — CI). If it's unclear which is which, ask.
2. **Extract only the important content** — be ruthless (see design-guide §7 "Less is more"). Keep: hook, the ONE strongest offer/price, the product image, brand, CTA (+ one short condition line only if leaving it out would mislead). Drop by default: date ranges, footnote marks/fine print, addresses, phone numbers, hashtags, slogans, second/third offers, spec lists. Tell the user in the brief what you left out.
3. **Match the hook font to the reference** (if a reference has a headline): crop the headline into `img/hook-ref.png`, copy `templates/font-compare/overlay.html` into a scratch folder with `job.json` `{"name":"font-match","sheet":true,"duration":1,"text":"<hook>","ref":"img/hook-ref.png"}`, run render.js `--preview-only`, look at the sheet and pick the closest family/weight/italic. Then copy the reference's *treatment* too (slant/skew, tight tracking, two-tone words, outline/plate/extrude, sticker box) — see design-guide §3.
4. **Write a short design brief** (show it to the user in 4–6 lines): chosen layout pattern + why, palette (hex), hook font (+ why it matches), decoration language, motion energy, what was left out, where the clip stays visible. CI comes from the references; if none, from the product image; never default to the old navy/orange look unless it fits. If the inputs are plain/empty-looking, plan extra design layers (design-guide §8).
5. **Ask only what you can't infer** — one AskUserQuestion round, ≤ 4 questions with good options: e.g. CTA wording/channel (ทักแชท / สั่งซื้อ / จอง / สมัคร), whether to show the price/promo, which image is the reference, whether they'll post with captions (bottom safe zone). Never invent prices, dates, numbers, guarantees or claims.
6. **Build the job folder** next to the user's files: `overlay.html` (from `templates/starter.html`), `job.json` (duration, fps, previewAt, `checks.clearZone`, optional `checks.reveal`), and the images it uses (copy/crop them into the folder; cut-outs can be made with macOS Vision if the product needs a die-cut). Keep the middle band clear. **Top section = top 2/7 only (y < 548)** — logo + hook + at most one stamp/benefit line. **Bottom section = lowest 1/4 only (y ≥ 1440, 480 px tall) and the product image sits inside it** — cut the product out (die-cut PNG) and place it in the panel; it must not float above y 1440.
7. **Preview**:
   ```bash
   node <SKILL>/scripts/render.js <job-folder> --preview-only
   ```
   Open `<name>-preview.png` yourself and critique it like a designer: hierarchy, contrast over a busy clip, alignment, Thai line breaks, nothing in the clip area, matches the brief/refs. Also check: does it look *designed* (not empty/flat)? Is every text block needed? Fix WARN lines (overflow, page errors, **bottom section too tall**). Iterate until it's good, then send both preview PNGs (SendUserFile) and wait for the user's OK/changes.
8. **Export**:
   ```bash
   node <SKILL>/scripts/render.js <job-folder>
   ```
   Default 15 s / 30 fps (set in job.json). `--prores` adds a desktop ProRes 4444 file. Needs Node 18+ and internet on first run (see setup above). On macOS the export is also checked with Apple's decoder (needs `swift`, from Xcode Command Line Tools); on Windows/Linux the cross-platform checks run (pixels before encoding + alpha layer present in every frame).
9. **Verify**: every printed check must be `PASS` (alpha flag, clip area transparent the whole time, top section within the top 2/7, bottom section within the lowest 1/4, reveal timing if set, no white-fringe risk). If anything FAILs, fix and re-render — don't deliver a failing file.
10. **Deliver** the `*-alpha-mobile.mov` (SendUserFile) + one line on use: CapCut → add as **Overlay**, fill the 9:16 frame, top layer.

## Hard rules (learned from real problems)

- Deliver **.mov HEVC with alpha** for phones — .mp4/H.264 can't be transparent. macOS encodes with Apple VideoToolbox, Windows/Linux with x265's alpha layer (BtbN FFmpeg builds); both were verified to decode with transparency by Apple's decoder (= iPhone). Apple's `avconvert` alpha preset dropped the alpha in testing — don't use it.
- Don't bypass render.js's **premultiply + alpha<4 cleanup** — without it CapCut exports show white streaks where fades end.
- Animation only on the paused **master** GSAP timeline, seeked frame by frame (see contract) — no CSS animations or timers.
- `RENDER.seek` must return nothing.
- Keep the user's clip visible; respect the safe zones in the design guide unless the user decides otherwise.
- **Top section ≤ 2/7 of the frame** (nothing visible from y 548 down to 1000 — includes shade fades, glows, rotating benefit lines, pop overshoot). If the hook doesn't fit, shorten it or cut the extras; don't shrink below the sizes in the guide. Only if the user explicitly asks, set `checks.topLimit`.
- **Bottom section ≤ 1/4 of the frame** (nothing visible between y 1000 and 1440, including shadows, glows, gradient fades, popping/overshooting elements and the tap cursor). render.js warns in preview and FAILs on export. Only if the user explicitly asks for a taller bottom, set `checks.bottomLimit` in job.json.
- **Product image goes in the bottom section**, inside the 480 px panel — not floating in the clip area.
- **Only the important details.** One offer, one CTA, short lines. If it doesn't fit comfortably at ≥ 26 px in the quarter, cut content — never shrink text below that.
- **Hook font follows the reference** (closest available Thai font + the same treatment), not a default.
- **Never ship a bare layout**: if the source images are plain, add designed layers (§8 of the guide) so it looks finished.
- Write copy in the user's language (Thai by default), short and concrete.
