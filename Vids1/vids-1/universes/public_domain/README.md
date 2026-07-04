# Public Domain — sample character library

A shared pool of **CC0 / public-domain** characters any Show or Movie can cast from. Empty for
now on purpose; fill `characters/` over time. `CastRegistry` discovers characters here the same
way it does any universe: any `characters/<id>.tscn` becomes a castable `<id>`.

## How to add a sample character

A character here is just a **`CharacterData` resource** — no scene to author. Drop
`characters/<id>.tres` and it's castable as `<id>` (the shared `character_base.tscn` builds
the look from its `Look` fields). Two looks:

- **Procedural** (`look = "procedural"`): set `body_color` / `skin_color` / `hair_color` /
  `has_hair` / `eye_color`. Flat shapes, our default style. See `characters/sage.tres`.
- **Image** (`look = "image"`): set `body_texture` to a PNG/WebP/SVG cutout (transparent PNG
  for a clean edge); it's auto-scaled to the native cast height. Optional `mouth_closed` /
  `mouth_open` cutouts lip-sync via swap. See `characters/glyph.tres`.

Then fill identity/voice/bible (`id`, `display_name`, `voices`, `bio`, `tags`). If the art is
sourced (not ours), add its license/attribution under `LICENSES/` — see below.

> Need full control (a bespoke rig, layered art)? Author a hand-drawn `characters/<id>.tscn`
> instead — a `.tscn` wins over a `.tres` of the same id. Data-driven is the default; bespoke
> is the escape hatch for heroes.

## Licensing rule (locked)

Assets are **baked into the repo**, never fetched at render time (keeps renders deterministic).
Only use **CC0 / public-domain** (or art we own). For each sourced asset add a file under
`LICENSES/<id>.md` recording: source URL, author, license, and any attribution text required.

## Layout

```
public_domain/
  universe.tres        this pack's identity
  characters/          <id>.tscn per character (currently empty)
  LICENSES/            one note per sourced asset (source, author, license)
```
