# Oralidle — Voice

The design system for a speech-coaching and mock-interview app.

Every colour value in this document was derived numerically against WCAG 2.2
and is stated with its measured contrast ratio. Nothing here is asserted by
eye. Where a value fails a threshold, that is said plainly rather than
rounded away.

---

## 1. Visual Theme & Atmosphere

**The app is an instrument, and the only thing that lights up is the user's
voice.**

Oralidle asks people to do something exposing: speak alone into a microphone
and be measured on it. They usually do it in private, often anxious, often the
night before something that matters. The interface answers that by being
quiet, precise, and encouraging — never clinical, never gamified, and never
loud enough to compete with the thing the user is producing.

Colour is the scarcest resource in this system, and it is spent almost
entirely on one thing: a live trace of the user's amplitude. Because that
trace is generated from their own audio, no competitor can copy it. Every
trace is different. It is the one visual element this product owns outright,
and it recurs as the record meter, the loading state, and the shape of a past
session in history.

**Density:** calm and generous while recording, compact and scannable while
reviewing. The recording screen holds one idea; the results screen holds many.

**Key characteristics**
- Deep petrol canvas. Chroma rationed to almost nothing.
- A four-stop voice ramp that always encodes real microphone amplitude.
- Actions are achromatic. The record control is the sole exception.
- Scores read as measurement and trajectory, never as verdict.

---

## 2. Depth: fills carry hierarchy, borders carry identification

This inversion is the load-bearing decision of the system, so it is stated
first and with its arithmetic.

A dark-on-dark surface ladder **cannot** produce legible depth. The WCAG
luminance formula compresses hard at the bottom of the range: for a surface to
reach even 1.5:1 against a `#08100E` canvas it would have to be `#293431` — a
mid-grey, not a dark surface. 3:1 would require `#4F635E`. Any system that
claims "depth comes from the surface ladder, not from borders" is describing
something that does not survive contact with a contrast checker.

So the two jobs are split:

- **Fills carry hierarchy.** Subtle, ambient, sub-1.3:1. They tell you a card
  is a card. They are not asked to do more than that.
- **Borders carry identification.** Anything the user can *act on* is outlined
  at a ratio that clears WCAG 1.4.11's 3:1 floor for user-interface
  components.

| Token | Hex | vs `canvas` | Role |
|---|---|---|---|
| `canvas` | `#08100E` | — | App background |
| `raised` | `#111A18` | 1.09:1 | Cards, sheets, the default raised plane |
| `raised2` | `#1A2523` | 1.22:1 | Inputs, nested cards, hovered rows |
| `sunken` | `#050B0A` | 1.03:1 | Wells, meter tracks, scrub tracks |
| `line` | `#2A3937` | 1.59:1 | Decorative separation |
| `lineStrong` | `#3E524E` | 2.31:1 | Structural dividers |
| `borderControl` | `#5E736D` | **3.80:1** | Every interactive boundary |

`line` and `lineStrong` are **decorative**. They are legitimate for separating
content, and they are explicitly *not* a WCAG claim — do not use either as the
only thing identifying a control. That is `borderControl`'s job.

### Elevation

| Level | Fill | Border | Shadow |
|---|---|---|---|
| 0 | `canvas` | — | none |
| 1 | `raised` | `line` | none |
| 2 | `raised2` | `borderControl` when interactive, else `line` | none |
| 3 (modal) | `raised2` | `lineStrong` | `0 16px 48px rgba(0,0,0,0.55)` |

**No backdrop blur anywhere.** It is the most-copied effect in this product
category, it costs real frames on web, and the surface ladder plus borders
already communicate everything blur would.

**One permitted glow:** the record control while capturing. It marks "we are
listening" and appears nowhere else.

---

## 3. Chroma budget: colour belongs to the voice

The voice ramp has four stops, not two. A two-ended ramp can tell a speaker
*louder* or *quieter*, but never answers the question they actually have:
**am I in a good range?** The sweet spot needs its own stop.

| Token | Hex | vs `canvas` | Meaning |
|---|---|---|---|
| `voiceRest` | `#55746E` | **3.77:1** | Silence. An unlit meter bar |
| `voiceLow` | `#46C8BC` | 9.40:1 | Quiet — audible, but soft |
| `voiceMid` | `#7BD98A` | 11.12:1 | **The sweet spot** |
| `voicePeak` | `#F2B33F` | 10.36:1 | At the edge — too loud |

`voiceColor(t)` interpolates the ramp for `t` in 0..1. **Any gradient between
these stops must be driven by real amplitude.** Never as decoration, never
across a row by position — colour encodes loudness, so a bar's colour comes
from its own height, not from where it sits.

`voiceRest` is a meaningful graphic, not decoration: a row of unlit bars is
the entire "we're listening, you're silent" signal. It therefore has to clear
3:1, and at 3.77:1 it does.

### Text

| Token | Hex | vs `canvas` | vs `raised` | Role |
|---|---|---|---|---|
| `ink` | `#ECF1EF` | 16.86:1 | 15.53:1 | Primary text. Never pure `#FFF` |
| `inkMuted` | `#A7B7B2` | 9.22:1 | 8.49:1 | Secondary text, labels, timestamps |
| `inkFaint` | `#7C8E89` | 5.58:1 | 5.14:1 | Placeholders, disabled, axis labels |

All three clear 4.5:1 on every surface in the ladder, so any of them is safe
for body copy anywhere. `inkFaint` means *disabled or de-emphasised*, not
"small" — an unselected tab is neither, and gets `inkMuted`.

### Semantic

Hue is reserved for genuine system state. It never renders a score.

| Token | Hex | vs `canvas` | Role |
|---|---|---|---|
| `positive` | `#5FC98F` | 9.39:1 | Confirmed success only (saved, uploaded) |
| `caution` | `#F2B33F` | 10.36:1 | Recoverable problems (mic unavailable, retrying) |
| `critical` | `#E8917F` | 8.06:1 | Destructive or failed. Soft, never alarm-red |

`caution` and `voicePeak` are deliberately the same value. Both mean "you are
at the edge" — in the meter that is volume, in a banner that is system state.
The overlap is coherent rather than accidental.

Semantic colour never travels alone. Per WCAG 1.4.1, every use pairs with an
icon or text.

---

## 4. Actions are achromatic — with exactly one exception

Chroma is spent on the voice, so buttons don't get any. This also means the
primary action is the highest-contrast object on any screen, which is what a
primary action should be.

| Role | Spec | Ratio |
|---|---|---|
| Primary | `action` `#ECF1EF` fill, `onAction` `#08100E` label | **16.86:1** |
| Secondary | `raised2` fill, 1px `borderControl` | 3.80:1 border |
| Destructive | `critical` outline + label, never a filled red block | 8.06:1 |
| Quiet | Label only, `inkMuted` | 8.49:1 |
| Focus ring | `voiceLow`, 2px, on every focusable control | 9.40:1 |

Radius 12, height 48. Labels are Manrope — Bricolage is a display face and
does not belong on a control.

**The exception: the record control.** A single 76px circle, filled `voiceLow`
when idle, `critical` **outlined** when recording. It is the only circular
control in the app, so the shape alone means "record", and it is the only
chromatic control in the app, because it is the one button that is *about your
voice*. Outlining while recording is not stylistic: a white glyph on filled
`critical` measures 2.62:1 and fails, while `critical` on canvas is 8.06:1.

---

## 5. Score is achromatic and relative

Red-to-green pass/fail is wrong here. Someone practising their own voice
should read a number as diagnostic, not as a verdict — and a red 58 is a
reason to close the app.

Encoding score as a position on the voice ramp is worse, and it is worth
naming because it is a tempting mistake: it paints a 95 in `voicePeak`, the
same colour as the warning state.

**A score meter is an `ink` fill on a `sunken` track, with the number set in
tabular mono above it, and a tick marking the user's previous average.**

Colour does no work. Position does. "72" on its own is an unanswerable
question; "72, with the tick at 68" is a trajectory. Every meter pairs with
one concrete next action.

Never a coloured ring. Never a red-to-green gradient.

---

## 6. Categories carry an icon, not a hue

Category is **nominal** data — a set of unordered names. Hue is a
**continuous** channel. Encoding one in the other is a category error that
happens to also be an accessibility failure: nobody reliably distinguishes 11
hues, and to a red-green colour-blind user `#F44336` and `#E91E63` are the
same swatch.

Each category gets a **Lucide icon plus its name**, rendered in the neutral
chip style. The name was already on the card, so this costs nothing and
satisfies "colour is not the only indicator" by not using colour at all.

The same rule governs interview question types. In particular, no question
type is ever painted in `critical` — a LeetCode question is not an error.

---

## 7. Typography

A characterful display face against a neutral body face, plus a mono for
anything measured. The display carries enough warmth that the product does not
read as a grading machine; the body stays out of the way at small sizes on
dark backgrounds; the mono makes the readouts read as instrument readouts.

- **Display:** `Bricolage Grotesque` — weight 600–700, negative tracking
- **Body / UI:** `Manrope` — excellent at 12–16px
- **Data:** `IBM Plex Mono` — every *measured* value

| Style | Family | Size | Weight | Tracking | Use |
|---|---|---|---|---|---|
| Display | Bricolage | 32 | 700 | −0.5 | Screen titles, score headline |
| Title | Bricolage | 22 | 600 | −0.25 | Section and card titles |
| Card title | Bricolage | 16 | 600 | 0 | Card headers |
| Body L | Manrope | 16 | 400 | 0 | Questions, prompts, transcript |
| Body | Manrope | 14 | 400 | 0 | Default UI text |
| Caption | Manrope | 12 | 400 | 0 | Secondary detail |
| Overline | IBM Plex Mono | 12 | 500 | +0.7, upper | Meter labels, chips |
| Readout | IBM Plex Mono | 14 | 500 | 0 | Any measured value |
| Timer | IBM Plex Mono | 56 | 500 | −2 | The recording clock |

**Every mono style sets `FontFeature.tabularFigures()`.** This is not optional
polish: without it a running timer and an animating score shift their own
layout on every frame as glyph widths change.

Body copy runs 1.5–1.6 line height and caps at ~65 characters. The timer drops
from 56 to 44 on short viewports.

---

## 8. Component Stylings

**Waveform (the signature component).** Bars, not a smooth curve — a curve
reads as decoration, discrete bars read as measurement. Bar width 4, gap 3,
radius 2. Height is driven by real RMS amplitude. Colour interpolates the
voice ramp **by amplitude, not by position**. At rest the bars sit low in
`voiceRest`. They never animate on fake data, and under reduced motion they
stop animating but keep reporting level.

**Buttons.** Per §4. Every button has a visible `voiceLow` 2px focus ring.

**Record control.** Per §4. 76px, the only circle in the app.

**Cards.** `raised`, radius 16, 1px `line`. Interactive cards step up to
`raised2` with a `borderControl` border. No blur.

**Score meter.** Per §5.

**Inputs.** `raised2`, 1px `borderControl`, radius 12, `voiceLow` border on
focus.

**Chips.** `raised2`, radius 999, `inkMuted` label in Overline, leading icon.
Selected swaps to a `borderControl` border with `ink` text.

**Every tap target** is at least 48×48, has a visible press response within
80–150ms, and carries an accessible name. Icon-only controls cannot be built
without a tooltip.

---

## 9. Layout Principles

- **Spacing scale:** 4, 8, 12, 16, 24, 32, 48, 64. Nothing between.
- **Radii:** 8 small, 12 controls, 16 cards, 999 pills, 2 waveform bars.
- **Icon sizes:** 14 (inline meta only), 16, 20, 24, 32.
- **Page padding:** 20 compact, 28 medium, 32 expanded.
- **Reading measure:** 760px for prose; 1180px for grids and dashboards.
- **Rhythm:** one idea per screen while recording; multi-column only above
  700px.
- **Whitespace:** the recording screen should feel almost empty. Everything
  that is not the question, the timer, or the waveform is noise.

---

## 10. Motion

Motion either reflects audio or communicates state. There is no third reason.

| Token | Duration | Use |
|---|---|---|
| `press` | 90ms | Tap feedback |
| `fast` | 150ms | Chip and toggle state |
| `base` | 220ms | Card, sheet, meter fill |

Easing is `easeOutCubic` — deceleration on arrival. Exits run at roughly 70%
of the entering duration.

**Reduced motion is honoured everywhere.** When `MediaQuery.disableAnimations`
is set, meters snap to their value, the processing pulse settles, and the
waveform stops its ticker while still reporting level. Data keeps flowing;
only decoration stops.

Never animate `width`/`height` where a transform will do. Never block input
during an animation.

---

## 11. Responsive Behavior

Breakpoints come from `lib/core/utils/responsive.dart`:

| Name | Width | Behaviour |
|---|---|---|
| compact | < 600 | Single column, bottom nav, 20px padding |
| medium | 600–1239 | Two columns above 700, sidebar from 905, 28px padding |
| expanded | ≥ 1240 | Sidebar nav, content capped at 1180, 32px padding |

- Minimum touch target 48×48. The record control is 76.
- The waveform is full-bleed on compact and inset on wider screens.
- Content never scrolls horizontally; wide tables and charts scroll inside
  their own container.
- Layouts hold at 1.5× text scale without overflow.

---

## 12. Do's and Don'ts

**Do**
- Let the waveform be the hero. Give it room.
- Drive every voice-coloured gradient from real amplitude.
- Use tabular figures for anything that counts.
- Identify interactive things with `borderControl`, not with a fill step.
- Pair every score with one concrete next action.
- Pair every semantic colour with an icon or text.

**Don't**
- **No purple or indigo**, and **no gradient fills on controls.** Both are
  the current defaults of AI-product design; this system exists partly to
  avoid them.
- **No glassmorphism or backdrop blur.**
- **No red/green pass-fail scoring**, and no score rendered on the voice ramp.
- No chroma on a control other than the record button.
- No emoji as iconography.
- No decorative motion, and no decorative glow.
- No pure white text or pure black backgrounds.
- No raw hex in a widget. Tokens only.

---

## 13. Agent Prompt Guide

When generating a new screen in this system:

> Build `<screen>` for Oralidle. Canvas `#08100E`; cards `raised` `#111A18`
> with a 1px `line` border and no blur; interactive surfaces step to `raised2`
> `#1A2523` with a `borderControl` `#5E736D` border. Depth comes from borders,
> not from fills or shadows.
> Chroma is reserved for the user's voice: a four-stop ramp from `voiceRest`
> `#55746E` (silent) through `voiceLow` `#46C8BC` (quiet) and `voiceMid`
> `#7BD98A` (ideal) to `voicePeak` `#F2B33F` (too loud), used only where it
> encodes real amplitude. Buttons are achromatic — `action` `#ECF1EF` fill
> with `onAction` `#08100E` text — except the record control, which is
> `voiceLow`.
> Display type is Bricolage Grotesque 600–700 with negative tracking; body is
> Manrope; every measured value is IBM Plex Mono with tabular figures.
> Spacing comes from the 4/8/12/16/24/32/48/64 scale. Show scores as an `ink`
> fill on a `sunken` track with the previous average marked — never a ring,
> never red-to-green. Categories get an icon and a word, never a hue.
> Every tap target is 48×48 with a press response and an accessible name.

Token names for prompts: `canvas`, `raised`, `raised2`, `sunken`, `line`,
`lineStrong`, `borderControl`, `voiceRest`, `voiceLow`, `voiceMid`,
`voicePeak`, `action`, `onAction`, `ink`, `inkMuted`, `inkFaint`, `positive`,
`caution`, `critical`.

---

## 14. Enforcement

`test/design_system_test.dart` greps the source tree and fails CI on: the
retired brand purple, `BackdropFilter`/`ImageFilter.blur`, `Colors.white` and
`Colors.black`, inline `fontSize:`, and any `LinearGradient` or `BoxShadow`
outside an explicit allowlist.

The allowlists are the exceptions this document grants — the record-control
glow, the level-3 modal shadow, and amplitude-driven gradients inside the
waveform painter. Adding to them requires amending this file first.
