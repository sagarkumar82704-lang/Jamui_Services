import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/widgets/data_table_view.dart';
import '../../../../core/widgets/status_badge.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _bookings = [];

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final fs = FirebaseFirestore.instance;
      // Fetch customer requests from leads collection (used by customer & provider apps)
      final leadsSnap = await fs.collection('leads').limit(50).get();
      final bookingsSnap = await fs.collection('bookings').limit(50).get();

      final List<Map<String, dynamic>> combined = [];
      for (final d in leadsSnap.docs) {
        combined.add({'id': d.id, 'source': 'lead', ...d.data()});
      }
      for (final d in bookingsSnap.docs) {
        combined.add({'id': d.id, 'source': 'booking', ...d.data()});
      }

      if (!mounted) return;
      setState(() {
        _bookings = combined;
      });
    } catch (_) {}
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: DataTableView(
        title: 'Bookings & Service Requests Directory',
        isLoading: _isLoading,
        columns: const [
          DataColumnItem(label: 'BOOKING ID'),
          DataColumnItem(label: 'CUSTOMER'),
          DataColumnItem(label: 'PROVIDER'),
          DataColumnItem(label: 'SERVICE'),
          DataColumnItem(label: 'DATE & TIME'),
          DataColumnItem(label: 'STATUS'),
        ],
        rows: _bookings.map((b) {
          final idStr = b['id']?.toString() ?? '';
          final shortId = idStr.length >= 8 ? idStr.substring(0, 8) : idStr;
          final customer =
              (b['customerName'] ?? b['customerPhone'] ?? 'Customer')
                  .toString();
          final provider =
              (b['providerName'] ?? b['businessName'] ?? 'Provider').toString();
          final service = (b['categoryTitle'] ?? b['serviceName'] ?? 'Service')
              .toString();
          final timeSlot =
              (b['preferredTimeSlot'] ??
                      b['bookingDate'] ??
                      b['createdAt']?.toString() ??
                      'N/A')
                  .toString();
          final status = (b['status'] ?? 'pending').toString();

          return DataRow(
            cells: [
              DataCell(
                Text(
                  shortId,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataCell(Text(customer)),
              DataCell(Text(provider)),
              DataCell(Text(service)),
              DataCell(Text(timeSlot)),
              DataCell(StatusBadge.fromStatus(status)),
            ],
          );
        }).toList(),
      ),
    );
  }
}
