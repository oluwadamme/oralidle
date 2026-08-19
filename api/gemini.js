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

export const config = {
  // Audio analysis of a long answer regularly runs past the 10s default.
  maxDuration: 60,
};

const UPSTREAM =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

/// Vercel rejects request bodies above this, and Gemini audio payloads are the
/// only thing here that gets close. Checked explicitly so an oversized answer
/// fails with an explanation rather than a bare platform error.
const MAX_BODY_BYTES = 4 * 1024 * 1024;

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

export default async function handler(request) {
  if (request.method !== 'POST') {
    return json(405, { error: { message: 'Method not allowed' } });
  }

  // Browsers attach Origin on cross-origin POSTs; our own page does not (it is
  // same-origin) and native clients send none at all. So an absent Origin is
  // normal and a mismatched one is not.
  //
  // This only filters casual abuse from other websites — Origin is trivially
  // forged outside a browser. Rate limiting is what actually contains misuse
  // of this endpoint; see the WAF rule noted in README.md.
  const origin = request.headers.get('origin');
  const allowed = process.env.ALLOWED_ORIGIN;
  if (origin && allowed && origin !== allowed) {
    return json(403, { error: { message: 'Origin not allowed' } });
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    // A configuration fault, not a caller fault — say so plainly rather than
    // letting Google return a confusing 400.
    return json(500, {
      error: { message: 'GEMINI_API_KEY is not configured on the server' },
    });
  }

  const body = await request.text();
  if (body.length > MAX_BODY_BYTES) {
    return json(413, {
      error: {
        message:
          'Recording is too large to analyse. Please keep answers under three minutes.',
      },
    });
  }

  let upstream;
  try {
    upstream = await fetch(UPSTREAM, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body,
    });
  } catch (error) {
    return json(502, {
      error: { message: `Could not reach the analysis service: ${error}` },
    });
  }

  // Status and body pass straight back so the client's existing error
  // handling — which already reads Gemini's `error.message` — keeps working.
  return new Response(upstream.body, {
    status: upstream.status,
    headers: { 'Content-Type': 'application/json' },
  });
}
