import 'package:flutter/material.dart';
import '../../domain/entities/professional_shop_profile_entity.dart';

class ProfessionalShopEarningsPage extends StatelessWidget {
  final ProfessionalShopProfileEntity shop;

  const ProfessionalShopEarningsPage({super.key, required this.shop});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Earnings & Reports',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Filter Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sales Performance',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Row(
                    children: [
                      Text('This Month', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // KPI Overview Cards (Matching Reference Image)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Sales', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        const SizedBox(height: 6),
                        Text(
                          '₹${shop.todaySales > 0 ? (shop.todaySales * 10).toInt() : 125000}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Orders', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        const SizedBox(height: 6),
                        Text(
                          '${shop.totalOrders > 0 ? shop.totalOrders : 520}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F766E)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Net Earnings Highlight Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Net Merchant Earnings', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        '₹${shop.netEarnings > 0 ? (shop.netEarnings * 10).toInt() : 25600}',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const Icon(Icons.account_balance_wallet_rounded, color: Colors.white54, size: 36),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Top Selling Products Section (Matching Reference Image)
            const Text(
              'Top Selling Products',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                children: [
                  _buildTopProductRow('Apple - Fresh', '120 kg', Icons.apple_rounded, Colors.red.shade400),
                  const Divider(height: 18),
                  _buildTopProductRow('Potato - Local', '210 kg', Icons.eco_rounded, Colors.amber.shade700),
                  const Divider(height: 18),
                  _buildTopProductRow('Onion - Fresh', '180 kg', Icons.circle_rounded, Colors.purple.shade400),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductRow(String name, String volume, IconData icon, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Text(name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          ],
        ),
        Text(volume, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
      ],
    );
  }
}

