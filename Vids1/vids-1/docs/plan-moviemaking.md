# Plan — Moviemaking (cinematography layer)  [M10]

Make the flat one-color shows look **shot, not drawn** — without abandoning the South Park
aesthetic. Everything here is a **staging layer** the Director drives from the markdown: new
scene/beat directives that resolve like mood/style and animate deterministically. No engine fork.

**Decisions (2026-06-28):**
- **Keep it simple, ship fast, details later.** Build the smallest version of each slice that
  visibly improves the frame; tune knobs afterward.
- **Look:** keep the flat shapes as the *default*; add cinema *grammar* first (Phase 1 = light +
  grade, then camera). Richer characters (Phase 2) is **optional — only if it stays simple; defer
  it otherwise.**
- **Assets: agnostic pipeline.** A character/prop/background can be flat `Polygon2D`, **SVG**, or
  **bitmap** (`PNG/JPG/WebP`) or any mix — Godot treats them all as nodes and our contract is
  shape-agnostic, so nothing special is needed. *Ours-by-default* for style coherence, but dropping
  in CC0 vector/bitmap packs is fully supported. Audio: **free CC0**, baked into the repo.
- **Directing:** **auto + override.** The Director auto-frames/grades to sensible defaults;
  the script overrides per beat when it cares.
- **Build first:** **Light & color grade** (mood you can *see*).

## Hard constraints (why some "obvious" tricks are out)
- **GL Compatibility renderer.** `CanvasModulate`, screen-reading post shaders (we already ship
  `anaglyph`), and `Light2D` all work — but our cast is flat `Polygon2D` with **no normal maps**,
  so a `Light2D` only *tints a region uniformly*. Real per-surface **key/rim shading is not free**;
  it's faked globally in Phase 1 and hand-drawn (rim polygons) in Phase 2.
- **Movie Maker determinism.** No `randf()` in render paths. Anything "random" (grain, shake)
  must derive from the **frame index** (which increments deterministically), so re-renders stay
  byte-identical. All motion tweens off the **beat timeline**, not wall-clock.
- **Movie Maker bakes the viewport size at launch** (see `export.md`). `Camera2D` zoom/pan reframes
  *within* that baked size — fine — but resolution still comes from `override.cfg`.

---

## Architecture — one staging layer, resolved like everything else

New domain **`domains/stage/`** (camera, lights, grade presets) plus a `_stage` helper block in
the Director. Three resource kinds, each with a built-in library + per-universe `.tres` override,
resolved **most-specific-first** exactly like mood/style:

| Resource | Fields (first cut) | Built-ins |
|----------|--------------------|-----------|
| `Grade`  | tint·Color, contrast, saturation, temperature, vignette 0..1, grain 0..1 | `neutral`, `warm`, `noir`, `flash`, `dream` |
| `LightRig` | ambient·Color (→ CanvasModulate), key dir+color+energy, rim color, pool radius/color | `day`, `night`, `dusk`, `interior`, `spotlight` |
| `Shot`   | framing (wide/medium/close/two), target (cast id / "all"), height-fraction, x-bias | `wide`, `medium`, `close`, `two_shot`, `ots` |

**Mood ties in (composition, not duplication).** `Mood` gains optional `grade:` and `light:`
names. `tense → grade noir + light night`, `calm → grade warm + light day`. The episode/scene can
still override either independently. Resolution order for a beat:
`beat directive → scene `{...}` → mood's preset → show/episode default → built-in neutral/day/wide`.

### Grammar additions (parser stays forward-compatible — unknown verbs already warn-and-skip)
Scene header `{...}` learns comma-separated keys (today it reads only `mood:`):
```
## Scene: rooftop — night {mood: tense, light: night, grade: noir, lens: 50}
```
Inline / directive-only beats learn new verbs in `_normalize`:
```
[shot: close on leo]        # frame a character
[shot: two]                 # both in frame
[camera: push-in 1.5]       # dolly toward subject over 1.5s
[camera: pan leo 0.8]       # ease the frame to a subject
[camera: shake 0.3]         # deterministic shake (frame-index noise)
[light: spotlight on leo]   # accent pool / preset swap
[grade: flash 0.2]          # brief grade pulse (impact, lightning)
[look: leo at lucas]        # Phase 2 — head turn
[gesture: leo point]        # Phase 2 — arm beat
```

### Auto-direction defaults (the "good out of the box" half)
- On every `say` beat: **cut/ease the frame to the speaker** (medium), widen to **two-shot** when
  speakers alternate quickly. Subtle **push-in on emphasis** (ALL-CAPS text or "excited/gritando"
  emote). All easing keyed to the line's audio length.
- **Grade + light default from the scene's mood**; **time-of-day** inferred from scene-name
  keywords (`night`/`noche`, `dawn`, `día`) or the explicit `light:` key.
- Every default is overridable by a directive on the same beat.

---

## Phase 1 — staging (ships in three slices)

### Slice A — Light & color grade  ← BUILD FIRST
The cheapest "every frame looks shot" win; it reuses the post-shader `CanvasLayer` we already have
for styles. **Minimal version first:**
1. **`Grade` + `GradeLibrary`** and a `grade.gdshader` (full-screen, screen-reading): tint
   multiply, contrast/saturation, temperature, **vignette**, **directional gradient** (cheap fake
   key: warm corner → cool corner), **frame-index grain**. *Composes* below the style shaders.
2. Wire it: `Mood.grade` (new optional field) + scene `{grade:}` + `[grade: name]` beat, resolved
   most-specific-first. A few presets: `neutral`/`warm`/`noir`/`flash`.
   *Verify:* `tense` → cold + vignetted; `calm` → warm; grain **identical across two renders**.
3. *Later/optional:* `CanvasModulate` time-of-day + `PointLight2D` accent pools (`LightRig`).
   The grade shader already does the heavy lifting, so this is polish, not blocking.

### Slice B — Camera & framing
1. Add a **`Camera2D`** to `main.tscn`; Director owns it. **`Shot` + `ShotLibrary`** presets map a
   framing to a `Camera2D` (position, zoom) computed from the responsive viewport + cast positions.
2. **Auto-frame the speaker**; `[shot: …]` overrides. **Moves:** push-in, pan-to-subject, shake —
   all tweened on the beat clock; shake uses frame-index value noise (deterministic).
3. Re-check the responsive composition math still holds when the camera zooms.

### Slice C — Depth & composition
1. **Parallax background layers** (sky / far / mid) as extra `Stage` `CanvasLayer`s that drift a
   few px with camera pan → instant depth, still flat.
2. **Rule-of-thirds placement** for 1–3 characters; subtle per-character idle offset so a held
   frame isn't dead. (Full idle/breathe is Phase 2.)

## Phase 2 — character richness  *(optional; defer unless it stays simple)*
Rig upgrades on `Character`, all deterministic — pick only the cheap wins:
- **Blink** (cadence by frame index), **idle breathe/bob** — both trivial, high payoff.
- Later/maybe: **eyebrows** by mood, **head look-at** the speaker, **arms** on emphasis
  (`[gesture:]`), **hand-drawn rim** polygon for real key/rim. Skip until Phase 1 has landed.

---

## Assets — vector, SVG, **and** bitmap all welcome
The pipeline is **format-agnostic by design**, because a cast/prop scene is "whatever nodes you
draw" and the `Character` contract only needs `Voice` + a `Mouth.set_open()`:

| Source | Node | Notes |
|--------|------|-------|
| Flat shapes (today) | `Polygon2D` | Our default; cheapest; no real per-surface lighting. |
| **SVG** | `Sprite2D` | Godot **rasterizes SVG → texture at import** (set import `scale`). Crisp, easy to re-export bigger. Not live-vector at runtime. |
| **Bitmap** (PNG/JPG/WebP) | `Sprite2D` | Native + deterministic. With a **normal map** it takes real `Light2D` shading — better lit than flat polygons. |
| Mix | any | e.g. bitmap body + polygon flap-mouth, or sprite **viseme** swaps via the existing `Mouth` shape-swap. |

**The catch is curatorial, not technical:**
- **Coherence** — mixed packs can look like "asset soup." Keep one style per show; ours-by-default.
- **Animation granularity** — a *single full-character image* only bobs/slides/scales. To flap or
  gesture, cut it into parts (head/jaw/arms) or supply swap-frames. Parts = animatable.
- **Convention** — assets live in `assets/` (shared) or `universes/<u>/assets/`; bake the file +
  its **license** into the repo. Never fetch at render (determinism). Prefer **CC0**.
- **Import** — PNG: enable mipmaps + linear filter for clean camera-zoom scaling. SVG: pick an
  import `scale` ≥ the largest on-screen size so it stays sharp.

**Audio:** free **CC0**, pre-baked, supplementing our procedural `AudioLibrary`. Sources: Kenney
audio, Freesound (filter CC0), Free Music Archive / Incompetech (check each track).
**Font:** one free OFL/CC0 display face for subtitles + future title cards (we use the engine
default today). Bake the `.ttf` + license into the repo.

## Open questions / risks
- **Grain & vignette taste:** easy to overdo. Default amounts low; expose 0..1 so episodes dial it.
- **Light2D in Compatibility** is limited on flat polygons — plan treats it as *accent only*; the
  grade shader does the heavy lifting. Re-evaluate if we ever switch to the Forward+ renderer.
- **Auto-cut frequency:** too many cuts feels jittery. Heuristic: min hold ~1.2s, no cut on lines
  under ~0.8s. Tunable.

## Build sequence
1. ~~**Slice A — Light & color grade** (`Grade`/`GradeLibrary` + `grade.gdshader` + mood wiring).~~
   ✅ shipped — `domains/grade/`; `[grade:]`/`{grade:}`/mood resolution; byte-identical re-renders.
   *(CanvasModulate / Light2D accents still optional/later.)*
2. **Slice B — Camera & framing** (`Camera2D` + `Shot`/`ShotLibrary` + auto-frame + moves). ← next
3. **Slice C — Depth & composition** (parallax layers + thirds placement).
4. **Phase 2** — character rig (blink → breathe → brows → look-at → gesture → rim).
