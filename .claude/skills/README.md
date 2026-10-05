# Project skills

## Custom skills

- `promo-overlay/` — สร้างไฟล์ overlay แนวตั้ง 9:16 พื้นหลังใส (.mov HEVC + alpha)
  ไว้ซ้อนบนคลิปโปรโมทสินค้า/บริการ/คอร์ส (uploaded by the repo owner; see
  `promo-overlay/Promo-Overlay-Guide-TH.md` for the Thai guide). Not part of
  the vendored set below.

## Vendored skills: mattpocock-skills

Agent skills vendored from [mattpocock/skills](https://github.com/mattpocock/skills)
(MIT License — see `LICENSE-mattpocock-skills`).

- Source version: `1.2.3` (plugin `mattpocock-skills`)
- Source commit: `3cca18b368ae95cdbdebbff572ccafa662551015`
- Contents: the 25 active skills listed in the source repo's
  `.claude-plugin/plugin.json`, flattened into `.claude/skills/<skill-name>/`
  so Claude Code auto-discovers them as project skills.

## Usage

Skills load automatically at the start of each Claude Code session in this
repo. User-invoked skills are available as slash commands (e.g. `/grill-me`,
`/to-spec`, `/implement`); model-invoked skills (e.g. `tdd`, `code-review`,
`diagnosing-bugs`) trigger on matching tasks.

Recommended first step (per the upstream README): run
`/setup-matt-pocock-skills` once in a new session to configure the repo's
issue tracker, triage labels, and domain doc layout.

## Updating

Re-copy the skill folders from a fresh clone of the source repo, or use:

```bash
npx skills@latest add mattpocock/skills
```

These are ordinary files owned by this repo — edit them freely.
