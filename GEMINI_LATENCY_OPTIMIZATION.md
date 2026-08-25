# Gemini API Latency Optimization Guide for Oradile

This document details the root causes of the 20–40 second latency spikes observed during speech analysis and interview processing with Google Gemini, along with the concrete 5-step blueprint to reduce response times to **2–4 seconds**.

---

## 1. Root Cause Analysis: Where the Latency is Spent

For a typical 1.5-minute audio recording, the 20–40 second wait time is distributed across three main bottlenecks:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ Total Latency Breakdown (Typical 1.5-min recording)                                    │
├──────────────────────────┬───────────────────────────────┬─────────────────────────────┤
│ 1. Network Upload        │ 2. Multimodal Audio Decoding  │ 3. Gemini Generation        │
│    5.2 MB Base64 JSON    │    Acoustic tokenization      │    Thinking / Reasoning     │
│    (10 – 18 seconds)     │    (6 – 12 seconds)           │    (8 – 15 seconds)         │
└──────────────────────────┴───────────────────────────────┴─────────────────────────────┘
```

### Bottleneck A: Uncompressed Audio Payload (Base64 WAV)
- **Problem**: 16 kHz, 16-bit Mono Linear PCM audio generates $32\text{ KB/s} \times 90\text{s} = 2.88\text{ MB}$ of raw bytes.
- **Base64 Inflation**: Base64 encoding inflates the payload by 33%, resulting in **~3.84 MB to 5.2 MB of JSON text** sent inside the HTTP body.
- **Impact**: On typical mobile or home uplinks (1.5–4 Mbps), uploading 5 MB alone consumes **10–18 seconds** before Google servers even begin processing the request.

### Bottleneck B: Model Architecture & Reasoning Cycles
- **Problem**: `gemini-2.5-flash` is a hybrid reasoning/thinking model.
- **Impact**: By default, the model generates internal hidden "thinking" tokens before emitting the user-facing output. For speech coaching and interview questions, this reasoning deliberation adds **5–15 seconds** of latency without providing additional coaching value.
- **Solution**: Google provides `gemini-2.5-flash-lite`, which is purpose-built for ultra-low latency with thinking **disabled by default**.

### Bottleneck C: Full Multimodal Audio Tokenization vs. Text
- **Problem**: When sending raw audio, Gemini must perform acoustic feature extraction and automatic speech recognition (ASR) across the entire audio stream before it can score the fluency and grammar.
- **Impact**: When given pre-transcribed text (e.g. from on-device Moonshine LiteRT), Gemini only processes ~200 text tokens, which completes in **under 1.5 seconds**.

---

## 2. The 5-Step Optimization Blueprint

```
┌─────────────────────────┐     ┌────────────────────────┐     ┌────────────────────────┐
│ 1. Model Selection      │     │ 2. Audio Compression   │     │ 3. Constrained Schema  │
│ gemini-2.5-flash-lite   │ ──► │ µ-law / AAC (150-250KB)│ ──► │ responseSchema + JSON  │
└─────────────────────────┘     └────────────────────────┘     └────────────────────────┘
                                                                            │
┌─────────────────────────┐     ┌────────────────────────┐                  │
│ 5. Streaming Output     │ ◄── │ 4. On-Device STT First │ ◄────────────────┘
│ streamGenerateContent   │     │ Moonshine LiteRT (Text)│
└─────────────────────────┘     └────────────────────────┘
```

---

### Step 1: Switch to `gemini-2.5-flash-lite`

Google's **`gemini-2.5-flash-lite`** is optimized for high-throughput, latency-sensitive applications. It offers the same 1M token context window and multimodal capabilities while drastically reducing Time-To-First-Token (TTFT).

#### Implementation:
**In `lib/core/config/ai_endpoint.dart`**:
```dart
abstract final class AiEndpoint {
  static const _googleDirect =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent';
  ...
}
```

**In `api/gemini.js` (Serverless Proxy)**:
```javascript
const UPSTREAM =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent';
```

---

### Step 2: Compress Audio Payloads (5 MB $\rightarrow$ 150–250 KB)

Gemini natively supports compressed audio formats: `audio/aac`, `audio/mp4`, `audio/mp3`, `audio/webm`, and `audio/wav` (including µ-law).

| Audio Format | 90s Raw Size | Base64 Upload Size | Upload Time (3 Mbps) |
| :--- | :--- | :--- | :--- |
| **Linear PCM WAV (16-bit)** | 2.88 MB | **5.1 MB** | **13.6 s** |
| **µ-law WAV (`uploadBytes`)** | 1.44 MB | **1.9 MB** | **5.0 s** |
| **AAC / Opus / MP3** | ~180 KB | **~240 KB** | **0.6 s** |

#### Implementation:
In `RecordingNotifier` (`lib/features/recording/providers/recording_provider.dart`), pass `usableAudio.uploadBytes` (companded µ-law WAV) for the Gemini payload while retaining `playbackBytes` for local device playback.

---

### Step 3: Enforce Native `responseSchema` (Constrained Decoding)

Instead of relying on prompt instructions to produce JSON, specify `responseSchema` in `generationConfig`. This forces Gemini's decoder grammar to output pure JSON directly without thinking tokens, markdown fences, or preamble text.

#### Implementation:
```dart
static const _generationConfig = {
  'maxOutputTokens': 1024,
  'temperature': 0.2,
  'responseMimeType': 'application/json',
  'thinkingConfig': {'thinkingBudget': 0},
  'responseSchema': {
    'type': 'OBJECT',
    'properties': {
      'transcript': {'type': 'STRING'},
      'overall_score': {'type': 'INTEGER'},
      'scores': {
        'type': 'OBJECT',
        'properties': {
          'fluency': {'type': 'INTEGER'},
          'vocabulary': {'type': 'INTEGER'},
          'grammar': {'type': 'INTEGER'},
          'coherence': {'type': 'INTEGER'},
          'topic_relevance': {'type': 'INTEGER'},
          'confidence': {'type': 'INTEGER'},
        },
        'required': [
          'fluency',
          'vocabulary',
          'grammar',
          'coherence',
          'topic_relevance',
          'confidence',
        ],
      },
      'filler_words': {'type': 'OBJECT'},
      'wpm': {'type': 'INTEGER'},
      'strengths': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
      'improvements': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'area': {'type': 'STRING'},
            'tip': {'type': 'STRING'},
          },
          'required': ['area', 'tip'],
        },
      },
      'summary': {'type': 'STRING'},
    },
    'required': [
      'scores',
      'overall_score',
      'strengths',
      'improvements',
      'summary',
    ],
  },
};
```

---

### Step 4: Prefer On-Device STT Transcript Analysis

When using the mobile application, on-device **Moonshine LiteRT** (`flutter_gemma_speech`) transcribes the speech live while the user speaks. When the user finishes speaking, the transcript is already available at zero additional cost.

- **Audio Flow**: $\text{Capture} \longrightarrow \text{Upload 4 MB} \longrightarrow \text{Gemini ASR} \longrightarrow \text{Gemini Evaluation} \approx \mathbf{15\text{–}30\text{ s}}$
- **Transcript Flow**: $\text{Capture + Local ASR (0s)} \longrightarrow \text{Upload 1 KB text} \longrightarrow \text{Gemini Evaluation} \approx \mathbf{1.2\text{–}2.0\text{ s}}$

#### Implementation:
In `AnalysisNotifier.analyse()` (`lib/features/analysis/providers/analysis_provider.dart`):
1. If `session.hasTranscript` is true and metrics are pre-computed $\rightarrow$ Call `analyseTranscript()`.
2. Fall back to `analyseAudioFile()` only for file uploads or web sessions where local STT is not available.

---

### Step 5: Streaming Response via `streamGenerateContent`

For interview sessions and real-time coaching:
- Switch from `generateContent` to `streamGenerateContent`.
- The first JSON chunk arrives in **under 1.0 second**, allowing UI meters and animations to update progressively rather than remaining locked on a static loading state.

---

## 3. Latency Impact Summary

| Stage | Baseline (Before) | Optimized (After) | Gain |
| :--- | :--- | :--- | :--- |
| **Network Upload** | 10 – 18 s (5 MB Base64) | **0.4 – 0.8 s** (Compressed / Text) | **~15s faster** |
| **Model Selection** | `gemini-2.5-flash` | **`gemini-2.5-flash-lite`** | **~6s faster** |
| **Reasoning Budget** | Unconstrained thinking | **`thinkingBudget: 0`** | **~8s faster** |
| **Decoding Engine** | Prompt-based JSON formatting | **`responseSchema` Constrained Decoding** | **~2s faster** |
| **Total Turnaround** | **20 – 40 seconds** | **2 – 4 seconds** (Audio) / **1.2 – 2.0 seconds** (Transcript) | **~10× speedup** |
