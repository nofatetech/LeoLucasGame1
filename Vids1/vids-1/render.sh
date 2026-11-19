#!/usr/bin/env bash
# render.sh - render an episode to MP4 from the command line (same steps as the Studio dock).
#
#   ./render.sh <episode> [style] [--lang <code>]
#
#   <episode>  name (cow), file (cow.md) or path (episodes/cow.md)
#   [style]    wide | vertical | square | anaglyph | bw | crt | a universe style id.
#              Explicit styles suffix the output (output/cow_vertical.mp4) so they never
#              overwrite the default render. Without it, the episode's own `style:` applies.
#   --lang     fallback language below the script's own `language:`
#
# Output: output/<episode>[_<style>].mp4 (AVI kept only if ffmpeg is missing).
# Needs a display: Movie Maker can't rasterize under --headless. On a box without one,
# xvfb-run is used when installed.
set -euo pipefail
cd "$(dirname "$0")"

usage() { sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-1}"; }
die() { echo "render.sh: $*" >&2; exit 1; }

episode="" style="" lang=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage 0 ;;
    --lang) [[ $# -ge 2 ]] || die "--lang needs a value"; lang="$2"; shift 2 ;;
    -*) die "unknown option $1" ;;
    *) if [[ -z "$episode" ]]; then episode="$1"; elif [[ -z "$style" ]]; then style="$1"
       else die "too many arguments"; fi; shift ;;
  esac
done
[[ -n "$episode" ]] || usage

# --- resolve the episode file ---
case "$episode" in
  *.md) [[ -f "$episode" ]] || episode="episodes/$(basename "$episode")" ;;
  *)    episode="episodes/$episode.md" ;;
esac
[[ -f "$episode" ]] || die "episode not found: $episode (have: $(ls episodes | sed 's/\.md$//' | tr '\n' ' '))"
name="$(basename "$episode" .md)"

# --- resolve the style's resolution (single source: universe .tres, then StyleLibrary.BUILTIN) ---
effective="$style"
if [[ -z "$effective" ]]; then   # episode frontmatter `style:` (between the first two --- lines)
  effective="$(awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f&&/^style:/{sub(/^style:[ \t]*/,"");gsub(/["\x27]/,"");print}' "$episode")"
fi
resolution=""
if [[ -n "$effective" ]]; then
  tres="$(ls universes/*/styles/"$effective".tres 2>/dev/null | head -1 || true)"
  if [[ -n "$tres" ]]; then
    resolution="$(sed -nE 's/^resolution = Vector2i\(([0-9]+), *([0-9]+)\).*/\1 \2/p' "$tres")"
  elif grep -q "^\s*\"$effective\":" domains/style/style_library.gd; then
    resolution="$(sed -nE "s/^\s*\"$effective\":\s*\[Vector2i\(([0-9]+), *([0-9]+)\).*/\1 \2/p" domains/style/style_library.gd)"
  else
    builtins="$(sed -nE 's/^\s*"([a-z_]+)":\s*\[Vector2i.*/\1/p' domains/style/style_library.gd | tr '\n' ' ')"
    die "unknown style '$effective' (built-in: $builtins; or universes/<u>/styles/<id>.tres)"
  fi
  [[ "$resolution" == "0 0" ]] && resolution=""   # shader-only style: keep project size
fi

# --- display ---
runner=()
if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
  command -v xvfb-run >/dev/null || die "no display: run in a desktop session, or install xvfb (xvfb-run)"
  runner=(xvfb-run -a)
fi
command -v godot >/dev/null || die "godot not on PATH"

# --- override.cfg: Movie Maker bakes the viewport size at launch ---
[[ -e override.cfg ]] && die "override.cfg already exists (a render in progress, or a leftover?); remove it first"
cleanup() { rm -f override.cfg; }
trap cleanup EXIT
if [[ -n "$resolution" ]]; then
  read -r w h <<<"$resolution"
  printf '[display]\n\nwindow/size/viewport_width=%s\nwindow/size/viewport_height=%s\n' "$w" "$h" > override.cfg
fi

# --- render ---
mkdir -p output
out="output/$name${style:+_$style}"
user_args=(--render --episode "res://$episode")
[[ -n "$style" ]] && user_args+=(--style "$style")
[[ -n "$lang" ]] && user_args+=(--language "$lang")
echo "render.sh: $episode → $out.mp4 (style: ${effective:-default}${resolution:+, ${resolution/ /×}})"
rm -f "$out.avi"
"${runner[@]}" godot --path . --fixed-fps 30 --write-movie "$out.avi" res://scenes/main.tscn \
  -- "${user_args[@]}" 2>&1 | grep -E "Director|Done recording|frames at|ERROR|WARNING" || true
[[ -s "$out.avi" ]] || die "render produced no video ($out.avi missing or empty)"

# --- transcode ---
if command -v ffmpeg >/dev/null; then
  ffmpeg -loglevel error -y -i "$out.avi" -c:v libx264 -pix_fmt yuv420p -c:a aac -movflags +faststart "$out.mp4"
  rm -f "$out.avi"
  echo "render.sh: done → $out.mp4"
else
  echo "render.sh: ffmpeg not on PATH; kept $out.avi (MJPEG, plays poorly in browsers)"
fi
