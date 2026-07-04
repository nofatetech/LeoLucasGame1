# media/ — presentation assets (slides & clips)

Drop images and video clips here; reference them by bare name in a script:

```
[slide: quarterly_chart]     # resolves quarterly_chart.png|webp|jpg|svg here
[slide: intro_clip]          # resolves intro_clip.ogv
leo: As you can see...
[slide: stop]                # clear the current slide
```

- **Images:** `png` / `webp` / `jpg` / `svg` (use PNG/WebP with alpha for cutouts).
- **Video:** `ogv` (Ogg Theora) — Godot plays this natively. Convert other formats in
  first (see the Studio dock's media-convert action / plan-moviemaking media notes).
- You may also pass a direct `res://...` path (e.g. `[slide: res://icon.svg]`).
- A name with no matching file renders a labelled **placeholder card**, so a script
  always renders before the art exists (same philosophy as the audio placeholders).

One slide shows at a time; a new `[slide: ...]` replaces the current one. Slides sit on the
set (in front of the backdrop, behind the cast) and are tinted by the active grade/style.
