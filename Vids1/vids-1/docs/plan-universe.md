# Plan — Universe, Productions, Moods

The studio's content model. A **Universe** owns reusable assets (characters, sets, moods);
**Productions** (Shows→Seasons→Episodes, and Movies) cast from a universe. Defaults trickle
down the same way `language` already does. Decisions taken: build the Universe foundation
first; model Movies alongside Shows; moods also shape voice delivery.

```
Universe ── characters · sets · moods · lore   (reusable, show-agnostic)
   ├─ Show ─► Season ─► Episode (.md)           productions draw cast/sets/moods
   └─ Movie  (long single .md)                  from their universe
```

---

## 1. Characters become a shared library (the keystone)

Today characters are cast scenes hardcoded in `CastRegistry`. We flip ownership: characters
live in a universe and are discovered dynamically.

- **Location:** `universes/<universe>/characters/<id>.tscn` (the hand-editable visual scene,
  `Character` script at root, `CharacterData` inline — unchanged shape).
- **`CharacterData` grows into a bible:** identity + the existing language/voices, plus
  `bio`, `personality`, `relationships` (id → label, e.g. `{"lucas": "younger brother"}`),
  `catchphrases`, `tags`. Optional fields; empty by default.
- **`CastRegistry` goes dynamic:** scans `universes/*/characters/*.tscn`, maps `id` (file
  basename) → scene. Adding a character = drop a scene in the folder. No code edits.
- **History is auto-derived:** scan all episode `.md` for cast usage → "Leo: S01E01, S01E02,
  Movie-1." Never hand-maintained. (Computed in the dock.)

A character can appear in any production that shares its universe — that's the whole point.

## 2. Productions: Show and Movie

- **`Show`** gains a `universe` reference (which universe it casts from). Seasons/episodes
  unchanged.
- **`Movie`** is a sibling production: title, `universe`, language, fps/resolution, one
  (possibly long) `.md`. Same render path as an episode — it's just a big script.
- The dock browses **Universe → {Shows, Movies}**, and a **Characters** tab for the universe.

## 3. Moods — trickle-down presets that shape audio + visuals + voice

A `Mood` is a named bundle resolved most-specific-first, exactly like `language`:

```
scene mood → episode mood → season → show → (none)
```

A `Mood` resource holds:
- `music`, `ambience` (names → AudioLibrary), `bg_color` (stage tint)
- `pace` (scales the inter-beat gap)
- **voice delivery:** `voice_length_scale` (>1 slower), `voice_noise_scale` — passed straight
  to Piper, so "tense" speaks slower/flatter, "manic" faster. One word reshapes a scene.

Authoring: `## Scene: kitchen — night {mood: tense}` or episode frontmatter `mood: happy`.
A mood expands to the music/ambience/bg it implies; explicit `[music: …]` still overrides.

## 4. Templates

- **Episode templates:** skeleton `.md` files (`templates/episodes/*.md`) — "knock-knock",
  "two-hander", "cold-open→bit→tag", "interview". The dock's "New episode" scaffolds from one.
- **Show archetypes:** a show *type* (`templates/shows/*.tres`) seeding defaults — "sitcom"
  (bright, laugh sfx), "storytime" (narrator + calm mood), "news-desk" (one anchor + desk set).

## 5. Storytelling layer

Above dialogue beats: each scene/episode carries a `stage` (setup / conflict / twist /
resolution) and a mood. The dock shows an **outline view** (episode = ordered stages) so you
write structure-first. Seasons can carry an arc that episodes slot into. (Later slice.)

---

## Build sequence

1. **Universe + shared characters** ← *this slice*. `Universe` resource; `CharacterData`
   bible fields; dynamic `CastRegistry`; move leo/lucas into `universes/leo_lucas/`.
2. **Moods** (resolution chain + music/ambience/bg + Piper voice params; `Tts.synth` takes
   delivery params, cache key includes them).
3. **Movie** production type + `Show.universe` reference.
4. **Templates** (episode skeletons + "new from template"; show archetypes).
5. **Story stages + outline view**; dock Universe/Characters tabs; auto-derived history.
6. Dock polish from `plan-studio-panel.md` (validate/lint, log tail) on top.

## What slice 1 delivers (no behavior change for existing episodes)

- `universes/leo_lucas/` with `universe.tres` + `characters/{leo,lucas}.tscn`.
- `CharacterData` bible fields (unused-but-present is fine).
- `CastRegistry` resolves ids by scanning universes — cookie & cow still render unchanged.
- `Show` gets an optional `universe` pointer (informational until Movies/dock use it).
