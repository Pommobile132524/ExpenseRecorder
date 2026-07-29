import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// เครื่องมือจัดการเลขบัตรประชาชน 13 หลัก
/// นโยบาย: ไม่เก็บเลขเต็มในฐานข้อมูล — เก็บเฉพาะ hash + 4 หลักท้าย
class NationalId {
  /// ตรวจรูปแบบ + checksum ตามสูตรบัตรประชาชนไทย
  static bool isValid(String id) {
    if (!RegExp(r'^\d{13}$').hasMatch(id)) return false;
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      sum += int.parse(id[i]) * (13 - i);
    }
    final check = (11 - (sum % 11)) % 10;
    return check == int.parse(id[12]);
  }

  /// SHA-256(เลขบัตร + salt) สำหรับเก็บ/ค้นในฐานข้อมูล
  static String hash(String id) {
    final salt = dotenv.env['HASH_SALT'] ?? '';
    return sha256.convert(utf8.encode('$id|$salt')).toString();
  }

  static String last4(String id) => id.substring(id.length - 4);

  /// แสดงแบบปิดบัง เช่น 1-2345-XXXXX-XX-1
  /// รับได้ทั้งเลขเต็ม 13 หลัก หรือเฉพาะ last4
  static String mask({String? fullId, String? lastFour}) {
    if (fullId != null && fullId.length == 13) {
      return '${fullId[0]}-${fullId.substring(1, 5)}-XXXXX-XX-${fullId[12]}';
    }
    if (lastFour != null && lastFour.length == 4) {
      return 'X-XXXX-XXXX${lastFour[0]}-${lastFour.substring(1, 3)}-${lastFour[3]}';
    }
    return 'X-XXXX-XXXXX-XX-X';
  }
}
