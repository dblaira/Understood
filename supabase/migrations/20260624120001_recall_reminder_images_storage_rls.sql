-- Private Storage bucket RLS for reminder photos (path: "<uid>/<reminder-id>.jpg").

drop policy if exists "recall reminder images select own" on storage.objects;
drop policy if exists "recall reminder images insert own" on storage.objects;
drop policy if exists "recall reminder images update own" on storage.objects;
drop policy if exists "recall reminder images delete own" on storage.objects;

create policy "recall reminder images select own"
  on storage.objects for select to authenticated
  using (bucket_id = 'reminder-images' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "recall reminder images insert own"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'reminder-images' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "recall reminder images update own"
  on storage.objects for update to authenticated
  using (bucket_id = 'reminder-images' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "recall reminder images delete own"
  on storage.objects for delete to authenticated
  using (bucket_id = 'reminder-images' and (storage.foldername(name))[1] = auth.uid()::text);
