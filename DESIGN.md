# Oralidle — Warm Signal

The design system for a speech-coaching and mock-interview app.

Every colour value in this document was derived numerically against WCAG 2.2
and is stated with its measured contrast ratio. Nothing here is asserted by
eye. Where a value fails a threshold, that is said plainly rather than
rounded away.

---

## 1. Visual Theme & Atmosphere

**Warm, confident, and encouraging — a coach, not a grading machine.**

Oralidle asks people to do something exposing: speak alone into a microphone
and be measured on it. They usually do it in private, often anxious, often the
night before something that matters. A cold, clinical interface makes that
worse. So the canvas is a warm umber-black rather than a neutral or cool one,
and the product carries a real accent that shows up wherever the user is meant
to act.

Two colour systems coexist, and keeping them apart is the whole discipline:

- **The accent** — apricot — is the brand. It marks primary actions, active
  navigation, selected state, score fills, and section markers. It is used
  generously, because an interface with no colour reads as unfinished rather
  than restrained.
- **The voice ramp** is cool where everything else is warm, and encodes real
  microphone amplitude and nothing else. Because it never appears except as
  measurement, the waveform can never be mistaken for decoration.

**Density:** calm and generous while recording, compact and scannable while
reviewing. The recording screen holds one idea; the results screen holds many.

**Key characteristics**
- Warm umber canvas with a real accent, used freely.
- A four-stop cool voice ramp that always encodes real amplitude.
- Scores read as measurement and trajectory, never as verdict.
- Hierarchy is earned by size and placement, not by making everything loud.

---

## 2. Depth: fills carry hierarchy, borders carry identification

This inversion is the load-bearing decision of the system, so it is stated
first and with its arithmetic.

A dark-on-dark surface ladder **cannot** produce legible depth. The WCAG
luminance formula compresses hard at the bottom of the range: for a surface to
reach even 1.5:1 against a `#16110F` canvas it would have to be `#382E2A` — a
mid-brown, not a dark surface. 3:1 would require `#5C4E48`. Any system that
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
| `canvas` | `#16110F` | — | App background. Warm umber-black |
| `raised` | `#221A17` | 1.10:1 | Cards, sheets, the default raised plane |
| `raised2` | `#2E2320` | 1.23:1 | Inputs, nested cards, hovered rows |
| `sunken` | `#0E0A09` | — | Wells, meter tracks, scrub tracks |
| `line` | `#3A2D28` | — | Decorative separation |
| `lineStrong` | `#4E3E37` | — | Structural dividers |
| `borderControl` | `#8A756B` | 4.31:1 | Every interactive boundary. **3.51:1 on `raised2`** |

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

## 3. Colour: an accent for the product, a ramp for the voice

### The accent

| Token | Hex | vs `raised2` | Role |
|---|---|---|---|
| `accent` | `#FF8A5B` | 6.56:1 | Primary actions, active nav, selected state, score fills |
| `accentSoft` | `#FFB392` | 8.80:1 | Hover, subtle marks |
| `onAccent` | `#2B1206` | **7.58:1 on `accent`** | Label on an accent fill |

Use it freely. A browse screen with no accent on it is a bug, not restraint.
What the accent must **not** do is encode a measurement — that is the ramp's
job.

### The voice ramp

Four stops, because a speaker's real question is not *louder or quieter* but
**am I in a good range?** The sweet spot needs its own stop.

| Token | Hex | vs `raised2` | Meaning |
|---|---|---|---|
| `voiceRest` | `#856F66` | 3.24:1 | Silence. An unlit meter bar |
| `voiceLow` | `#58C7D4` | 7.65:1 | Quiet — audible, but soft |
| `voiceMid` | `#5FD9A4` | 8.67:1 | **The sweet spot** |
| `voicePeak` | `#E03131` | 3.38:1 | At the edge — too loud |

The ramp is **cool where the interface is warm**, so the waveform reads as
instrumentation rather than brand furniture. `voicePeak` is a true red, not an
orange, so it can never be confused with `accent` — the two appear together on
the recording screen.

`voiceColor(t)` interpolates the ramp. **Any gradient between these stops must
be driven by real amplitude** — never by position, never as decoration.

### Text

| Token | Hex | vs `canvas` | vs `raised2` | Role |
|---|---|---|---|---|
| `ink` | `#F5EFEA` | 16.43:1 | 13.37:1 | Primary text. Never pure `#FFF` |
| `inkMuted` | `#B0A099` | 7.43:1 | 6.05:1 | Secondary text, labels, timestamps |
| `inkFaint` | `#9C8B82` | 5.73:1 | 4.67:1 | Placeholders, disabled |

### Semantic

| Token | Hex | vs `raised2` | Role |
|---|---|---|---|
| `positive` | `#4FC98A` | 7.30:1 | Confirmed success only |
| `caution` | `#F5B93C` | 8.63:1 | Recoverable problems |
| `critical` | `#E03131` | 3.38:1 | Destructive or failed |

`critical` and `voicePeak` are the same value: both mean "you are at the edge".
Semantic colour never travels alone — every use pairs with an icon or text.

---

## 4. Actions

| Role | Spec | Ratio |
|---|---|---|
| Primary | `accent` fill, `onAccent` label | **7.58:1** |
| Secondary | `raised2` fill, 1px `borderControl` | 3.51:1 border |
| Destructive | `critical` outline + label, never a filled red block | — |
| Quiet | Label only, `inkMuted` | 6.05:1 |
| Focus ring | `accent`, 2px, on every focusable control | 6.56:1 |

Radius 12, height 48. Labels are Bricolage at weight 600.

**Buttons size to their content by default.** A full-bleed button is a claim
that it is the single most important thing on the screen, so `expand` is opt-in
and belongs to at most one control per view. A shortcut ("Surprise me"), an
upsell, or anything competing with the screen's real content takes the
secondary treatment. Two full-width primaries on one screen is a bug.

**The record control** is a 76px circle — the only circular control in the app,
so the shape alone means "record". `accent` filled when idle, `critical`
**outlined** while recording. Outlining is not stylistic: a glyph on filled
`critical` fails contrast, while `critical` on the canvas clears it
comfortably. It carries the one permitted glow, and only while capturing.

---

## 5. Score reads in bands, and relative to your own average

A score meter is a fill on a `sunken` track, with the number above it and a
tick marking the user's previous average.

### Bands

The fill and the readout take the band the score falls in, so a breakdown is
scannable without reading every number:

| Band | Token | Hex |
|---|---|---|
| under 40 | `scoreLow` | `#E0705C` |
| 40–59 | `scoreFair` | `#F0894B` |
| 60–79 | `scoreGood` | `#E2C24E` |
| 80+ | `scoreHigh` | `#4FC98A` |

This is a deliberate reversal of an earlier rule in this document, which held
that colour must never grade. The argument against banding is real — a red 58
is a discouraging thing to show someone practising — and it is recorded here so
nobody re-litigates it by accident. It was overridden because an all-one-hue
breakdown gave the reader no way to triage six numbers at a glance.

The mitigations that make it acceptable:

- The low band is a **soft coral**, not an alarm red, and the ramp passes
  through the brand's own orange rather than jumping red-to-green.
- Colour is never the only signal: the number and the bar length both carry
  the value, per WCAG 1.4.1.
- Every score is paired with `previousAverage`, so the meter reports a
  **trajectory** rather than a verdict — "46, and your average is 62" is
  actionable in a way that "46" alone is not.

### Never

The score bands must never borrow the **voice ramp**. Those two systems mean
different things, and an earlier version of this product painted a 95 in the
same amber it used for "too loud". Never a ring, and never a raw red-to-green
two-stop gradient.

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

**One family: `Bricolage Grotesque`.** A single variable grotesque carries the
whole system, from a 32px screen title down to an 11px meter label. Hierarchy
comes from size, weight and tracking rather than from a change of voice, which
keeps the interface feeling like one object — appropriate for something
presented as an instrument.

| Style | Size | Weight | Tracking | Use |
|---|---|---|---|---|
| Display | 32 | 700 | −0.5 | Screen titles, score headline |
| Title | 22 | 600 | −0.25 | Section and card titles |
| Card title | 16 | 600 | 0 | Card headers |
| Body L | 16 | 400 | 0 | Questions, prompts, transcript |
| Body | 14 | 400 | 0 | Default UI text |
| Caption | 12 | 400 | 0 | Secondary detail |
| Overline | 12 | 500 | +0.7, upper | Meter labels, chips |
| Readout | 14 | 500 | 0 | Any measured value |
| Timer | 56 | 500 | −2 | The recording clock |

### Measured values need fixed-width slots

Bricolage Grotesque is proportional, so a `1` is narrower than a `0`. Any
number that changes while on screen — the recording timer, an animating score,
a live word count — will therefore shift its own layout on every update. A
clock that jitters as it counts is the single most visible way for an
instrument to look cheap.

`FontFeature.tabularFigures()` does not solve this here: it is a request the
font is free to ignore, and a proportional grotesque generally does.

**So changing numbers are laid out in fixed-width slots instead**, via
`TabularText`, which measures the widest digit at the given style and gives
every character an identical box. Static numbers can be set normally; only
values that update in place need it.

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
- Let the waveform be the hero on the recording screen. Give it room.
- Drive every voice-coloured gradient from real amplitude.
- Use the accent freely on actions, active state, and section markers.
- Set any number that changes in place in `TabularText`.
- Identify interactive things with `borderControl`, not with a fill step.
- Pair every score with one concrete next action.
- Pair every semantic colour with an icon or text.

**Don't**
- **No purple or indigo**, and **no gradient fills on controls.** Both are the
  current defaults of AI-product design; this system exists partly to avoid
  them.
- **No glassmorphism or backdrop blur.**
- **No score rendered on the voice ramp**, and no raw red-to-green two-stop
  gradient — scores use the four bands in §5.
- **No more than one full-bleed primary action per screen.**
- No warm colour in the voice ramp other than `voicePeak`, and no accent used
  to encode a measurement.
- No emoji as iconography.
- No decorative motion, and no decorative glow.
- No pure white text or pure black backgrounds.
- No raw hex in a widget. Tokens only.
  the current defaults of AI-product design; this system exists partly to
  avoid them.
- **No glassmorphism or backdrop blur.**
- **No score rendered on the voice ramp**, and no raw red-to-green two-stop
  gradient — scores use the four bands in §5.
- No chroma on a control other than the record button.
- No emoji as iconography.
- No decorative motion, and no decorative glow.
- No pure white text or pure black backgrounds.
- No raw hex in a widget. Tokens only.

---

## 13. Agent Prompt Guide

When generating a new screen in this system:

> Build `<screen>` for Oralidle. Canvas `#16110F` (warm umber-black); cards
> `raised` `#221A17` with a 1px `line` border and no blur; interactive surfaces
> step to `raised2` `#2E2320` with a `borderControl` `#8A756B` border. Depth
> comes from borders, not from fills or shadows.
> The brand accent is apricot `#FF8A5B` with `onAccent` `#2B1206` on top, and
> it is used generously — primary actions, active navigation, selected state,
> score fills, section markers. Buttons size to their content; at most one
> full-bleed primary per screen.
> Amplitude uses a separate cool ramp — `voiceRest` `#856F66`, `voiceLow`
> `#58C7D4`, `voiceMid` `#5FD9A4` (ideal), `voicePeak` `#E03131` (too loud) —
> and only ever encodes real level.
> Type is Bricolage Grotesque throughout, hierarchy from size and weight; any
> number that updates in place is wrapped in `TabularText`.
> Spacing comes from the 4/8/12/16/24/32/48/64 scale. Show scores as an accent
> fill on a `sunken` track with the previous average marked — never a ring,
> never red-to-green. Categories get an icon and a word, never a hue.
> Every tap target is 48×48 with a press response and an accessible name.

Token names for prompts: `canvas`, `raised`, `raised2`, `sunken`, `line`,
`lineStrong`, `borderControl`, `accent`, `accentSoft`, `onAccent`, `voiceRest`,
`voiceLow`, `voiceMid`, `voicePeak`, `ink`, `inkMuted`, `inkFaint`, `positive`,
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
