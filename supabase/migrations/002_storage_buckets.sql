-- ============================================================
-- Migration 002: Storage buckets + policies
-- บัคเก็ตทั้งหมดเป็น private → ใช้ signed URL เท่านั้น ไม่มี public read
-- ============================================================

insert into storage.buckets (id, name, public)
values
  ('idcards', 'idcards', false),
  ('items',   'items',   false)
on conflict (id) do nothing;

-- ---------- idcards: อ่านเฉพาะ owner/manager, อัพโหลดได้ทุกพนักงาน ----------
create policy "mgr read idcard files" on storage.objects
  for select to authenticated
  using (bucket_id = 'idcards' and public.app_role() in ('owner','manager'));

create policy "staff upload idcard files" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'idcards');

create policy "mgr delete idcard files" on storage.objects
  for delete to authenticated
  using (bucket_id = 'idcards' and public.app_role() in ('owner','manager'));

-- ---------- items: อ่าน/อัพโหลดได้ทุกพนักงานที่ล็อกอิน ----------
create policy "staff read item files" on storage.objects
  for select to authenticated
  using (bucket_id = 'items');

create policy "staff upload item files" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'items');

create policy "mgr delete item files" on storage.objects
  for delete to authenticated
  using (bucket_id = 'items' and public.app_role() in ('owner','manager'));
