# Vids1 — script-driven animated episodes in Godot

Turn a markdown script into an exported animated video. Flat one-color-shape characters
(South Park–ish), driven by an opinionated `.md` script. Godot is the renderer; the script
is the source of truth.

**Bias:** simple / scalable / cool. 80% useful, 20% beautiful. Build the spine first.

---

## How it works (the spine)

```
episode.md  ──parse──▶  ScriptResource  ──drive──▶  Director  ──render──▶  video file
													   │
			  cast/bg/sfx registries ─────────────────┘
```

1. **Parse** the `.md` into a `ScriptResource` (scenes → beats → directives).
2. The **Director** walks beats, resolving timing from real audio length
   (dialogue is the clock — see [`timeline-spec.md`](timeline-spec.md)).
3. Characters/backgrounds/sfx come from **registries** referenced by name.
4. Export deterministically via Godot **Movie Maker mode** (`--write-movie`).

Core model: every event is **Clock / Point / Span** (one beat / an instant / a span).
Same model covers sound, animation, and camera. Full detail in the timeline spec.

---

## Key decisions (locked)

- **Data-driven, not codegen.** Godot reads the script at runtime; we never generate `.gd`/`.tscn`.
- **Dialogue is the clock.** No absolute timing — everything is beat-relative, so re-recording
  a line never breaks downstream events.
- **Movie Maker export**, not screen capture. Deterministic, frame-perfect, audio-synced.
- **Two render modes:** Preview (fast, placeholder timing) and Final (real TTS, video export).
- **Mirror the sibling project's layout** (`domains/`, `autoload/event_bus.gd`, MVC bases).

---

## Layout (target)

```
vids-1/
  docs/                  ← you are here (README + plan-* + spec)
  addons/vids_studio/    editor dock (browse/preview/render)
  domains/
    script/              md parser → EpisodeScript
    director/            beat playback, pacing, cast spawn, audio events
    character/           character.gd (contract) + mouth.gd + character_data.gd (bible)
      cast_registry.gd   id → cast scene (dynamic: scans universes/)
      character.tscn     TEMPLATE to duplicate for new characters
    audio/               tts (Piper), tone, clip_amplitude, audio_library (sfx/music)
    show/                Show / Season / EpisodeRef resources
    universe/            Universe resource
    mood/                Mood resource + MoodLibrary (presets)
  universes/<id>/        characters/<id>.tscn (+ universe.tres) — reusable cast
  shows/<id>/            show.tres
  episodes/              the .md scripts (cookie.md, cow.md)
  scenes/                main.tscn (entry)
  output/                rendered videos (gitignored)
```

---

## Milestones

### M0 — Prove the pipeline (no parser yet)  ✅ done
The risky part is export + audio sync. Hardcode a scene, prove it renders to a file.
- [x] `Character.tscn` + procedural draw from `CharacterData` (body/head/eyes/mouth)
- [x] Amplitude-driven mouth flap from an audio clip (`ClipAmplitude` reads clip RMS)
- [x] Minimal `Director`: plays 3 hardcoded lines with placeholder audio (`Tone`)
- [x] Movie Maker export + `domains/export/export.md` (auto-quit on `--render` user flag)
- [x] Verified in editor: two characters flap mouths in sync, subtitles advance
- [x] Verified export: renders `out.avi` (147 frames @ 30 FPS, ~4.3 s) and auto-quits
- **Done:** `godot --path . --fixed-fps 30 --write-movie out.avi res://scenes/main.tscn -- --render`

### M1 — Script format + parser  ✅ core done
- [x] `.md` → `EpisodeScript` parser (`domains/script/`): frontmatter (episode/title/cast),
      `## Scene:` headers, dialogue (`alias: (emote) text`), `[wait]`, comments
- [x] Director consumes `EpisodeScript` instead of hardcoded beats; cast spawned from
      `CastRegistry` (hand-editable scenes), auto-spread across the stage
- [x] Verified: editing `episodes/cookie.md` changes the rendered output, no code edits
      (added `[wait]` + whisper line → render grew 4.27 s → 5.16 s)
- [ ] Deferred: lock remaining grammar open questions (timeline spec §7); explicit
      Preview-vs-Final toggle (placeholder timing is already the default path)
- **Done when:** editing the `.md` changes the rendered output, no code edits. ✔

### M2 — Audio & timing for real  ✅ done
- [x] Local offline TTS via **Piper** (`domains/audio/tts.gd`), per-line clips, cached by
      text+voice hash → deterministic re-renders; falls back to `Tone` if Piper/voice missing
- [x] Clock resolves from **true clip length** (`_clip_for` / `_wav_seconds` in Director)
- [x] Language model: episode `language:` + `CharacterData.language`/`voices` + per-line
      `@lang` override, resolved most-specific-first (see [`plan-studio-panel.md`](plan-studio-panel.md) §3)
- [x] **SFX points** (inline or standalone, optional `+offset`), **ambience/music spans**
      (`start`/`stop`), **auto-duck** music under dialogue — `AudioLibrary` resolves names to
      deterministic procedural placeholders (real files drop in by name later)
- [x] Subtitles render from script lines (free)
- [x] Verified: `cow.md` renders in real LATAM Spanish (Leo `es_MX`, Lucas `es_AR`),
      lip-synced, with ducked music + sfx (12 beats, no warnings)
- **Done:** Final render has synced voices, sfx, ducked music, and on-screen captions.

### M3 — Reusability & polish  ⬜
- [ ] Cast registry (parameterized characters: color/hair/accessories)
- [ ] Background/prop registry
- [ ] Camera framings (wide/mid/close/shake) + scene transitions/stingers
- [ ] Thumbnail + description emitted per episode
- **Done when:** a new episode is "write `.md`, add any new assets, render."

### M4 — Later / nice-to-have  ⬜
- [ ] `[sync: marker]` escape hatch (frame-exact points)
- [ ] Multi-speaker overlap / crosstalk
- [ ] Per-character voice tuning, music ducking envelopes

### M5 — Studio panel + series structure  🟡 core done  (plan: [`plan-studio-panel.md`](plan-studio-panel.md))
- [x] `Show`/`Season`/`EpisodeRef` resources (`domains/show/`) + `shows/leo_lucas/show.tres`
- [x] Editor dock (`addons/vids_studio/`): browse the season/episode tree, Preview / Render /
      Render-all / Open-output; render status persists back to the `.tres`
- [x] Verified: editor mounts the plugin cleanly; the dock's render command produces
	  `output/cow.avi` (it shells out to the same CLI we use by hand)
- [x] Show/season `language` wired into the Director: the dock passes `--language` (resolved
	  episode→season→show default); it sits below the `.md`'s own `language:` in the chain
- [ ] Remaining: inline param editing in the dock (use the Inspector on `show.tres` for now);
      in-editor click-through QA
- **Note:** verified headlessly (load + render path); give the buttons a click in the editor.

### M6 — Localization output  ⬜
- [ ] Per-language `.srt` captions as a render byproduct
- [ ] Language-variant renders from one script (`cow.es.mp4`, `cow.en.mp4`)

### M7 — Universe + productions  🟡 foundation done  (plan: [`plan-universe.md`](plan-universe.md))
- [x] Characters are a **shared library**: `universes/<id>/characters/*.tscn`, discovered by a
      dynamic `CastRegistry` (scans universes; id = file basename). Leo/Lucas moved here.
- [x] `CharacterData` grew a **bible** (bio, personality, relationships, catchphrases, tags)
- [x] `Universe` resource (`universes/leo_lucas/universe.tres`); `Show.universe` pointer
- [x] Verified: cow renders unchanged via the dynamic registry (no behavior change)
- [x] **Moods** (`domains/mood/`): trickle-down preset resolved scene `{mood:x}` → episode
      `mood:` → `--mood` → none. Controls **bg tint**, **pace** (beat gaps), and **voice
      delivery** (Piper `length_scale`/`noise_scale`). Built-ins (happy/tense/calm/spooky/manic)
      + `universes/<u>/moods/<id>.tres` overrides. Verified: cookie `{mood: tense}` → slower,
      flatter speech + dim background.
- [ ] Next: **Movie** production type; episode/show **templates**; story stages + outline;
      dock Universe/Characters tabs + auto-derived character history

### M8 — Story graph (multi-path stories)  ⬜  (research done; see progress log)
Prior art: Ink/Twine/Yarn for authoring; formal models (choices-as-edges/nodes, hypertext,
storylets/quality-based, character supernodes). Maps cleanly onto us:
- [ ] **Episodes = nodes, path edges between them**; rendering a branch = pick a path and
      concatenate the episodes along it (one linear video out — no renderer change)
- [ ] Ink-style `->` diverts / choice metadata in `.md`; a `StoryGraph` resource over a season
- [ ] Storylet option: episodes that "unlock" on conditions (reuses the resolution philosophy)
- [ ] Optional Twine-like graph view in the dock; character supernode = our bible + history

---

## Progress log

- **2026-06-28** — Empty Godot 4.7 project (GL Compatibility, 2D stretch). Agreed on
  architecture (data-driven), audio/event model (Clock/Point/Span, dialogue-as-clock),
  and Movie Maker export. Wrote timeline spec + this doc.
- **2026-06-28** — Scaffolded M0: `domains/{character,director,audio,export}`, autoloads
  (`EventBus`, `Log`), `scenes/main.tscn`, project wired (main scene, 1280×720, movie fps 30).
  Director plays a 3-line cookie cold-open with tone-driven mouth flap + subtitles.
- **2026-06-28** — **M0 done.** Verified in Godot 4.7: characters render + flap in sync,
  export produces a playable AVI and auto-quits. Fixes along the way: autoload `Logger`→`Log`
  (clashes with native class in 4.7); spawn cast after first frame (adding during `_ready`
  trips the "parent busy" guard); quit on `--render` user flag (engine eats `--write-movie`
  before script args); export needs a real GL context (xvfb, not `--headless`) and explicit
  `--fixed-fps`.
- **2026-06-28** — Hand-editable character refactor + **M1 core done.** Characters are now
  per-id scenes (`domains/character/cast/*.tscn`) of real shape nodes you edit by hand,
  sharing one `Character` contract (needs `Voice` + `Mouth`); `Mouth` (`mouth.gd`) drives
  flap by scaling one shape or swapping 2+ shapes. `CastRegistry` maps id → scene. Director
  now parses `episodes/cookie.md` → `EpisodeScript` and plays its beats; cast auto-spawned
  and spread. Verified by render. Note: new `class_name` scripts need a project reimport
  (`godot --path . --import`) before headless runs see them in the global class cache.
- **2026-06-28** — **M2 voice core + language model.** Local Piper TTS wired
  (`domains/audio/tts.gd`): per-line synth → 16-bit mono PCM → `AudioStreamWAV`, cached by
  text+voice hash (deterministic), `Tone` fallback when Piper/voice absent. Clock now uses
  real clip length. Language resolution chain implemented at episode/character/line levels
  (`language:` frontmatter, `CharacterData.language`+`voices`, `alias@lang:`). `cow.md`
  verified rendering in real LATAM Spanish (Leo es_MX, Lucas es_AR). Piper binary + voices
  live outside the repo (`~/Apps/piper`, `VIDS_PIPER_BIN` to override). Wrote
  `plan-studio-panel.md` (editor dock + Show/Season model + full language design).
- **2026-06-28** — **M2 done.** Audio event model complete (`AudioLibrary` +
  Director `_fire_event`/`_span`/`_duck_music`): sfx Points (inline w/ optional `+offset`),
  ambience/music Spans (`start`/`stop`, looped), music auto-ducks under dialogue. Parser
  normalizes all directives to beat-shaped events; inline directives on a dialogue line fire
  at line start, standalone ones ride the playhead. Placeholder audio is deterministic
  procedural synth (no `randf()`), names resolve to real files later. `cow.md` verified with
  ambience+music+sfx, ducked, no warnings.
- **2026-06-28** — **M5 core.** `Show`/`Season`/`EpisodeRef` resources (`domains/show/`) +
  `shows/leo_lucas/show.tres` (Season 1: cookie, cow). Studio editor dock
  (`addons/vids_studio/`, enabled in project.godot): season/episode tree with
  Preview/Render/Render-all/Open-output; render shells out to the same CLI via
  `OS.create_process`, polls the PID, persists `status=rendered` back to the `.tres`. Verified
  headlessly — editor mounts the plugin clean, show.tres deserializes, dock render command
  produces `output/cow.avi`. Remaining: in-dock param editing + show/season into the language
  chain + click-through QA.
- **2026-06-28** — **Bilingual cast + show-language wiring.** Cookie was silent-ish (English
  text, cast had only `es` voices → placeholder tone). Gave Leo/Lucas English voices
  (`en_US-ryan-high`, `en_GB-alan-medium`), declared `language: en` on `cookie.md`, and wired
  the show/season default into the Director via a `--language` arg the dock passes (sits below
  the `.md` language in the chain). Cookie now renders in real English speech; cow stays
  Spanish. Cast is multilingual (>1 voice).
- **2026-06-28** — **M7 foundation: Universe.** Reframed the model — a Universe owns reusable
  characters; productions (Shows/Movies) cast from it. Wrote `plan-universe.md` (decisions:
  universe-first, Movies as a production type, moods shape voice too). Built: `Universe`
  resource; `CharacterData` bible fields; **dynamic `CastRegistry`** that scans
  `universes/*/characters/*.tscn` (id = basename); moved Leo/Lucas to
  `universes/leo_lucas/characters/`; `Show.universe` pointer. Cow re-rendered unchanged →
  the dynamic registry resolves cast from the new home.
- **2026-06-28** — **Moods.** Researched branching-narrative prior art first (Ink/Twine/Yarn +
  formal story-graph models) → logged **M8: Story graph** (episodes-as-nodes, render a chosen
  path). Then built moods (`domains/mood/`): a trickle-down preset (scene `{mood:x}` → episode
  `mood:` → `--mood`) setting bg tint + beat pace + Piper voice `length_scale`/`noise_scale`.
  `MoodLibrary` has built-ins (happy/tense/calm/spooky/manic) overridable via
  `universes/<u>/moods/*.tres`. Parser now stamps scene+mood on every beat; `Tts.synth` takes
  delivery params (cache key includes them). Verified: cookie `{mood: tense}` → slower/flatter
  speech + dim bg. **Next: Movie production type, or templates.**

---

## Conventions & guardrails

- **Determinism is non-negotiable** in render paths: fixed timestep, seeded RNG, no `randf()`.
  Re-rendering an episode must be byte-identical.
- Names over paths: scripts reference cast/bg/sfx by **registry name**, never by file path.
- Unknown directives warn-and-skip — scripts stay forward-compatible.
- Preview and Final share one Director; only the timing/audio source differs.

See [`timeline-spec.md`](timeline-spec.md) for the script grammar and beat→seconds resolution.
