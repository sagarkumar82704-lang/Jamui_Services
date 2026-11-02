import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/widgets/data_table_view.dart';
import '../../../../core/widgets/status_badge.dart';

class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _leads = [];

  @override
  void initState() {
    super.initState();
    _fetchLeads();
  }

  Future<void> _fetchLeads() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('leads').limit(50).get();
      setState(() {
        _leads = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: DataTableView(
        title: 'Lead Management & Flow Audit',
        isLoading: _isLoading,
        columns: const [
          DataColumnItem(label: 'LEAD ID'),
          DataColumnItem(label: 'CUSTOMER'),
          DataColumnItem(label: 'PROVIDER'),
          DataColumnItem(label: 'SERVICE'),
          DataColumnItem(label: 'STATUS'),
        ],
        rows: _leads.map((l) {
          return DataRow(
            cells: [
              DataCell(Text(l['id'].toString().substring(0, 8))),
              DataCell(Text(l['customerName'] ?? 'N/A')),
              DataCell(Text(l['providerName'] ?? 'N/A')),
              DataCell(Text(l['serviceName'] ?? 'General Inquiry')),
              DataCell(StatusBadge.fromStatus(l['status'] ?? 'new')),
            ],
          );
        }).toList(),
      ),
    );
  }
}
