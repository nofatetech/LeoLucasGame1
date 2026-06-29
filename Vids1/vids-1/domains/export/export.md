# Export (Movie Maker mode)

Godot renders **deterministically frame-by-frame** with synced audio when launched with
`--write-movie`. Real time is ignored — a slow frame just takes longer to write, output FPS
is fixed (`editor/movie_writer/fps`, set to 30 in `project.godot`).

## Render the current episode to a video

```bash
# AVI (MJPEG) is the built-in writer; transcode to mp4 with ffmpeg after.
# --fixed-fps sets the output frame rate; --render (after --) tells the Director to quit.
godot --path . --fixed-fps 30 --write-movie out.avi res://scenes/main.tscn -- --render

# then, optionally:
ffmpeg -i out.avi -c:v libx264 -pix_fmt yuv420p -c:a aac out.mp4
```

The Director quits automatically when `--render` is passed (it checks
`OS.get_cmdline_user_args()` — args after `--`, which the engine always preserves). Quitting is
what stops the writer and finalizes the file. In the editor (no flag) it plays through and
leaves the window open for iteration.

Two gotchas learned the hard way:

- **Don't use `--headless`** for export — the dummy renderer has no framebuffer and crashes
  Movie Maker (signal 11 in `dummy/storage`). A real GL context is required; on a headless box
  use `xvfb-run -a -s "-screen 0 1280x720x24" godot ...` (software llvmpipe works fine).
- **Pass `--fixed-fps` explicitly.** The `editor/movie_writer/fps` project setting is only
  forwarded when you launch from the editor's Movie Maker; a direct CLI run defaults to 60
  unless you pass `--fixed-fps`.

## Settings that matter

- `editor/movie_writer/fps` — output frame rate (30).
- `editor/movie_writer/mjpeg_quality` — 0..1, AVI quality vs size.
- Determinism guardrails (see `docs/README.md`): no `randf()` in render paths, fixed timestep.

## Roadmap

- M0: AVI out of the hardcoded scene (this).
- M2: real per-line audio mixed onto the dialogue bus before render.
- M3: per-episode output naming + thumbnail/description emitted alongside the video.
