import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/widgets/data_table_view.dart';
import '../../../../core/widgets/status_badge.dart';

class AdminsPage extends StatefulWidget {
  const AdminsPage({super.key});

  @override
  State<AdminsPage> createState() => _AdminsPageState();
}

class _AdminsPageState extends State<AdminsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _admins = [];

  @override
  void initState() {
    super.initState();
    _fetchAdmins();
  }

  Future<void> _fetchAdmins() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('admin_users').get();
      setState(() {
        _admins = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  void _showAddAdminDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String role = 'super_admin';
    String status = 'active';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add, color: Colors.blue),
              SizedBox(width: 8),
              Text('Add New Admin User'),
            ],
          ),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'उदा. सागर कुमार',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'नाम दर्ज करें' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Admin Email',
                      hintText: 'admin@jamuiservice.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) => (v == null || !v.contains('@')) ? 'वैध ईमेल दर्ज करें' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Admin Role'),
                    items: const [
                      DropdownMenuItem(value: 'super_admin', child: Text('Super Admin (मास्टर एडमिन)')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin (एडमिनિस्ट्रेटर)')),
                      DropdownMenuItem(value: 'support', child: Text('Support (कस्टमर सपोर्ट)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => role = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Account Status'),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active (सक्रिय)')),
                      DropdownMenuItem(value: 'inactive', child: Text('Inactive (निष्क्रिय)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => status = v);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(dialogCtx);
                  setState(() => _isLoading = true);
                  try {
                    await FirebaseFirestore.instance.collection('admin_users').add({
                      'name': nameCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'role': role,
                      'status': status,
                      'createdAt': FieldValue.serverTimestamp(),
                      'lastLogin': null,
                    });
                    messenger.showSnackBar(
                      const SnackBar(content: Text('नया एडमिन सफलतापूर्वक जोड़ा गया।')),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                  _fetchAdmins();
                }
              },
              child: const Text('Save Admin'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: DataTableView(
        title: 'Admin User & Role Permissions Manager',
        isLoading: _isLoading,
        headerAction: ElevatedButton.icon(
          onPressed: _showAddAdminDialog,
          icon: const Icon(Icons.person_add_outlined, size: 16),
          label: const Text('Add Admin'),
        ),
        columns: const [
          DataColumnItem(label: 'NAME'),
          DataColumnItem(label: 'EMAIL'),
          DataColumnItem(label: 'ROLE'),
          DataColumnItem(label: 'STATUS'),
        ],
        rows: _admins.map((a) {
          return DataRow(
            cells: [
              DataCell(Text(a['name'] ?? 'Master Admin')),
              DataCell(Text(a['email'] ?? 'admin@jamuiservice.com')),
              DataCell(Text(a['role'] ?? 'super_admin')),
              DataCell(StatusBadge.fromStatus(a['status'] ?? 'active')),
            ],
          );
        }).toList(),
      ),
    );
  }
}
