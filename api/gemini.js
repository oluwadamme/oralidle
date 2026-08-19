// Server-side proxy for Gemini `generateContent`.
//
// A Flutter web build is static files in a browser, so any key it carries is
// readable by anyone who loads the page. The key lives here instead: the
// client posts the same request body it would have sent to Google, and this
// function adds the credential on the way through.
//
// The body is forwarded verbatim, so both callers — GeminiService (speech
// analysis) and InterviewService (mock interviews) — work through one
// endpoint without the proxy needing to understand either payload.

const UPSTREAM =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

// Vercel rejects request bodies above ~4.5 MB, and Gemini audio payloads are
// the only thing here that gets close. Checked explicitly so an oversized
// answer fails with an explanation rather than a bare platform error.
const MAX_BODY_BYTES = 4 * 1024 * 1024;

// Below `maxDuration` in vercel.json (60s) so a stalled upstream returns a
// real 504 from us rather than the platform killing the function mid-flight
// and handing the client an opaque error.
const UPSTREAM_TIMEOUT_MS = 55_000;

// Per-instance flood control. See rateLimited() for what this does and does
// not protect against.
const RATE_LIMIT_MAX = 20;
const RATE_LIMIT_WINDOW_MS = 60_000;
const RATE_LIMIT_MAX_TRACKED = 5_000;

/** @type {Map<string, {count: number, resetAt: number}>} */
const rateLimitHits = new Map();

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      // Responses are request-specific and must never be served to anyone
      // else from a cache.
      'Cache-Control': 'no-store',
    },
  });
}

/** Host of `url`, or null if it cannot be parsed. */
function safeHost(url) {
  try {
    return new URL(url).host;
  } catch {
    return null;
  }
}

/** True when `origin` is this deployment itself, or the configured extra. */
function isAllowedOrigin(origin, request) {
  const originHost = safeHost(origin);
  if (!originHost) return false;

  const host =
    request.headers.get('x-forwarded-host') ??
    request.headers.get('host') ??
    safeHost(request.url);
  if (host && originHost === host) return true;

  const allowed = process.env.ALLOWED_ORIGIN;
  return Boolean(allowed) && origin === allowed;
}


function rateLimited(request) {
  const ip =
    request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() || 'unknown';
  const now = Date.now();

  // Bound the map: without this a spray of unique IPs would grow it until the
  // instance runs out of memory.
  if (rateLimitHits.size > RATE_LIMIT_MAX_TRACKED) {
    for (const [key, entry] of rateLimitHits) {
      if (now > entry.resetAt) rateLimitHits.delete(key);
    }
    if (rateLimitHits.size > RATE_LIMIT_MAX_TRACKED) rateLimitHits.clear();
  }

  const entry = rateLimitHits.get(ip);
  if (!entry || now > entry.resetAt) {
    rateLimitHits.set(ip, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS });
    return false;
  }

  entry.count += 1;
  return entry.count > RATE_LIMIT_MAX;
}

export async function POST(request) {

  const origin = request.headers.get('origin');
  if (origin && !isAllowedOrigin(origin, request)) {
    return json(403, { error: { message: 'Origin not allowed' } });
  }

  if (rateLimited(request)) {
    return json(429, {
      error: { message: 'Too many requests. Please wait a moment.' },
    });
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    // A configuration fault, not a caller fault — say so plainly rather than
    // letting Google return a confusing 400.
    return json(500, {
      error: { message: 'GEMINI_API_KEY is not configured on the server' },
    });
  }


  const declaredLength = Number(request.headers.get('content-length'));
  if (Number.isFinite(declaredLength) && declaredLength > MAX_BODY_BYTES) {
    return json(413, {
      error: {
        message:
          'Recording is too large to analyse. Please keep answers under three minutes.',
      },
    });
  }

  const body = await request.text();

  let upstream;
  try {
    upstream = await fetch(UPSTREAM, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body,
      signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
    });
  } catch (error) {
    // Logged in full for us; the client gets a message that says what to do
    // and nothing about our internals.
    console.error('Gemini upstream request failed:', error);
    const timedOut = error?.name === 'TimeoutError' || error?.name === 'AbortError';
    return json(timedOut ? 504 : 502, {
      error: {
        message: timedOut
          ? 'The analysis service took too long to respond. Please try again.'
          : 'Could not reach the analysis service. Please try again.',
      },
    });
  }

  // Status and body pass straight back so the client's existing error handling
  // — which already reads Gemini's `error.message` — keeps working. The
  // upstream content type is preserved rather than asserted: when Google's
  // edge returns an HTML error page, mislabelling it as JSON turns a readable
  // failure into a parse error.
  return new Response(upstream.body, {
    status: upstream.status,
    headers: {
      'Content-Type':
        upstream.headers.get('content-type') ?? 'application/json',
      'Cache-Control': 'no-store',
    },
  });
}
