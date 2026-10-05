# Designing the overlay for each product

The overlay sits on top of the user's own vertical clip (usually a person talking or the product being used). Its job: **stop the scroll (hook) → say why it matters (benefit) → show what it is (product/brand) → tell them what to do (CTA)**, without covering the clip.

## 1. Read the inputs

**Product / service / course image** → what it is, name, price/promo if printed, who it's for, key selling points, the subject to crop (product cut-out, faces, packshot), logo.

**Reference images (optional, any number)** → they override the defaults. Extract a CI brief:
- **Palette**: 1 dark/neutral base, 1–2 brand colors, 1 highlight. Sample real hex values (open the image with Read, or crop & inspect with a quick script if precision matters). Check contrast: white text on the base must be readable.
- **Typography**: weight (heavy/bold vs light), style (geometric sans / rounded / serif / handwritten / condensed), case and letter-spacing habits, Thai vs Latin pairing.
- **Shapes & surfaces**: rounded pills vs sharp rectangles, glass/blur, flat color blocks, outlines, gradients, grain, stickers/die-cut, badges, ribbons.
- **Decoration language**: sparkles, lines, dots, organic blobs, arrows, emoji-like stickers, price bursts.
- **Mood & motion energy**: calm/premium (slow fades, small moves) vs loud/promo (bouncy pops, shakes, big scale).
Write the brief down (5–8 bullets) before designing, and follow it. If no reference is given, derive the CI from the product image itself; if that's thin too, pick a style that fits the category below.

## 2. Pick a layout that fits the product (don't reuse one by default)

All layouts keep a clear middle band for the clip. **Fixed frame budget (1080×1920):**
- **Top / hook zone: y 0–548 = the top 2/7, never taller.** Usable area ≈ y 80–540 (~460 px): logo + hook (2 lines) + at most one stamp/badge or one rotating benefit line. Shade fades and pop overshoot also end above 548.
- **Clip zone**: y 548–1440 — nothing visible here.
- **Bottom zone: y 1440–1920 = the lowest 1/4, never taller.** It holds the product image + the one key offer + CTA. Shadows, glows, fades and animation overshoot must also stay below 1440.

Mix and adapt; these are starting points:

| pattern | looks like | good for |
|---|---|---|
| **Hook top + card bottom** (classic, templates/card-bottom) | headline block top, product card with image + CTA in the bottom quarter | courses, services, B2B, info products |
| **Ticker / tape** | slanted colored tapes with scrolling text top & bottom, small product sticker | sales, flash promos, events, food delivery |
| **Price burst + packshot** | big die-cut product image bottom-corner, starburst price/discount badge, CTA strip | physical products, FMCG, e-commerce, promotions with price |
| **Side tag** | short vertical brand tag on left/right inside the top zone (y < 548) with logo + benefit icons; bottom-quarter CTA strip | beauty, fashion, lifestyle, premium brands |
| **Lower-third bar** | broadcast-style name bar with logo + one line + CTA, minimal top tag | expert/presenter talking clips, clinics, consultants, real estate |
| **Corner frame** | brand-colored corner brackets/labels in the top zone + a matching bottom-quarter bar (no lines through the clip zone) | premium, minimal, luxury, hotels, cafés |
| **Sticker pop** | playful die-cut stickers, speech bubbles, hand-drawn arrows popping around the edges | kids, snacks, Gen-Z products, apps, games |
| **Checklist card** | top card with question; benefit checkmarks ticking in one by one (top zone); bottom-quarter product + CTA | services with clear outcomes, SaaS, training |

Choose by: category, brand mood (from refs), how much info there is (price? multiple benefits? a person's name?), and what the clip likely shows (a face → keep the center-top clearer; product demo → keep the center clear).

## 2a. The top 2/7 (548 px) — how to fit it

- Logo/brand mark small (height ≤ 80 px) at y ≈ 80–160, optionally with a tag pill beside it.
- Hook: 2 lines max, 72–100 px (the bigger word in the accent treatment), ending by ~y 470.
- One extra at most: a stamp/badge to the side of the hook, or one rotating benefit line (≤ 44 px).
- Dark fade behind it (for legibility) must reach alpha 0 by y 548.
If it doesn't fit → shorten the hook or drop the extra; don't go below 26 px text.

## 2b. The bottom quarter (480 px) — how to fit it

A proven grid (adapt freely, keep the zone):
- Panel y 1460–1920 (solid/gradient brand surface, top edge can be a slanted/curved cut or stripes).
- **Product image inside the panel**, left or right ~300–380 px wide, die-cut PNG, sitting on the panel's floor with a soft contact shadow / glow behind it. It may overlap the panel's top edge only down from y 1440, never above.
- Opposite side: ONE big offer line (price / %, 90–140 px) + one small label (26–34 px).
- CTA pill full-width or beside the offer, 40–52 px text, y ≈ 1780–1880.
- Optional: one condition line ≥ 22 px (only if needed so the offer isn't misleading).
If it feels crowded → remove content (see §7), don't shrink fonts.

## 3. Thai typography

Bundled: **LINE Seed Sans TH** (Rg/Bd/XBd/He) — modern, friendly, very legible. Other good Google Fonts with Thai:
- **Prompt** — geometric, punchy promos, headlines
- **Kanit** — strong, sporty, sales
- **Mitr** — rounded, friendly, kids/food
- **IBM Plex Sans Thai** — clean, tech/corporate
- **Noto Serif Thai** / **Trirong** — premium, beauty, luxury, editorial
- **Chakra Petch** — techy, gaming, futuristic
- **Bai Jamjuree** — modern corporate, finance
- **Sriracha** / **Mali** — handwritten, casual
Use at most 2 families.

### Match the hook font to the reference (required when a reference has a headline)
1. Crop the reference headline → `img/hook-ref.png`; render `templates/font-compare/` (see SKILL.md step 3) with the real hook text; pick the closest row by **shape**, not name: looped (หัวกลม) vs loopless (ไม่มีหัว), weight, width (condensed/wide), slant, x-height, square vs round bowls, terminals.
2. Poster fonts are often commercial (DB Heavent, PSL, Sukhumvit, Kittithada…). If the user has the file or it's installed on the Mac, use it (`@font-face` with the file in the job folder, or add it to the sheet via `"fonts":[{"family":"…","weight":900}]` to compare). Otherwise use the closest free one and tell the user which and why.
3. Copy the **treatment**, which matters as much as the family: italic or `transform: skewX(-8…-12deg)`, tight `letter-spacing`, two-tone words (e.g. white + yellow), thick outline (`-webkit-text-stroke` with `paint-order: stroke fill`), offset plate / 3D extrude (stacked `text-shadow` or a duplicate layer behind), sticker box, slight rotation, size jump between words.
4. Body text stays a clean, legible family (LINE Seed / Noto Sans Thai / IBM Plex Sans Thai).

Sizes at 1080 wide: headline 72–100px (must fit the top 2/7), sub 44–56px, labels 26–34px, CTA 40–52px. Keep text ≥ 26px. Long Thai lines: measure after `document.fonts.ready` and shrink to fit (see the `fitText` helper in templates/card-bottom).

## 4. Motion

- Intro ≤ 1.5 s: elements enter in reading order (hook → benefit → product → CTA).
- One "second beat" reveal (e.g. the product/price card at 2–4 s) re-captures attention.
- Idle loop: subtle and seamless (breathing CTA, rotating benefits, sparkles, shine sweep, ticker scroll). Avoid constant big motion over the clip.
- Match energy to the brand: premium = fades/slides, 0.6–1 s, `power2/expo`; promo = pops/bounces, `back.out`, shakes.
- A CTA "tap" (cursor/finger + ripple) once per loop works well for conversion.

## 5. Safe zones (TikTok / Reels / Shorts)

- Top ~220px: status bar/tabs — start content at ~y 80, keep small text below ~y 140. With the 2/7 limit, the hook usually spans y ≈ 140–460.
- Bottom ~300px: caption, username, music. The bottom quarter overlaps this; if the user will post with captions, keep the CTA/offer high in the quarter (y 1460–1650) and only low-priority decoration below (ask once).
- Right ~140px between y≈900–1620: like/comment/share buttons — don't put key text there.

## 6. Legibility over unknown footage

The clip under the overlay can be bright or busy. Put text on solid/blurred panels or on dark gradient fades from the edges (fade to fully transparent toward the middle). Fades are safe now — render.js removes the white-fringe problem — but always end fades at alpha 0, not at a tiny leftover value.

## 7. Content rules — less is more

The overlay is seen for a few seconds over a moving clip. Show only what makes someone stop and act:
- **Keep**: hook (1–2 short lines), ONE key offer (price / % / main benefit), product image, brand mark, CTA.
- **Optional (max 1–2)**: one stamp/badge with the strongest secondary point; one short condition line if omitting it would mislead (e.g. "สำหรับนิติบุคคล").
- **Drop by default**: date ranges, footnote numbers and fine print, addresses, phone numbers, hashtags, slogans, secondary/tertiary offers, spec lists, multiple logos. (If the user wants them back, add them.)
- Rule of thumb: ≤ 5 text blocks on the whole overlay; ≤ 3 in the bottom quarter.
- Only facts from the image or the user. Never invent prices, discounts, dates, quantities, certifications or guarantees.
- Hook: pain/question or bold promise, ≤ ~20 Thai characters per line. Benefits: concrete customer outcomes, 2–4 items, short.
- CTA verbs that match the channel: สั่งซื้อเลย / ทักแชทเลย / จองเลย / สมัครเลย / ลงทะเบียนฟรี / กดลิงก์ในโปรไฟล์.

## 8. When the inputs look plain — add design

If the product image / reference is sparse (white-background packshot, few elements, flat colors) or the first preview looks empty, add designed layers in the brand palette — inside the top and bottom zones only:
- **Surfaces**: gradient panels instead of flat fills, a slanted or curved panel top edge, a second offset panel/stripe in an accent color, subtle pattern (diagonal stripes, dots, grid, halftone) at 6–12 % opacity.
- **Product staging**: radial glow or spotlight behind the product, contact shadow / floor reflection, a colored circle or blob behind it, speed lines for vehicles, sparkles near highlights.
- **Accents**: corner brackets, thin lines, small stars/sparkles, arrows pointing to the offer, a ribbon/burst/badge for the number, outlined duplicates of the hook, brand-color tape strips.
- **Motion polish**: shine sweep across the panel/CTA, gentle float of the product, sparkle twinkle, stripes drifting (seamless loops).
Keep it coherent with the CI (same shape language, ≤ 3 colors + neutrals) and never let decoration hurt legibility or enter the clip zone.
