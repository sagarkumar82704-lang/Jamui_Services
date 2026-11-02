import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/widgets/data_table_view.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key});

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchAuditLogs();
  }

  Future<void> _fetchAuditLogs() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('audit_logs')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();
      setState(() {
        _logs = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: DataTableView(
        title: 'Immutable System Audit Logs',
        isLoading: _isLoading,
        columns: const [
          DataColumnItem(label: 'TIMESTAMP'),
          DataColumnItem(label: 'ADMIN EMAIL'),
          DataColumnItem(label: 'ACTION'),
          DataColumnItem(label: 'TARGET ID'),
        ],
        rows: _logs.map((l) {
          final ts = l['timestamp'] != null
              ? (l['timestamp'] as Timestamp).toDate().toString().substring(0, 19)
              : 'Recent';
          return DataRow(
            cells: [
              DataCell(Text(ts)),
              DataCell(Text(l['adminEmail'] ?? 'System')),
              DataCell(Text(l['action'] ?? 'LOG')),
              DataCell(Text(l['targetId'] ?? '-')),
            ],
          );
        }).toList(),
      ),
    );
  }
}
