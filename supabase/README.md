# Supabase setup

The project is owned directly, not through the Vercel Marketplace. The Flutter
client is what talks to Supabase; Vercel only serves static output and the one
Gemini proxy in `api/gemini.js`, so Marketplace env-var injection would not
reach the code that needs the keys.

## One-time provisioning

```bash
supabase login                # opens a browser
supabase projects create oralidle
supabase link --project-ref <ref>
supabase db push              # applies supabase/migrations/
```

`projects create` prompts for org, region, and database password when the flags
are omitted, so there is nothing to look up first. `supabase projects list`
gives the ref afterwards (`supabase orgs list` gives the org id, if you would
rather pass `--org-id` and `--region` non-interactively).

## Auth settings (all four are required)

Nothing below is on by default, and the flow fails silently without each one.

**1. Anonymous sign-ins** — Authentication → Sign In / Providers → Anonymous.
Gives every row an `auth.uid()` to hang off before the user has given an email.

⚠️ **CAPTCHA interacts with this.** Attack Protection is enabled on the project,
and Supabase applies CAPTCHA to *every* gotrue endpoint — `/signup` included,
which is what anonymous sign-in uses. There is no per-endpoint toggle. A silent
`signInAnonymously()` at launch is therefore rejected:

```
{"code":400,"error_code":"captcha_failed",
 "msg":"captcha protection: request disallowed (no captcha_token found)"}
```

and the failure is invisible — no uid, nothing syncs, the outbox just grows. So
the anonymous account is **created on the first save**, not at launch, by
`AnonymousSignInGate`: the user records and sees their result, then the hCaptcha
challenge appears once. Dismissing it leaves the session on the device and the
next launch tries again.

If you ever turn Attack Protection off, set the anonymous sign-in and email
rate limits under Authentication → Rate Limits in its place.

**2. Email provider** — Authentication → Sign In / Providers → Email. Enabled.

**3. Email templates must contain `{{ .Token }}`.** This is the one that bites.
The stock templates only interpolate `{{ .ConfirmationURL }}`, which sends a
*link* — but the app asks for a 6-digit *code* and calls `verifyOTP` with it. A
user would receive a link and have nothing to type. Under Authentication →
Emails → Templates, edit both:

| Template | Used by |
|---|---|
| **Magic Link** | `signInWithOtp` — signing into an account that already exists |
| **Change Email Address** | `updateUser(email:)` — attaching an email to an anonymous user |

Add something like `Your Oralidle code is {{ .Token }}` to each. Both are needed
because `AuthNotifier.sendLinkCode` picks between them depending on whether the
address is already registered.

**4. Custom SMTP** — Authentication → Emails → SMTP Settings. Supabase's
built-in sender is capped at roughly a couple of messages per hour and is not
meant for production; past that, codes simply stop arriving with no error the
user can see. Point it at Resend, Postmark, SES, or similar and raise the rate
limit under Authentication → Rate Limits before real traffic arrives.

## Keys

`supabase projects api-keys --project-ref <ref>` prints them.

| Key | Where it goes |
|---|---|
| Project URL | `SUPABASE_URL` |
| `sb_publishable_…` | `SUPABASE_PUBLISHABLE_KEY` — safe in the bundle |
| `sb_secret_…` | Nowhere in this repo. Ever. |

The publishable key is public by design; RLS is what protects the data. CI
refuses to deploy a bundle containing `sb_secret_`.

**Web / CI** — add both to the Vercel project (all environments) so
`vercel pull` exposes them to the `--dart-define` in `vercel.json`:

```bash
vercel env add SUPABASE_URL
vercel env add SUPABASE_PUBLISHABLE_KEY
```

**Native dev** — put them in `.env` (see `.env.example`).

**Native release** — pass them explicitly:

```bash
flutter build apk \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

Leave both empty and the app runs exactly as it did before any of this: Hive
only, no sync, no prompts.

## Migrations

| File | Contents |
|---|---|
| `20260825130000_init_schema.sql` | `profiles`, `sessions`, `interviews`, `events` + RLS |
| `20260825130100_storage_recordings.sql` | Private `recordings` bucket + per-user policies |
| `20260825130200_analytics_views.sql` | `analytics.*` views, not exposed to PostgREST |
| `20260825130300_session_audio_cleanup.sql` | Deleting a session drops its audio object |
| `20260825130400_analytics_users_view.sql` | `analytics.v_users` — profiles joined to `auth.users` |
| `20260825130500_recordings_mime_types.sql` | Fix-forward: the bucket's mime list rejected `audio/mp3` |
| `20260826090000_soft_delete.sql` | `deleted_at` on sessions/interviews, so a delete reaches other devices |
| `20260826100000_delete_keeps_content.sql` | Narrows it: a delete drops the audio, keeps the row |

## Deletion

Deleting is a **soft delete**: `deleted_at` is set, the row stays, and every read
filters `deleted_at is null`. A hard delete would leave other devices nothing to
notice, so their next push would put the row straight back.

Locally the row is removed from Hive outright — only the server keeps the
tombstone, which is why no read path in the app has to know about deleted rows.

The one thing a delete destroys is the **audio object**: a trigger removes it
from the bucket and nulls `audio_object_path`. It is the whole storage cost and
the most personal artefact, and nobody expects a deleted recording to still be
playable. Scores and transcript survive, so a session could be restored by
clearing `deleted_at` — everything except playback.

Tombstones accumulate, one small row per deletion. If that ever needs tidying, a
`pg_cron` job over `deleted_at < now() - interval '90 days'` would do it.

`profiles` deliberately has no `email` column. `auth.users.email` is the
verified copy and the only one; `analytics.v_users` joins the two so name and
email can be read together without a duplicate that could drift.

## Reading the analytics

From the SQL editor (which runs as `postgres`, so RLS does not apply):

```sql
select * from analytics.v_users;              -- name, email, session counts
select * from analytics.v_linked_rate;        -- how many ever add an email
select * from analytics.v_topic_popularity;   -- most-practised topics
select * from analytics.v_topic_funnel;       -- opened vs completed
select * from analytics.v_interview_modes;    -- interview mode mix
select * from analytics.v_interview_funnel;   -- started vs finished
select * from analytics.v_upload_mix;         -- record vs upload, file types
select * from analytics.v_daily_active;       -- DAU
select * from analytics.v_event_volume;       -- everything else
```

The views live in `analytics` rather than `public` precisely so the publishable
key cannot read them.
