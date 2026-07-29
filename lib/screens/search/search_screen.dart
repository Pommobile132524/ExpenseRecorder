import 'package:flutter/material.dart';

import '../../core/utils/national_id.dart';
import '../../models/customer.dart';
import '../../services/customer_service.dart';
import '../../services/purchase_service.dart';
import '../customer/customer_detail_screen.dart';

/// ค้นหากลางแอป: ชื่อ / เบอร์ / เลขบัตร (เต็มหรือ 4 หลักท้าย) / หมายเลขบิล
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Customer> _results = [];
  bool _loading = false;

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      // เลขบิล (PB-xxxxxx) → เปิดหน้าลูกค้าเจ้าของบิลทันที
      if (RegExp(r'^PB-?\d+$', caseSensitive: false).hasMatch(query.trim())) {
        final purchase = await PurchaseService().findByBillNo(query);
        if (purchase != null && mounted) {
          setState(() => _loading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CustomerDetailScreen(customerId: purchase.customerId),
            ),
          );
          return;
        }
      }
      final results = await CustomerService().search(query);
      if (mounted) setState(() => _results = results);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ค้นหาลูกค้า / บิล')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'ชื่อ / เบอร์ / เลขบัตร / เลขบิล',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    setState(() => _results = []);
                  },
                ),
              ),
              onSubmitted: _search,
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final c = _results[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(c.fullName),
                  subtitle: Text([
                    NationalId.mask(lastFour: c.nationalIdLast4),
                    if (c.phone != null) c.phone!,
                  ].join(' • ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CustomerDetailScreen(customerId: c.id),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
