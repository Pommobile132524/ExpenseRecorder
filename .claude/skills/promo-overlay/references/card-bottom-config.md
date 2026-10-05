# Classic "card-bottom" template — config.json reference

The original approved design (hook top, card bottom popping at 3s). Use it when the user asks for "แบบเดิม / แบบคอร์ส AI" or when a quick, proven result is wanted. Put `config.json` (+ images) in a job folder WITHOUT an overlay.html and run render.js on the folder.

Paths are relative to the config file (or absolute). Colors must be `#rrggbb`.

| field | required | meaning |
|---|---|---|
| `name` | yes | output file prefix, e.g. `ai-course` |
| `image` | yes | the promo image (product / service / course poster) |
| `imageCrop` | recommended | `{x,y,w,h}` in source pixels — the subject shown in the card (≈ square works best). Omit = whole image, centered |
| `logo` | no | `{ "image": "...", "crop": {x,y,w,h} }` — small logo top-left (height 80px). Omit or `null` = no logo |
| `pill` | no | small tag next to the logo: target audience, e.g. `สำหรับเจ้าของธุรกิจ` |
| `hook1` | yes | first hook line (white), question / pain point |
| `hook2` | no | second hook line in the accent box (punchy) |
| `benefits` | yes | 2–4 short benefits; `<b>…</b>` marks the accent-colored word |
| `kicker` | yes | small label above the title: `คอร์สเรียน`, `สินค้าใหม่`, `บริการ` … |
| `title1` / `title2` | yes | name of the product/course; `title2` is big + accent color |
| `cta` | yes | button text (arrow is added automatically) |
| `chip` | no | text of the floating chip on the card, e.g. `AI-Ready`, `ขายดี`, `ของแท้ 100%` |
| `names` | no | list of name tags on the card image (presenters/coaches) — max 3 short names |
| `theme` | no | `{dark, accent, accentLight, secondary, cardFrom, cardTo}` — pick from the image's palette. Defaults = navy / orange / blue |
| `previewBackground` | no | image used behind the overlay in the preview PNG (default: the promo image) |
| `duration` | no | seconds, default 15 |
| `fps` | no | default 30 |
| `cardIn` | no | when the card pops up, default 3 |
| `loop` | no | seconds per loop (benefits rotate within it), default 9 |
| `outDir` | no | where outputs go, default = config's folder |

## Example (the original AI & Business Injection course)

```json
{
  "name": "ai-business-injection",
  "image": "Cover course.png",
  "imageCrop": { "x": 800, "y": 0, "w": 1120, "h": 1080 },
  "logo": { "image": "Cover course.png", "crop": { "x": 56, "y": 38, "w": 310, "h": 110 } },
  "pill": "สำหรับเจ้าของธุรกิจ",
  "hook1": "ยังไม่ใช้ AI ในธุรกิจ?",
  "hook2": "คู่แข่งแซงแล้ว!",
  "benefits": ["เจาะลึก<b>ธุรกิจ</b>", "<b>เข้าใจง่าย</b>", "ใช้ได้<b>จริง</b>"],
  "kicker": "คอร์สเรียน",
  "title1": "AI & Business",
  "title2": "Injection",
  "cta": "สมัครเลย ที่นั่งจำกัด",
  "chip": "AI-Ready",
  "names": ["โค้ชเกรท", "โค้ชมิค"],
  "theme": { "dark": "#070f2b", "accent": "#ff7a45", "accentLight": "#ffa37a", "secondary": "#2f6bff", "cardFrom": "#142460", "cardTo": "#091234" },
  "duration": 15
}
```

## Picking values

- **imageCrop**: find the people/product bounding box, then grow it to roughly square around the subject (the card box is 470×470 and fades on its right side, so keep the subject left-of-center).
- **theme**: `dark` = darkest brand/background tone (used for the fades — must be dark for legibility); `accent` = the loudest brand color (CTA, hook box); `secondary` = a contrasting brand color (check icons); `cardFrom/cardTo` = two dark tones close to `dark`.
- **benefits**: concrete outcomes for the customer, not features; keep each short so it fits one line at 50px.
