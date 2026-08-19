# Lumina Speech

Speech fluency coach and mock-interview practice, built with Flutter.
Runs on iOS, Android, macOS and the web.

## Getting started

```bash
flutter pub get
flutter run
```

Create a `.env` in the project root:

```
GEMINI_API_KEY=<your key>
```

### Required once per machine: native assets

On-device speech-to-text is delivered through `flutter_gemma_speech`, whose
native LiteRT runtime arrives as a **CodeAsset** produced by a build hook.
Flutter only runs those hooks when the feature is switched on:

```bash
flutter config --enable-native-assets
```

Without it the app still builds and runs, and recording still works — but the
native library is never bundled, `getActiveStt()` fails at load time with
`LiteRtLm framework/dylib not found`, and the app falls back to transcribing
server-side with no live preview. The failure is easy to miss precisely
because everything else keeps working. This is a machine-level Flutter
setting, so it is not captured by the repository and every developer and CI
runner needs it.

### Platform support for on-device transcription

| Platform | On-device preview | Notes |
|----------|-------------------|-------|
| iOS      | ✅ verified        | ~712 ms to decode 8.6 s of speech |
| Android  | untested          | Same FFI path as iOS |
| macOS    | ❌ does not load   | Upstream packaging gap, see below |
| Web      | ➖ not applicable  | No on-device engine by design |

Recording, upload and Gemini transcription work on **all** of them. Only the
live preview depends on the on-device engine, and its absence is surfaced in
the recording UI rather than failing the session.

#### Why macOS cannot load the engine

`flutter_gemma_litertlm` sets `skipCompanionsOn: {OS.macOS}` in its build
hook, deliberately excluding three Apple dylibs from Native Assets bundling —
Google ships them without `-Wl,-headerpad_max_install_names`, so the
`install_name_tool` step would abort. The package leaves the host app to embed
them and ships that step only in its own example, so a consuming app ends up
with a `LiteRtLm.framework` whose `@rpath/libGemmaModelConstraintProvider.dylib`
load command resolves to nothing.

Embedding the dylib by hand — in `Contents/Frameworks`, inside the framework's
`Versions/A`, and symlinked at the framework root, covering every rpath the
binary declares — did not make dyld resolve it. Worth reporting upstream
rather than working around locally; the app degrades correctly in the meantime.

Requires **iOS 16** (`flutter_gemma`'s floor) and **Android minSdk 24**.
The iOS bump is a product decision: it drops iPhone 6s/7 and the 1st-gen SE.
Dropping on-device transcription is what it would take to go back to iOS 13.

## How audio works

Exactly one component opens the microphone: `AudioCaptureService`. It streams
16 kHz mono 16-bit PCM and fans it out to everything that needs audio:

```
record.startStream()          ← the only microphone client
    ├── buffer  → WAV → Gemini   (authoritative transcript + evaluation)
    ├── chunks  → Moonshine      (live on-device preview; native only)
    └── chunks  → RMS            (waveform meter)
```

Running a second microphone client is a hard conflict — on iOS a second
client reconfigures the shared `AVAudioSession`, on Android `SpeechRecognizer`
holds an exclusive `AudioRecord` — and whichever loses records silence. The
invariant is enforced by `test/architecture/single_microphone_owner_test.dart`.

Uploads are companded to G.711 µ-law, which halves them at no measurable cost
to the transcript. `tool/verify_audio_format.dart` re-runs that comparison
against the live API.

## Tests

```bash
flutter test
```

`tool/verify_stt.dart` drives the real Moonshine pipeline on a device, which
the unit tests deliberately do not — model download, FFI load, and whether the
windows the segmenter cuts reassemble into coherent text:

```bash
say -o /tmp/s.aiff "Um, so basically the main challenge was scaling."
afconvert -f WAVE -d LEI16@16000 -c 1 /tmp/s.aiff /tmp/s.wav
flutter run -d <device> -t tool/verify_stt.dart --dart-define=WAV=/tmp/s.wav
```

## Deploying to Vercel

Pushing to `main` deploys production; a PR into `main` gets a preview URL
commented on the PR. Both run `flutter test` first and refuse to deploy if it
fails. See [.github/workflows/deploy.yml](.github/workflows/deploy.yml).

Flutter runs on the GitHub runner, not on Vercel: the workflow does
`vercel build` there and ships the finished output with
`vercel deploy --prebuilt`, so Vercel never needs a Flutter toolchain.

### Where the API key lives

A web build is static files in a browser, so anything it carries is public.
`.env` is a declared Flutter asset, which means a bundled key would be served
at `/assets/.env` to anyone who visits.

So the key is **not in the app**. [`api/gemini.js`](api/gemini.js) holds it
server-side and forwards requests to Google; the web app posts to
`/api/gemini` instead. [`AiEndpoint`](lib/core/config/ai_endpoint.dart) is the
single place that decides this:

| Build | Endpoint | Carries a key |
|-------|----------|---------------|
| Web | `/api/gemini` (same origin) | no |
| Native, default | Google directly | yes, from `.env` |
| Native with `--dart-define=API_PROXY_BASE=…` | that proxy | no |

CI copies `.env.example` over `.env` before building — the file must exist
because it is a declared asset, and an empty one ships nothing. The workflow
then greps the build output for key-shaped strings and fails the deploy if it
finds any.

### One-time setup

1. `vercel link` to create the project.
2. GitHub repo secrets: `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`
   (the last two come from `.vercel/project.json`).
3. Vercel environment variables, for **both** Production and Preview:
   - `GEMINI_API_KEY` — the real key
   - `ALLOWED_ORIGIN` — your production origin, e.g. `https://your-app.vercel.app`
4. Add a **rate-limit rule on `/api/gemini`** in the Vercel WAF. The origin
   check in the function only filters other websites; `Origin` is trivially
   forged outside a browser, so rate limiting is what actually stops someone
   who finds the URL from spending your quota.
5. Rotate `GEMINI_API_KEY` if it was ever committed or bundled.

### Answer length is capped at 3 minutes

Vercel rejects request bodies over 4.5 MB, and answers upload as base64 audio:
three minutes of µ-law is ~3.7 MB encoded, five minutes would be ~6.1 MB and
fail. `InterviewNotifier.maxAnswerSeconds` enforces the limit and the session
timer shows it. Raising it means sending raw binary instead of base64 (saves
33%) or moving to Gemini's Files API.
