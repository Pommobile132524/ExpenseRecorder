import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/national_id.dart';
import '../../models/customer.dart';
import '../../models/purchase.dart';
import '../../services/purchase_service.dart';

/// รายละเอียดลูกค้า + ประวัติการขายทั้งหมด (ล่าสุดก่อน, กรองช่วงเวลาได้)
class CustomerDetailScreen extends StatefulWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Customer? _customer;
  List<Purchase> _history = [];
  DateTimeRange? _range;
  bool _loading = true;

  final _dateFmt = DateFormat('d MMM yyyy HH:mm', 'th');
  final _moneyFmt = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final customerRow = await Supabase.instance.client
        .from('customers')
        .select()
        .eq('id', widget.customerId)
        .single();
    final history = await PurchaseService().customerHistory(
      widget.customerId,
      from: _range?.start,
      to: _range?.end.add(const Duration(days: 1)),
    );
    if (mounted) {
      setState(() {
        _customer = Customer.fromJson(customerRow);
        _history = history;
        _loading = false;
      });
    }
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (range != null) {
      setState(() => _range = range);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total =
        _history.fold<double>(0, (s, p) => s + p.totalAmount);
    return Scaffold(
      appBar: AppBar(
        title: Text(_customer?.fullName ?? 'ลูกค้า'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'กรองช่วงเวลา',
            onPressed: _pickRange,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_customer!.fullName,
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                            'บัตรประชาชน: ${NationalId.mask(lastFour: _customer!.nationalIdLast4)}'),
                        if (_customer!.phone != null)
                          Text('โทร: ${_customer!.phone}'),
                        const SizedBox(height: 8),
                        Text(
                          'ประวัติ ${_history.length} บิล'
                          '${_range != null ? ' (ช่วงที่เลือก)' : ''}'
                          ' • รวม ฿${_moneyFmt.format(total)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ..._history.map((p) => Card(
                      child: ExpansionTile(
                        title: Text(
                            '${p.billNo} • ฿${_moneyFmt.format(p.totalAmount)}'),
                        subtitle: Text(_dateFmt.format(p.createdAt.toLocal())),
                        children: p.items
                            .map((item) => ListTile(
                                  dense: true,
                                  title: Text(item.category),
                                  subtitle: Text([
                                    if (item.description != null)
                                      item.description!,
                                    if (item.weight != null)
                                      '${item.weight} กรัม',
                                    if (item.purity != null) item.purity!,
                                    if (item.photoPaths.isNotEmpty)
                                      'รูป ${item.photoPaths.length} รูป',
                                  ].join(' • ')),
                                  trailing: Text(
                                      '฿${_moneyFmt.format(item.amount)}'),
                                ))
                            .toList(),
                      ),
                    )),
                if (_history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('ยังไม่มีประวัติการขาย')),
                  ),
              ],
            ),
    );
  }
}
