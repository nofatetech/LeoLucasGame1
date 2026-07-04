# Public Domain — sample character library

A shared pool of **CC0 / public-domain** characters any Show or Movie can cast from. Empty for
now on purpose; fill `characters/` over time. `CastRegistry` discovers characters here the same
way it does any universe: any `characters/<id>.tscn` becomes a castable `<id>`.

## How to add a sample character (today)

1. Duplicate `res://domains/character/character.tscn` into `characters/<id>.tscn`.
2. Draw the look — flat `Polygon2D` shapes **or** `Sprite2D` nodes with PNG/WebP textures
   (transparent PNG for cutouts). Keep the `Voice` (AudioStreamPlayer) and `Mouth` nodes.
   Draw feet-at-origin, ~224px tall / ~58px half-wide so the auto-composition frames it right.
3. Fill `CharacterData` on the root (id, display_name, voices, bible).
4. If the art is sourced (not ours), drop its license/attribution under `LICENSES/` — see below.

> **Coming (backlog, priority): a data-driven character base** so a sample is just a
> `CharacterData` `.tres` (+ optional textures) instead of a full hand-built scene. Once that
> lands, populating this library gets much cheaper. Until then, duplicate the template.

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
