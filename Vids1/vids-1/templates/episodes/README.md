# Format skeletons

A **format** is a story *shape* — the beat structure of an episode, independent of who's in it
(cast), how it looks (style), or where it's set (universe). Each file here is a parser-valid
episode you copy and fill in.

## Use one
- **In the Studio dock:** click **New…**, pick a format. It copies the skeleton into
  `episodes/new_<format>.md` and adds it to the show, ready to edit and Render.
- **By hand / in Obsidian:** copy a file into `episodes/`, rename it, and rewrite the lines.

## Anatomy
- `# ...` lines are comments — guidance for you, skipped by the parser (except `## Scene:`).
- `{{...}}` are fill-ins. Replace every one before rendering (they're spoken literally if left).
- `cast: { role: id }` maps a format's generic role (e.g. `host`) to a real character id in your
  universe. The skeletons map to `leo`/`lucas` so they render out of the box.
- Frontmatter `style:` is a suggestion (`promo` → `vertical`); override per render in the dock.

## Current set
| Format | Shape | Best for |
|--------|-------|----------|
| `promo` | hook → problem → features → CTA | ads, including the Vids1 self-promo |
| `fable` | narrator frames a two-character moral tale | the (coming) `aesop` content pack |
| `interview` | host asks, guest answers | fake-expert / explainer bits |

Add a format by dropping a new `.md` here — it shows up in **New…** automatically.
