# Plan — Templates (four axes) + Obsidian-first

"Template" is really **four orthogonal axes** that compose. Keeping them separate is what makes
the system scalable. Decision: build all four; **Obsidian is the primary management/authoring
layer** (our scripts are already markdown + YAML frontmatter — Obsidian-native).

| Axis | What it is | Lives as | Example |
|------|-----------|----------|---------|
| **Format** | a story *shape* | skeleton `.md` in `templates/` | promo, fable, interview |
| **Style** | how it's *rendered* | `Style` preset (resolution + shader) | anaglyph, vertical 9:16 |
| **Content pack** | a ready *universe* | `universes/<id>/` | Aesop fables (public domain) |
| **Archetype** | a show's *default bundle* | `Show` preset (.tres) | sitcom, storytime channel |

They compose: a *fable* (format) in *anaglyph* (style) using the *Aesop pack* (content) under a
*storytime* archetype.

---

## Style (render layer) — trickles down like mood

A `Style` resolves episode `style:` → show/season (`--style`) → none. Two parts:
- **Resolution / aspect** — `wide` 1280×720, `vertical` 1080×1920 (Shorts/Reels/TikTok),
  `square` 1080×1080. Set at launch via Godot's `--resolution`; the **scene layout is
  responsive** (positions derived from viewport size) so it adapts.
- **Post shader** — fullscreen effect: `anaglyph` (red/cyan 3D glasses), `bw` (silent-film),
  `crt`. A `CanvasLayer` + screen-reading `ColorRect` shader. Built-ins in `StyleLibrary`,
  overridable via `universes/<u>/styles/<id>.tres`.

(Aspect = the real-world publish gap — vertical Shorts matter more than the gimmicks.)

## Format (story skeletons)

`templates/episodes/*.md` — placeholder scripts. "New from template" copies one, registers an
`EpisodeRef`. Starter set:
- **`promo`** — hook → problem → feature beats → CTA. First use: a **promo for Vids1 itself**
  (dogfooding + a real marketing asset).
- **`fable`** — narrator + two characters + moral (pairs with the Aesop pack).
- later: interview, news-desk, explainer, trailer, recap, silent-film (intertitle cards).

## Content pack (public-domain universes)

Ship reusable universes from **public-domain** material — *plots/names are free; we use our own
flat-shape designs, never someone's art*. Safe sources: Aesop's fables, Grimm/Andersen,
Greek/Norse myth, nursery rhymes, Sherlock Holmes, Alice, Dracula. First: an **`aesop`**
universe + the `fable` format.

## Archetype (show presets)

`templates/shows/*.tres` — a `Show` with defaults pre-filled (format + style + mood + cast
roles): `sitcom` (bright, snappy), `storytime` (calm mood, narrator), `news-desk`.

---

## Obsidian-first management

Our episodes are markdown + YAML frontmatter = Obsidian's native format. Point a vault at the
project and get, with near-zero code:
- **Graph view = the M8 story graph** (wikilinks between episodes/characters become the graph).
- **Backlinks = character history** for free (`[[Leo]]` → "appears in…").
- **Dataview dashboards** over our frontmatter (episodes by mood/status/language).
- **Canvas** to author branch graphs we can parse; **Templates** plugin hosts our formats.

Conventions to adopt (cheap): keep frontmatter (done); add `[[wikilinks]]` for cast/episode
refs (parser learns to read them as cast ids / story edges); ship starter Dataview queries +
a `.obsidian`-friendly README. The custom dock stays a thin **render launcher**; Obsidian is
the brain. This likely replaces the dock's planned browse/manage/graph UI.

---

## Build sequence

1. ~~**Style layer** (anaglyph + aspect + responsive layout; `Style`/`StyleLibrary`).~~ ✅
2. ~~**Format skeletons** + "new from template" + the Vids1 self-promo.~~ ✅
   `templates/episodes/{promo,fable,interview}.md`; dock **"New…"**; `episodes/promo_vids1.md`.
3. **Obsidian conventions** (wikilink cast refs, Dataview starters, vault README). ← next
4. **PD content pack** (`aesop` universe + `fable` format + a sample fable).
5. **Archetypes** (show presets) — last, once the others exist to bundle.
