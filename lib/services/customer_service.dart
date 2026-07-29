import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/national_id.dart';
import '../models/customer.dart';

class CustomerService {
  final SupabaseClient _supa = Supabase.instance.client;

  /// สร้างลูกค้าใหม่ (เก็บเฉพาะ hash + last4 ของเลขบัตร)
  /// ถ้าเลขบัตรนี้เคยลงทะเบียนแล้ว จะคืน id ลูกค้าเดิมแทน
  Future<String> createOrGetCustomer({
    required String fullName,
    required String nationalId,
    String? phone,
  }) async {
    final hash = NationalId.hash(nationalId);

    final existing = await _supa
        .from('customers')
        .select('id')
        .eq('national_id_hash', hash)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    final res = await _supa.from('customers').insert({
      'full_name': fullName,
      'national_id_hash': hash,
      'national_id_last4': NationalId.last4(nationalId),
      'phone': phone,
    }).select('id').single();
    return res['id'] as String;
  }

  /// อัพโหลดรูปบัตร (หน้า/หลัง) เข้าบัคเก็ต private แล้วบันทึก path + consent
  Future<void> uploadIdCard({
    required String customerId,
    required XFile frontFile,
    XFile? backFile,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;

    final frontPath = '$customerId/front_$ts.jpg';
    await _supa.storage.from('idcards').upload(frontPath, File(frontFile.path));

    String? backPath;
    if (backFile != null) {
      backPath = '$customerId/back_$ts.jpg';
      await _supa.storage.from('idcards').upload(backPath, File(backFile.path));
    }

    await _supa.from('idcards').insert({
      'customer_id': customerId,
      'front_path': frontPath,
      'back_path': backPath,
    });
  }

  /// ค้นลูกค้าจากชื่อ / เบอร์ / 4 หลักท้าย / เลขบัตรเต็ม 13 หลัก
  Future<List<Customer>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    // ถ้าพิมพ์เลขบัตรเต็ม ให้ค้นจาก hash ตรง ๆ (แม่นสุด)
    if (RegExp(r'^\d{13}$').hasMatch(q)) {
      final rows = await _supa
          .from('customers')
          .select()
          .eq('national_id_hash', NationalId.hash(q));
      return rows.map<Customer>((r) => Customer.fromJson(r)).toList();
    }

    final rows = await _supa
        .from('customers')
        .select()
        .or('full_name.ilike.%$q%,phone.ilike.%$q%,national_id_last4.eq.${q.length == 4 ? q : '0000'}')
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map<Customer>((r) => Customer.fromJson(r)).toList();
  }

  /// ขอ signed URL อายุสั้นสำหรับดูรูปบัตร (เฉพาะ owner/manager ผ่าน RLS)
  /// พร้อมบันทึก audit log ทุกครั้ง
  Future<String> signedIdCardUrl(String path, {String? customerId}) async {
    final url =
        await _supa.storage.from('idcards').createSignedUrl(path, 60 * 5);
    await _supa.from('audit_logs').insert({
      'action': 'view_idcard',
      'entity': 'idcards',
      'entity_id': customerId,
      'detail': {'path': path},
    });
    return url;
  }
}
