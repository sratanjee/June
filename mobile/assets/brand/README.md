# June — brand assets

The "j" mark, finalized. The accent dot is placed at Lora's exact tittle
coordinate (extracted from the glyph itself, not positioned by eye), and the
dot color is the live palette's attention color. All marks are built from the
Lora serif (weight 500) and outlined to vector — no font dependency at render.

## Files

### icon/
| file | use | bg | notes |
|---|---|---|---|
| `icon-1024.png` | **iOS/Android master** | solid ink | 1024×1024, no transparency, full bleed. iOS generates smaller sizes from this. |
| `icon-inverted.svg` | primary mark | ink tile | paper "j", amber tittle — the chosen direction |
| `icon-light-amber.svg` | light, Editorial Calm | cream | ink "j", amber tittle |
| `icon-light-coral.svg` | light, Warm Coral | cream | charcoal "j", coral tittle |
| `icon-white-green.svg` | light, Bold Fintech | white | ink "j", green tittle |
| `icon-mono-dark.svg` | single-color | ink tile | no accent dot |
| `icon-mono-light.svg` | single-color | cream | no accent dot |
| `notification-silhouette.svg` | Android notification | transparent | white "j" silhouette, no tile |

### wordmark/
| file | use |
|---|---|
| `wordmark-ink-amber.svg` | primary lockup (Editorial Calm) — SVG master |
| `wordmark-charcoal-coral.svg` | Warm Coral palette |
| `wordmark-mono-ink.svg` / `-paper.svg` | single-color |
| `wordmark-ink-amber@1x/@2x/@3x.png` | raster fallback |

### splash/
| file | use |
|---|---|
| `splash-1152.png` | **splash master**, 1152×1152, content inside central 768×768 safe area |
| `splash-1152.svg` | editable source |

## Palette swap
The accent dot is the only colored element. To match whichever palette ships:
- Editorial Calm → amber `#BA7517`
- Warm Coral → coral `#E45D52`
- Bold Fintech → green `#00C853`

Ink `#10182B` / paper `#FBF8F2` (or charcoal `#1F1816` / cream `#FAF5EE` for
the warm-coral palette).

## Notes for final polish
SVGs are production-clean but the wordmark kerning and the icon's optical
centering are worth one human pass in Figma/Illustrator before shipping —
particularly the spacing between the j and u.
