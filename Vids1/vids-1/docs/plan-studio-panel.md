# Plan — Studio panel (editor GUI) + language model

Status: **PLAN** (not built yet). Two related designs:
1. A custom Godot **editor dock** ("Studio") to manage shows → seasons → episodes, params, TTS, and render outputs.
2. A **language model** that defaults per show and trickles down, overridable at every level.

---

## 1. Content model: Show → Season → Episode

Today episodes are loose `.md` files in `episodes/`. To manage a series we introduce a small
resource hierarchy (Godot `Resource` / `.tres`, hand-editable + inspector-friendly):

```
domains/show/
  show.gd        # Show:    title, default_language, default_voices, seasons[]
  season.gd      # Season:  title, number, language(override), episodes[]
  episode_ref.gd # EpisodeRef: title, number, md_path, language(override), status, last_output
shows/
  leo_lucas/
    show.tres
    s01/ season.tres + cookie.md, cow.md, ...
```

- `Show` is the root: series-wide defaults (language, voices, resolution/fps, output dir).
- `Season` groups episodes, can override show defaults.
- `EpisodeRef` points at the `.md` and carries per-episode overrides + bookkeeping
  (render status, last output path/size/date).

The `.md` stays the source of truth for *content*; these resources hold *structure + params*
so the panel has something to list and the language/voice defaults have somewhere to live.

---

## 2. The Studio dock (EditorPlugin)

A `EditorPlugin` adding a bottom/right dock. Pure tooling — it drives the same headless
render path we already use, so nothing about playback logic changes.

```
┌ Studio ─────────────────────────────────────────────┐
│ Show: [Leo & Lucas ▾]   Default lang: [es ▾]         │
│ ┌ Seasons/Episodes ─────┐ ┌ Inspector ─────────────┐ │
│ │ ▾ S01                 │ │ Episode: cow            │ │
│ │    • cookie   ✅ 5.1s  │ │ md: episodes/cow.md     │ │
│ │    • cow      ✅ 12.2s │ │ language: (inherit→es)  │ │
│ │ ▸ S02                 │ │ fps: [30]  res:[1280x720]│ │
│ └───────────────────────┘ │ voices: leo→es_MX ...   │ │
│ [▶ Preview] [⤓ Render] [⤓ Render all] [Open output] │ │
│ Log: recording 1280x720 @30 … 380 frames … done      │ │
└──────────────────────────────────────────────────────┘
```

**Actions**
- **Preview**: run the episode in a play window (no movie), fast iteration.
- **Render**: invoke the export command we already have, per episode, writing to the show's
  output dir; update `EpisodeRef.status/last_output`.
- **Render all**: queue every episode in a season/show.
- **Params**: edit fps/resolution/language/voices inline; they save to the resources.
- **Outputs**: list rendered files with size/date; "Open output" / "Reveal".

**How it renders** — the panel shells out (`OS.create_process`) to:
```
godot --path . --fixed-fps <fps> --write-movie <out> res://scenes/main.tscn \
      -- --render --episode res://<md_path>
```
i.e. exactly the CLI we validated in M0/M1. The panel is a convenience layer, not new engine
logic — so the pipeline stays scriptable/CI-able without the GUI.

**Build order** (later milestone, ~M5):
1. Resources (`Show`/`Season`/`EpisodeRef`) + a couple of `.tres` for the current show.
2. Read-only dock: tree of shows/episodes from the resources.
3. Wire Preview/Render buttons to the existing CLI via `OS.create_process`, stream log.
4. Inline param editing (write back to resources).
5. Output tracking + "render all" queue.

---

## 3. Language model — default per show, trickles down, overridable everywhere

### Resolution chain (most specific wins)
For the language a given **line** is spoken in:

```
line override  →  character main language  →  episode  →  season  →  show default  →  "en"
```

Each level is optional; an empty value means "inherit from the next level down the list".

### Where each level lives
- **Show**: `Show.default_language` (e.g. `"es"`). The trunk.
- **Season**: `Season.language` override (optional).
- **Episode**: frontmatter `language: es` (optional). *(implemented now)*
- **Character main language**: `CharacterData.language` — a character can default to their own
  tongue regardless of the episode. *(implemented now)*
- **Line override**: `alias@lang:` prefix, e.g. `leo@en: Hello there.` — one line in another
  language. *(implemented now)*

### "Multilanguage" is not a flag — it's just having multiple voices
A character (or show) is multilingual simply by owning voices for more than one language:

```
CharacterData.voices = { "es": "es_MX-claude-high", "en": "en_US-hfc_male-medium" }
```
The resolved language picks the voice. No special mode. A monolingual character has one entry.

### Voice selection (given resolved language L, character C)
```
voice = C.voices[L]                    # character's voice for that language
      ?? Show.default_voices[L]        # series fallback voice for L   (later)
      ?? <none> → placeholder Tone + warn
```

### Subtitles & multilanguage output
- Subtitles render from the line text in whatever language it is — free, already wired.
- Future: emit per-language subtitle/caption tracks (`.srt`) as a render byproduct, and
  optionally render language variants of an episode by overriding the resolved language at the
  top of the chain (one script → `cow.es.mp4`, `cow.en.mp4`).

---

## 4. What's implemented vs planned

| Piece | State |
|-------|-------|
| Episode `language:` frontmatter | ✅ now (M2) |
| `CharacterData.language` + `voices` map | ✅ now (M2) |
| Line override `alias@lang:` | ✅ now (M2) |
| Voice selection + Piper TTS + Tone fallback | ✅ now (M2) |
| Show/Season resources + defaults trickle | ⬜ plan (M5) |
| Studio editor dock | ⬜ plan (M5) |
| Per-language `.srt` + language-variant renders | ⬜ plan (M6) |
