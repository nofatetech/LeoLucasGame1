# Timeline & Event Spec

The contract between a `.md` episode script and the Godot **Director** that renders it.

Design rule: **dialogue is the clock; everything else hangs off beats, never off absolute time.**
Authors think in "this, then this, *while* that" — the Director resolves real seconds at render
once every audio clip's true length is known.

---

## 1. The three lifetimes

Every event — sound *or* visual — is exactly one of three shapes. This is the whole model.

| Lifetime | Lives for | Advances playhead? | Examples |
|----------|-----------|--------------------|----------|
| **Clock** | one beat   | **yes** | dialogue line, `[wait]` |
| **Point** | an instant | no  | sfx, emote, camera cut, stinger |
| **Span**  | beat → beat | no | music, ambience, a held action |

- The **playhead** only moves on Clock beats. Their duration = the line's audio length
  (or the explicit `[wait]` value).
- **Points** fire at a moment, relative to a beat, with an optional offset.
- **Spans** open at one beat and close at a later one (or auto-close at scene end).

Build the resolver once for these three and it covers sound, animation, and camera alike.

---

## 2. Script structure

```markdown
---
episode: "s01e03"
title: "The Last Cookie"
cast: { leo: red_kid, lucas: blue_kid }   # alias -> character resource
---

## Scene: kitchen — night
[bg: kitchen] [ambience: kitchen_hum] [music: tense start]

leo: (annoyed) You took the last cookie.
[sfx: fridge_close +0.4]
lucas: (whisper) Prove it.
[wait: 1.2]
[sfx: crash] [camera: shake]
[music: stop]
```

- **Frontmatter** (YAML): `episode`, `title`, optional `description`, and `cast` (alias → character).
- **`## Scene: <name> — <time-of-day>`** opens a scene. Scene exit auto-closes any open spans.
- **Dialogue line**: `alias: (emote) text` → Clock beat. `(emote)` is optional.
- **Directive**: `[verb: args]` → Point or Span depending on the verb. Multiple per line allowed.
- Blank lines are ignored. `#`-prefixed lines that aren't `## Scene` are author comments.

---

## 3. Directive grammar

```
directive   := "[" verb (":" args)? ("+" offset)? "]"
verb        := identifier
args        := token ("," token)*        # verb-specific
offset      := seconds (float)           # only meaningful on Point directives
```

Offsets are **relative to the start of the beat the directive sits on** (positive = later).
Negative offsets are allowed (fire slightly *before* the line lands).

### Core verbs (v1)

| Verb | Lifetime | Args | Meaning |
|------|----------|------|---------|
| `sfx` | Point | `name [+offset]` | one-shot sound effect |
| `emote` | Point | `alias, name` | character expression swap |
| `action` | Point/Span | `alias, name [start\|stop]` | gesture; Span if `start`/`stop` |
| `camera` | Point | `wide\|mid\|close\|shake\|cut <target>` | shot framing / motion |
| `bg` | Point | `name` | set scene background |
| `ambience` | Span | `name [start\|stop]` | looping room tone (default start) |
| `music` | Span | `name [start\|stop]` | scored track; auto-ducks under dialogue |
| `wait` | Clock | `seconds` | silent pause that advances the playhead |
| `sync` | — | `marker` | anchor next Point to a named marker (see §6) |

Unknown verbs are a **non-fatal warning** (logged, skipped) so scripts stay forward-compatible.

---

## 4. How the Director resolves beats → seconds

```
playhead = 0
open_spans = {}
for each line in scene:
    beat_start = playhead
    # 1. fire Point directives on this line, scheduled at beat_start + offset
    # 2. open/close Span directives (record start time, or seal end time)
    if line is dialogue:
        clip = tts(line.text, voice_of(line.alias))
        schedule_dialogue(clip, at = beat_start)
        drive_mouth_flap(line.alias, clip)        # amplitude-driven shapes
        playhead += clip.length
    elif line is [wait: t]:
        playhead += t
    # directive-only lines do NOT advance the playhead
on scene_exit:
    seal all still-open spans at playhead
```

Key properties this buys:

- **Re-record-safe.** Change a line, a voice, or insert a beat — every downstream event
  re-resolves automatically because nothing was pinned to a number.
- **Directive-only lines are free** — they ride the current playhead, so you can stack
  `[sfx]`/`[camera]` without inserting time.
- **Spans clean themselves up** at scene exit; no dangling music.

---

## 5. Render modes

| Mode | Audio | Timing source | Use |
|------|-------|---------------|-----|
| **Preview** | skipped / beeps | placeholder durations (≈0.06s/char) | fast in-editor iteration |
| **Final** | real TTS + SFX | true clip lengths | Movie Maker export to video |

Same script, same Director — only the timing source and audio swap. Determinism required in
both: fixed timestep, seeded RNG, no `randf()` in render paths. Re-rendering an episode must be
byte-identical.

---

## 6. Sync points (escape hatch — build only when a shot needs it)

Most timing is beat-relative and that's enough. Occasionally you want a Point to land on an
exact animation frame rather than a beat. A named `marker` inside an `AnimationPlayer` track
emits a signal; `[sync: marker]` binds the next Point directive to that signal instead of to
`beat_start + offset`.

```markdown
[action: leo, swing start]
[sync: bat_contact] [sfx: home_run]   # fires the instant the swing hits, not on a clock
```

Do **not** implement this in v1. It exists in the grammar so scripts don't need rewriting later.

---

## 7. Open questions (decide before locking v1)

- Voice assignment: per-alias in frontmatter, or a separate cast registry resource?
- Music ducking: automatic gain envelope vs. explicit `[music: duck]` directive?
- Multi-speaker overlap: v1 assumes one Clock beat at a time. Crosstalk = later.
- Offset units: seconds only, or allow `+2beats`? (Leaning seconds-only for v1.)
