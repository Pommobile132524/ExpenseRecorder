import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/national_id.dart';
import '../../models/purchase_item.dart';
import '../../services/customer_service.dart';
import '../../services/purchase_service.dart';

/// ฟอร์มสร้างรายการรับซื้อ: ข้อมูลลูกค้า + บัตรประชาชน + รายการสินค้า + สรุปยอด
class PurchaseFormScreen extends StatefulWidget {
  const PurchaseFormScreen({super.key});

  @override
  State<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends State<PurchaseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  // ลูกค้า
  final _name = TextEditingController();
  final _nationalId = TextEditingController();
  final _phone = TextEditingController();

  // บัตรประชาชน + consent
  XFile? _idFront;
  XFile? _idBack;
  bool _consent = false;

  // สินค้า
  final List<DraftItem> _drafts = [];
  final _note = TextEditingController();

  bool _saving = false;

  double get _total => _drafts.fold(0, (s, d) => s + d.item.amount);

  Future<XFile?> _pickPhoto() =>
      _picker.pickImage(source: ImageSource.camera, imageQuality: 80);

  Future<void> _addItem() async {
    final draft = await showModalBottomSheet<DraftItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ItemFormSheet(),
    );
    if (draft != null) setState(() => _drafts.add(draft));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_idFront == null || !_consent) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('กรุณาถ่ายรูปบัตรประชาชนและติ๊กยินยอมก่อนบันทึก')));
      return;
    }
    if (_drafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเพิ่มสินค้าอย่างน้อย 1 รายการ')));
      return;
    }

    setState(() => _saving = true);
    try {
      final customerService = CustomerService();
      final customerId = await customerService.createOrGetCustomer(
        fullName: _name.text.trim(),
        nationalId: _nationalId.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      );
      await customerService.uploadIdCard(
        customerId: customerId,
        frontFile: _idFront!,
        backFile: _idBack,
      );
      final billId = await PurchaseService().createPurchase(
        customerId: customerId,
        drafts: _drafts,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('บันทึกบิลเรียบร้อย ($billId)')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('รายการรับซื้อใหม่')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('ข้อมูลลูกค้า',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'ชื่อ-นามสกุล *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อ' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nationalId,
              keyboardType: TextInputType.number,
              maxLength: 13,
              decoration: const InputDecoration(
                labelText: 'เลขบัตรประชาชน 13 หลัก *',
                helperText: 'ระบบเก็บเฉพาะรหัสยืนยัน (hash) และ 4 หลักท้าย',
              ),
              validator: (v) => NationalId.isValid(v ?? '')
                  ? null
                  : 'เลขบัตรประชาชนไม่ถูกต้อง',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'เบอร์โทร'),
            ),
            const Divider(height: 32),

            Text('บัตรประชาชน',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(_idFront == null
                        ? Icons.photo_camera
                        : Icons.check_circle),
                    label: Text(
                        _idFront == null ? 'ถ่ายด้านหน้า *' : 'ได้ด้านหน้าแล้ว'),
                    onPressed: () async {
                      final f = await _pickPhoto();
                      if (f != null) setState(() => _idFront = f);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(_idBack == null
                        ? Icons.photo_camera_back
                        : Icons.check_circle),
                    label: Text(
                        _idBack == null ? 'ถ่ายด้านหลัง' : 'ได้ด้านหลังแล้ว'),
                    onPressed: () async {
                      final f = await _pickPhoto();
                      if (f != null) setState(() => _idBack = f);
                    },
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              value: _consent,
              onChanged: (v) => setState(() => _consent = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'ลูกค้ารับทราบและยินยอมให้จัดเก็บสำเนาบัตรประชาชน '
                'ตามนโยบายข้อมูลส่วนบุคคล (PDPA)',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const Divider(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('สินค้าที่นำมาขาย (${_drafts.length})',
                    style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มสินค้า'),
                  onPressed: _addItem,
                ),
              ],
            ),
            ..._drafts.asMap().entries.map((entry) => Card(
                  child: ListTile(
                    title: Text(entry.value.item.category),
                    subtitle: Text([
                      if (entry.value.item.description != null)
                        entry.value.item.description!,
                      if (entry.value.item.weight != null)
                        '${entry.value.item.weight} กรัม',
                      if (entry.value.item.purity != null)
                        entry.value.item.purity!,
                      'รูป ${entry.value.photos.length} รูป',
                    ].join(' • ')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('฿${entry.value.item.amount.toStringAsFixed(2)}'),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              setState(() => _drafts.removeAt(entry.key)),
                        ),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'หมายเหตุ'),
            ),
            const SizedBox(height: 24),
            Text('ยอดรวม  ฿${_total.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('บันทึกบิลรับซื้อ'),
            ),
          ],
        ),
      ),
    );
  }
}

/// ฟอร์มเพิ่มสินค้า 1 ชิ้น (เปิดเป็น bottom sheet)
class _ItemFormSheet extends StatefulWidget {
  const _ItemFormSheet();

  @override
  State<_ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends State<_ItemFormSheet> {
  static const categories = [
    'ทองรูปพรรณ',
    'ทองคำแท่ง',
    'กรอบพระ',
    'เครื่องประดับ',
    'อื่น ๆ',
  ];

  final _picker = ImagePicker();
  String _category = categories.first;
  final _description = TextEditingController();
  final _purity = TextEditingController();
  final _weight = TextEditingController();
  final _amount = TextEditingController();
  final List<XFile> _photos = [];

  Future<void> _addPhoto() async {
    if (_photos.length >= 5) return;
    final f =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (f != null) setState(() => _photos.add(f));
  }

  void _submit() {
    final amount = double.tryParse(_amount.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณากรอกจำนวนเงินให้ถูกต้อง')));
      return;
    }
    Navigator.pop(
      context,
      DraftItem(
        item: PurchaseItem(
          category: _category,
          description:
              _description.text.trim().isEmpty ? null : _description.text.trim(),
          purity: _purity.text.trim().isEmpty ? null : _purity.text.trim(),
          weight: double.tryParse(_weight.text),
          amount: amount,
        ),
        photos: List.of(_photos),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('เพิ่มสินค้า', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            items: categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v!),
            decoration: const InputDecoration(labelText: 'ประเภท'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'รายละเอียด'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _purity,
                  decoration: const InputDecoration(
                      labelText: 'ความบริสุทธิ์', hintText: '96.5% / 18K'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'น้ำหนัก (กรัม)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'ราคารับซื้อ (บาท) *'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('รูปสินค้า ${_photos.length}/5'),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.add_a_photo),
                label: const Text('ถ่ายรูป'),
                onPressed: _photos.length >= 5 ? null : _addPhoto,
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _submit, child: const Text('เพิ่มรายการ')),
        ],
      ),
    );
  }
}
