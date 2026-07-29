import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/purchase.dart';
import '../models/purchase_item.dart';

/// รายการสินค้า 1 ชิ้นพร้อมไฟล์รูปที่ยังไม่ได้อัพโหลด (ใช้ตอนกรอกฟอร์ม)
class DraftItem {
  final PurchaseItem item;
  final List<XFile> photos; // 1–5 รูป

  DraftItem({required this.item, this.photos = const []});
}

class PurchaseService {
  final SupabaseClient _supa = Supabase.instance.client;

  /// เปิดบิลรับซื้อ: บันทึกหัวบิล + รายการสินค้า + อัพโหลดรูปสินค้า
  /// คืนค่า id ของบิล
  Future<String> createPurchase({
    required String customerId,
    required List<DraftItem> drafts,
    String? note,
  }) async {
    final total =
        drafts.fold<double>(0, (sum, d) => sum + d.item.amount);

    final purchase = await _supa.from('purchases').insert({
      'customer_id': customerId,
      'total_amount': total,
      'note': note,
    }).select('id').single();
    final purchaseId = purchase['id'] as String;

    for (final draft in drafts) {
      final itemRow = await _supa
          .from('purchase_items')
          .insert(draft.item.toInsertJson(purchaseId))
          .select('id')
          .single();
      final itemId = itemRow['id'] as String;

      for (var i = 0; i < draft.photos.length && i < 5; i++) {
        final path =
            '$purchaseId/$itemId/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        await _supa.storage
            .from('items')
            .upload(path, File(draft.photos[i].path));
        await _supa.from('item_photos').insert({
          'purchase_item_id': itemId,
          'photo_path': path,
        });
      }
    }
    return purchaseId;
  }

  /// ประวัติการขายทั้งหมดของลูกค้า (ล่าสุดก่อน กรองช่วงเวลาได้)
  Future<List<Purchase>> customerHistory(
    String customerId, {
    DateTime? from,
    DateTime? to,
  }) async {
    var query = _supa
        .from('purchases')
        .select('*, purchase_items(*, item_photos(*))')
        .eq('customer_id', customerId);
    if (from != null) query = query.gte('created_at', from.toIso8601String());
    if (to != null) query = query.lte('created_at', to.toIso8601String());

    final rows = await query.order('created_at', ascending: false);
    return rows.map<Purchase>((r) => Purchase.fromJson(r)).toList();
  }

  /// ค้นบิลจากหมายเลขบิล เช่น PB-000123
  Future<Purchase?> findByBillNo(String billNo) async {
    final row = await _supa
        .from('purchases')
        .select('*, purchase_items(*, item_photos(*))')
        .eq('bill_no', billNo.trim().toUpperCase())
        .maybeSingle();
    return row == null ? null : Purchase.fromJson(row);
  }

  /// signed URL สำหรับรูปสินค้า
  Future<String> signedItemPhotoUrl(String path) =>
      _supa.storage.from('items').createSignedUrl(path, 60 * 30);
}
