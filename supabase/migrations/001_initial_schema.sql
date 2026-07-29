-- ============================================================
-- ระบบรับซื้อ (Gold Shop Purchase Recorder)
-- Migration 001: ตารางหลัก + ดัชนี + RLS
-- รันใน Supabase SQL Editor หรือ `supabase db push`
-- ============================================================

create extension if not exists pgcrypto;

-- ---------- บทบาทผู้ใช้ ----------
create type public.user_role as enum ('owner', 'manager', 'staff');

-- โปรไฟล์พนักงาน (ผูกกับ auth.users ของ Supabase)
create table public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  full_name  text not null,
  role       public.user_role not null default 'staff',
  created_at timestamptz not null default now()
);

-- ฟังก์ชันช่วยอ่านบทบาทของผู้ใช้ปัจจุบัน (ใช้ใน policy)
create or replace function public.app_role()
returns public.user_role
language sql stable security definer set search_path = public
as $$
  select role from public.profiles where id = auth.uid()
$$;

-- ---------- ลูกค้า ----------
-- ห้ามเก็บเลขบัตรเต็ม: เก็บ hash (SHA-256 + salt ฝั่งแอป) + 4 หลักท้าย
create table public.customers (
  id                 uuid primary key default gen_random_uuid(),
  full_name          text not null,
  national_id_hash   text not null unique,
  national_id_last4  char(4) not null,
  phone              text,
  created_by         uuid not null default auth.uid() references auth.users (id),
  created_at         timestamptz not null default now()
);

-- ---------- ไฟล์บัตรประชาชน ----------
-- เก็บ "path ใน storage" ไม่ใช่ URL ตรง ๆ แล้วออก signed URL ตอนแสดงผล
create table public.idcards (
  id                  uuid primary key default gen_random_uuid(),
  customer_id         uuid not null references public.customers (id) on delete cascade,
  front_path          text not null,
  back_path           text,
  consent_accepted_at timestamptz not null default now(),
  consent_accepted_by uuid not null default auth.uid() references auth.users (id),
  created_at          timestamptz not null default now()
);

-- ---------- หัวบิลรับซื้อ ----------
create sequence public.bill_no_seq;

create table public.purchases (
  id           uuid primary key default gen_random_uuid(),
  bill_no      text not null unique
               default 'PB-' || lpad(nextval('public.bill_no_seq')::text, 6, '0'),
  customer_id  uuid not null references public.customers (id) on delete restrict,
  total_amount numeric(12,2) not null default 0,
  note         text,
  created_by   uuid not null default auth.uid() references auth.users (id),
  created_at   timestamptz not null default now()
);

-- ---------- รายการสินค้าในบิล ----------
-- หมายเหตุ: ใช้ชื่อคอลัมน์ description แทน desc เพราะ desc เป็น reserved word ของ SQL
create table public.purchase_items (
  id          uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references public.purchases (id) on delete cascade,
  category    text not null,            -- เช่น ทองรูปพรรณ / กรอบพระ / เครื่องประดับ
  description text,
  purity      text,                     -- เช่น 96.5%, 18K, 14K
  weight      numeric(10,2),            -- กรัม
  unit_price  numeric(12,2),
  amount      numeric(12,2) not null default 0,
  created_at  timestamptz not null default now()
);

-- ---------- รูปสินค้า (1–5 รูปต่อชิ้น ตรวจที่ฝั่งแอป) ----------
create table public.item_photos (
  id               uuid primary key default gen_random_uuid(),
  purchase_item_id uuid not null references public.purchase_items (id) on delete cascade,
  photo_path       text not null,
  created_at       timestamptz not null default now()
);

-- ---------- Audit log การเข้าถึงข้อมูลอ่อนไหว ----------
create table public.audit_logs (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid(),
  action     text not null,             -- เช่น view_idcard, download_idcard, delete_customer
  entity     text not null,             -- ชื่อตาราง/ชนิดข้อมูล
  entity_id  uuid,
  detail     jsonb,
  created_at timestamptz not null default now()
);

-- ---------- ดัชนีช่วยค้น ----------
create index idx_customers_name      on public.customers using gin (to_tsvector('simple', full_name));
create index idx_customers_name_ilike on public.customers (full_name text_pattern_ops);
create index idx_customers_last4     on public.customers (national_id_last4);
create index idx_customers_phone     on public.customers (phone);
create index idx_purchases_customer  on public.purchases (customer_id, created_at desc);
create index idx_purchases_bill_no   on public.purchases (bill_no);
create index idx_items_purchase      on public.purchase_items (purchase_id);
create index idx_photos_item         on public.item_photos (purchase_item_id);
create index idx_idcards_customer    on public.idcards (customer_id);

-- ============================================================
-- Row Level Security
-- ============================================================
alter table public.profiles       enable row level security;
alter table public.customers      enable row level security;
alter table public.idcards        enable row level security;
alter table public.purchases      enable row level security;
alter table public.purchase_items enable row level security;
alter table public.item_photos    enable row level security;
alter table public.audit_logs     enable row level security;

-- profiles: ทุกคนเห็นโปรไฟล์ตัวเอง / owner จัดการทั้งหมด
create policy "read own profile" on public.profiles
  for select to authenticated using (id = auth.uid() or public.app_role() = 'owner');
create policy "owner manages profiles" on public.profiles
  for all to authenticated
  using (public.app_role() = 'owner') with check (public.app_role() = 'owner');

-- customers: พนักงานทุกคนอ่าน/สร้างได้, แก้ไข-ลบเฉพาะ owner/manager
create policy "staff read customers" on public.customers
  for select to authenticated using (true);
create policy "staff insert customers" on public.customers
  for insert to authenticated with check (created_by = auth.uid());
create policy "mgr update customers" on public.customers
  for update to authenticated
  using (public.app_role() in ('owner','manager'))
  with check (public.app_role() in ('owner','manager'));
create policy "mgr delete customers" on public.customers
  for delete to authenticated using (public.app_role() in ('owner','manager'));

-- idcards: อ่านได้เฉพาะ owner/manager (staff สร้างตอนรับลูกค้าได้ แต่ย้อนดูไม่ได้)
create policy "mgr read idcards" on public.idcards
  for select to authenticated using (public.app_role() in ('owner','manager'));
create policy "staff insert idcards" on public.idcards
  for insert to authenticated with check (consent_accepted_by = auth.uid());
create policy "mgr delete idcards" on public.idcards
  for delete to authenticated using (public.app_role() in ('owner','manager'));

-- purchases / purchase_items / item_photos: พนักงานอ่าน-สร้างได้, ลบเฉพาะ owner/manager
create policy "staff read purchases" on public.purchases
  for select to authenticated using (true);
create policy "staff insert purchases" on public.purchases
  for insert to authenticated with check (created_by = auth.uid());
create policy "mgr delete purchases" on public.purchases
  for delete to authenticated using (public.app_role() in ('owner','manager'));

create policy "staff read items" on public.purchase_items
  for select to authenticated using (true);
create policy "staff insert items" on public.purchase_items
  for insert to authenticated with check (true);
create policy "mgr delete items" on public.purchase_items
  for delete to authenticated using (public.app_role() in ('owner','manager'));

create policy "staff read photos" on public.item_photos
  for select to authenticated using (true);
create policy "staff insert photos" on public.item_photos
  for insert to authenticated with check (true);
create policy "mgr delete photos" on public.item_photos
  for delete to authenticated using (public.app_role() in ('owner','manager'));

-- audit_logs: ทุกคนเขียนได้ อ่านได้เฉพาะ owner
create policy "insert audit" on public.audit_logs
  for insert to authenticated with check (user_id = auth.uid());
create policy "owner read audit" on public.audit_logs
  for select to authenticated using (public.app_role() = 'owner');
