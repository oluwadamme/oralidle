# Oralidle — Level

An original design system for a speech-coaching and mock-interview app.
Written in the `DESIGN.md` convention (9 sections) so an agent can generate
new screens that stay coherent. It is not derived from any other product's
visual identity.

---

## 1. Visual Theme & Atmosphere

**The user's voice is the only thing that glows, and its colour means something.**

Oralidle asks people to do something exposing: speak alone into a microphone
and be measured on it. The interface answers that by getting out of the way.
The canvas is a deep petrol studio with no chrome competing for attention, and
the single luminous element on any screen is the thing the user is producing —
their voice, drawn as a live level trace.

That trace is the whole design language, not one widget on one screen. An
amplitude trace is the app's only ornament, and it recurs as the record meter,
the loading state, the divider between sections, and the shape of a past
session in history. Because it is generated from the user's own audio, no
competitor can copy it — every trace is different, and it is the one visual
element this product owns outright.

**Density:** calm and generous while recording, compact and scannable while
reviewing. The recording screen holds one idea; the results screen holds many.

**Mood:** warm, encouraging, precise. Not clinical, not gamified.

**Key characteristics**
- Deep petrol canvas; chroma is rationed to almost nothing.
- A two-ended level ramp that always encodes real microphone amplitude.
- Waveform as recurring motif, never as decoration.
- Scores read as intensity, not as pass/fail.

---

## 2. Color Palette & Roles

Chroma is scarce on purpose. A screen should be greyscale plus level.

### Canvas & surfaces
A deep petrol green, not a neutral near-black. Near-black plus one bright
accent is the default look of AI products right now; the hue shift is the
point.

| Token | Hex | Role |
|---|---|---|
| `canvas` | `#0E1513` | App background. Deep petrol. |
| `surface-1` | `#141C1A` | Cards, sheets, the default raised plane. |
| `surface-2` | `#1B2422` | Inputs, nested cards, hovered rows. |
| `surface-3` | `#243230` | Pressed states, scrub tracks, chart gridlines. |
| `hairline` | `#FFFFFF` @ 8% | Every border. One weight only. |

### Level — a ramp, not an accent

Colour is reserved for loudness. There is no single decorative brand colour:
the palette is greyscale plus a two-ended ramp that always encodes how loudly
someone is speaking.

| Token | Hex | Role |
|---|---|---|
| `level-low` | `#4FB8A8` | Conversational volume. Doubles as the primary action colour. |
| `level-high` | `#E8A33D` | Peak. Appears only at the loudest moments of a take. |
| `level-rest` | `#2C4642` | An unlit meter bar. Silence. |
| `on-level` | `#06110F` | Text and icons on a level-filled surface. |

`levelColor(t)` interpolates the ramp. Any gradient between these two must be
driven by real amplitude — never used as decoration.

### Text
| Token | Hex | Role |
|---|---|---|
| `ink` | `#E6E9E5` | Primary text. Never pure `#FFF`. |
| `ink-muted` | `#8FA09B` | Secondary text, labels, timestamps. |
| `ink-faint` | `#6B7A76` | Placeholders, disabled, axis labels. |

### Score & semantic
Scores are shown as **fill and intensity**, not as red/green judgement. A
person practising their own voice should read a number as diagnostic, not as a
verdict. Hue is reserved for genuine system states.

| Token | Hex | Role |
|---|---|---|
| `score-track` | `#243230` | Unfilled portion of any score meter. |
| `score-fill` | `levelColor(score/100)` | Filled portion. The score is a position on the ramp, so it carries no red and reads as a measurement. |
| `positive` | `#5BC38C` | Confirmed success only (saved, uploaded). Muted on purpose. |
| `warning` | `#E8A33D` | Recoverable problems (mic unavailable, retrying). |
| `danger` | `#E08A7E` | Destructive or failed. Soft, never alarm-red. |

---

## 3. Typography Rules

A characterful display face against a neutral, highly legible body face. The
display carries warmth so the product does not read as a grading machine; the
body stays out of the way at small sizes on dark backgrounds.

- **Display:** `Bricolage Grotesque` — a variable grotesque with real character
  in its apertures; weight 600–700, negative tracking.
- **Body / UI:** `Manrope` — neutral geometric sans, excellent at 12–16px.
- **Data:** `IBM Plex Mono` — every *measured* value (timer, wpm, score, filler
  count) is set in mono. This is an instrument, and instruments have readouts.

| Style | Family | Size | Weight | Tracking | Use |
|---|---|---|---|---|---|
| Display | Bricolage Grotesque | 32 | 700 | −0.5 | Screen titles, score headline |
| Title | Bricolage Grotesque | 22 | 600 | −0.25 | Section and card titles |
| Body L | Manrope | 16 | 400 | 0 | Questions, prompts, transcript |
| Body | Manrope | 14 | 400 | 0 | Default UI text |
| Label | IBM Plex Mono | 12 | 500 | +0.7, uppercase | Meter labels, chips, overlines |
| Timer | IBM Plex Mono | 56 | 500 | −2, tabular | The recording clock |

Body copy runs 1.5–1.6 line height and caps at ~65 characters.

---

## 4. Component Stylings

**Waveform (the signature component).** Bars, not a smooth curve — a smooth
curve reads as decoration, discrete bars read as measurement. Bar width 4,
gap 3, radius 2. Height is driven by real RMS amplitude. Colour interpolates
`level-low → level-high` **by amplitude, not by position** — a gradient across
the row would only decorate. At rest the bars sit low in `level-rest`; they
never animate on fake data.

**Buttons.** Primary is a `level-low` fill with `on-level` text, radius 12,
height 48. Secondary is `surface-2` with a `hairline` border. Destructive is a
`danger` outline, never a filled red block. Every button has a visible focus
ring in `level-low` at 2px.

**Record control.** A single 76px circle, `level-low` filled when idle, `danger`
outlined when recording. It is the only circular control in the app, so the
shape itself means "record".

**Cards.** `surface-1`, radius 16, 1px `hairline` border, and **no backdrop
blur**. Depth comes from the surface ladder, not from glass.

**Score meter.** A horizontal track in `score-track` with a `score-fill` bar
and the number set in tabular figures above it. Never a coloured ring, never a
red-to-green gradient.

**Inputs.** `surface-2`, 1px `hairline`, radius 12, `level-low` border on focus.

**Chips.** `surface-2`, radius 999, `ink-muted` label; selected state swaps to
`level-rest` background with `ink` text.

---

## 5. Layout Principles

- **Spacing scale:** 4, 8, 12, 16, 24, 32, 48, 64. Nothing between.
- **Page padding:** 20 compact, 28 medium, 32 expanded.
- **Reading measure:** 760px for prose; 1180px for grids and dashboards.
- **Rhythm:** one idea per screen while recording; multi-column only above
  700px.
- **Whitespace:** the recording screen should feel almost empty. Resist filling
  it. Everything that is not the question, the timer, or the waveform is noise.

---

## 6. Depth & Elevation

Depth is communicated by **surface lightness and hairlines**, not by shadow or
blur. Backdrop blur is explicitly retired: it is the most-copied effect in this
product category and it costs real frames on web.

| Level | Surface | Border | Shadow |
|---|---|---|---|
| 0 | `canvas` | — | none |
| 1 | `surface-1` | `hairline` | none |
| 2 | `surface-2` | `hairline` | none |
| 3 (modal) | `surface-2` | `hairline` | `0 16px 48px rgba(0,0,0,0.5)` |

The one permitted glow: the record control and live waveform may cast a soft
`level` glow while capturing. It marks "we are listening" and appears nowhere
else.

---

## 7. Do's and Don'ts

**Do**
- Let the waveform be the hero. Give it room.
- Drive every level-coloured gradient from real amplitude.
- Use tabular figures for anything that counts.
- Pair every score with one concrete next action.
- Keep chroma rationed — greyscale plus the level ramp.

**Don't**
- **No purple gradients**, and **no near-black canvas with one bright accent**.
  Both are current AI-design defaults; this system exists to avoid them.
- **No glassmorphism / backdrop blur.** Use the surface ladder.
- **No red/green pass-fail scoring.** Intensity, not verdict.
- No more than one accent hue on a screen.
- No emoji as iconography.
- No decorative motion. Motion either reflects audio or communicates state.
- No pure white text or pure black backgrounds.

---

## 8. Responsive Behavior

Breakpoints match `lib/core/utils/responsive.dart`:

| Name | Width | Behaviour |
|---|---|---|
| compact | < 600 | Single column, bottom nav, 20px padding. |
| medium | 600–1239 | Two-column above 700, sidebar from 905, 28px padding. |
| expanded | ≥ 1240 | Sidebar nav, content capped at 1180, 32px padding. |

- Minimum touch target 48×48 — the record control is 76.
- The waveform is full-bleed on compact and inset on wider screens.
- The recording timer drops from 56 to 44 on short viewports.
- Content never scrolls horizontally; wide tables and charts scroll inside
  their own container.

---

## 9. Agent Prompt Guide

When generating a new screen in this system:

> Build `<screen>` for Oralidle. Canvas `#0E1513` (deep petrol), cards
> `surface-1` `#141C1A` with a 1px 8% white hairline and no blur. Chroma is
> rationed: greyscale plus a level ramp from `#4FB8A8` (quiet) to `#E8A33D`
> (peak), used only where it encodes loudness. Display type is Bricolage
> Grotesque 600–700 with negative tracking; body is Manrope; every measured
> value is IBM Plex Mono, tabular.
> Spacing comes from the 4/8/12/16/24/32/48/64 scale. If the screen involves
> audio, the amplitude waveform is the hero and must be driven by real level
> data. Show scores as fill intensity on a neutral track — never red/green.
> No purple, no glassmorphism, no decorative gradients.

Colour references for prompts: `canvas`, `surface-1..3`, `hairline`,
`level-low`, `level-high`, `level-rest`, `on-level`, `ink`, `ink-muted`,
`ink-faint`, `score-track`, `score-fill`, `positive`, `warning`, `danger`.
