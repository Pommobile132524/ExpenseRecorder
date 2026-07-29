import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../purchase/purchase_form_screen.dart';
import '../search/search_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แดชบอร์ด'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // แถบค้นหา: ชื่อ / เบอร์ / เลขบัตร / หมายเลขบิล
            TextField(
              readOnly: true,
              decoration: const InputDecoration(
                hintText: 'ค้นหา: ชื่อ / เบอร์ / เลขบัตร / เลขบิล',
                prefixIcon: Icon(Icons.search),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('รับของเข้า / ทำรายการใหม่'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PurchaseFormScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
