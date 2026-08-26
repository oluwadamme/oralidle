-- Fix-forward for the `recordings` bucket's allowed_mime_types.
--
-- 20260825130100 shipped a list written from the registered MIME names rather
-- than from what the client actually sends. `_mimeType` in
-- preparation_screen.dart emits `audio/mp3` and `audio/flac`, so every mp3
-- upload — the most common uploaded format — was rejected at the bucket.
--
-- That migration had already been applied when the mistake was found, and
-- applied migrations are never re-run. Its file carries the corrected list so a
-- fresh `db reset` is right from the start; this one repairs the databases that
-- had already taken the old one. Running both is harmless — the update below is
-- idempotent.

update storage.buckets
   set allowed_mime_types = array[
         'audio/wav', 'audio/wave', 'audio/x-wav',
         'audio/mp3', 'audio/mpeg',
         'audio/mp4', 'audio/m4a', 'audio/aac',
         'audio/ogg', 'audio/webm', 'audio/flac'
       ]
 where id = 'recordings';
