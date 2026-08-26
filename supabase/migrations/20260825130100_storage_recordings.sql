-- Private bucket for practice audio.
--
-- Objects are keyed `{uid}/{sessionId}.wav`, so the first path segment is the
-- owner and every policy below is a comparison against it. Playback mints a
-- short-lived signed URL rather than making the bucket public.
--
-- What gets uploaded is the µ-law WAV the app already produces for the Gemini
-- request (WavCodec.encodeMuLaw), not the linear-PCM playback copy: ~16 KB/s,
-- so a two-minute answer is ~1.9 MB instead of ~3.8 MB.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'recordings',
  'recordings',
  false,
  10485760, -- 10 MB: covers a 2-minute µ-law take with room for uploaded files
  -- Must stay in step with `_mimeType` in preparation_screen.dart, which is
  -- what the client actually sends. It emits `audio/mp3` and `audio/flac`,
  -- neither of which is the registered name — omit them and every mp3 upload
  -- is rejected at the bucket.
  array[
    'audio/wav', 'audio/wave', 'audio/x-wav',
    'audio/mp3', 'audio/mpeg',
    'audio/mp4', 'audio/m4a', 'audio/aac',
    'audio/ogg', 'audio/webm', 'audio/flac'
  ]
)
on conflict (id) do nothing;

create policy "own recordings read" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'recordings'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "own recordings insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'recordings'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "own recordings update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'recordings'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "own recordings delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'recordings'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
