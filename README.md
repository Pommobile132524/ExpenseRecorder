# ระบบรับซื้อหน้าร้าน (Gold Shop Purchase Recorder)

แอป Flutter + Supabase สำหรับบันทึกการรับซื้อสินค้า (ทอง/พระ/เครื่องประดับ) หน้าร้าน
เก็บ (1) รูปบัตรประชาชน (2) รายการสินค้าที่ลูกค้านำมาขาย (3) รูปถ่ายสินค้า
และ (4) ค้นประวัติการขายรายบุคคลได้ — ออกแบบตามแนวทาง PDPA

## โครงสร้างโปรเจกต์

```
supabase/migrations/
  001_initial_schema.sql    # ตาราง + ดัชนี + RLS (customers, idcards, purchases, ...)
  002_storage_buckets.sql   # บัคเก็ต idcards / items (private) + policy ตามบทบาท
lib/
  main.dart                 # จุดเริ่มแอป + AuthGate (login ↔ dashboard)
  core/
    theme/app_theme.dart    # ธีมโทนทอง
    utils/national_id.dart  # ตรวจ checksum, hash+salt, last4, mask เลขบัตร
  models/                   # Customer, Purchase, PurchaseItem
  services/
    customer_service.dart   # สร้าง/ค้นลูกค้า, อัพโหลดบัตร, signed URL + audit log
    purchase_service.dart   # เปิดบิล, รายการสินค้า+รูป, ประวัติรายบุคคล, ค้นเลขบิล
  screens/
    auth/login_screen.dart
    dashboard/dashboard_screen.dart
    purchase/purchase_form_screen.dart   # ฟอร์มลูกค้า+บัตร+consent+สินค้า+สรุปยอด
    search/search_screen.dart            # ค้น ชื่อ/เบอร์/เลขบัตร/เลขบิล
    customer/customer_detail_screen.dart # ประวัติการขาย กรองช่วงเวลาได้
```

## ขั้นตอนติดตั้ง

### 1. ตั้งค่า Supabase

1. สร้างโปรเจกต์ที่ [supabase.com](https://supabase.com)
2. รัน SQL ใน **SQL Editor** ตามลำดับ:
   - `supabase/migrations/001_initial_schema.sql`
   - `supabase/migrations/002_storage_buckets.sql`
3. สร้างผู้ใช้พนักงานใน **Authentication → Users** แล้วเพิ่มแถวใน `profiles`
   กำหนด `role` เป็น `owner` / `manager` / `staff`:
   ```sql
   insert into public.profiles (id, full_name, role)
   values ('<auth-user-uuid>', 'ชื่อเจ้าของร้าน', 'owner');
   ```

### 2. ตั้งค่าแอป Flutter

```bash
# สร้างไฟล์แพลตฟอร์ม android/ios (โฟลเดอร์เหล่านี้ไม่ commit ไว้ใน repo)
flutter create . --platforms=android,ios --project-name gold_purchase_app

cp .env.example .env   # แล้วใส่ SUPABASE_URL / SUPABASE_ANON_KEY / HASH_SALT
flutter pub get
flutter run
```

อย่าลืมเพิ่ม permission กล้อง/แกลเลอรีตามคู่มือ [image_picker](https://pub.dev/packages/image_picker)
(`NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` ใน iOS)

## จุดออกแบบด้านความปลอดภัย/PDPA

- **ไม่เก็บเลขบัตรเต็ม** — เก็บ SHA-256(เลขบัตร+salt) + 4 หลักท้าย และแสดงแบบ mask เสมอ
- **บัคเก็ตเป็น private ทั้งหมด** — เข้าถึงไฟล์ผ่าน signed URL อายุสั้นเท่านั้น
- **รูปบัตรอ่านได้เฉพาะ owner/manager** (staff อัพโหลดตอนรับลูกค้าได้ แต่ย้อนดูไม่ได้)
- **Consent** — ต้องติ๊กยินยอมก่อนบันทึก และเก็บเวลา+ผู้บันทึกใน `idcards`
- **Audit log** — บันทึกทุกครั้งที่มีการเปิดดูรูปบัตร (`audit_logs` อ่านได้เฉพาะ owner)
- **RLS เปิดทุกตาราง** — สิทธิ์แยกตามบทบาทผ่านฟังก์ชัน `app_role()` ใน policy

## สิ่งที่ยังไม่ได้ทำ (โรดแมปถัดไป)

- รายงานสรุปยอดรายวัน/รายเดือน
- Export CSV/PDF ใบรับซื้อ
- นโยบายลบข้อมูลตามอายุจัดเก็บ (retention) อัตโนมัติ
- รองรับหลายสาขา (เพิ่ม branch_id + ปรับ RLS)
