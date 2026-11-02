import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/data_table_view.dart';
import '../../../../core/widgets/status_badge.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allCustomers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  String _searchQuery = '';

  int _currentPage = 1;
  static const int _pageSize = 15;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  static String _extractName(Map<String, dynamic> c) {
    final name = (c['fullName'] as String?) ??
        (c['name'] as String?) ??
        (c['displayName'] as String?) ??
        (c['customerName'] as String?) ??
        '';
    return name.trim();
  }

  static String _extractPhone(Map<String, dynamic> c) {
    final phone = (c['phoneNumber'] as String?) ??
        (c['phone'] as String?) ??
        (c['mobile'] as String?) ??
        (c['customerPhone'] as String?) ??
        '';
    return phone.trim();
  }

  static String _extractEmail(Map<String, dynamic> c) {
    final email = (c['email'] as String?) ?? (c['emailAddress'] as String?) ?? '';
    return email.trim();
  }

  static String _extractArea(Map<String, dynamic> c) {
    final area = (c['jamuiArea'] as String?) ??
        (c['area'] as String?) ??
        (c['city'] as String?) ??
        (c['district'] as String?) ??
        '';
    return area.trim();
  }

  static String _extractAddress(Map<String, dynamic> c) {
    final address = (c['address'] as String?) ??
        (c['formattedAddress'] as String?) ??
        (c['fullAddress'] as String?) ??
        '';
    return address.trim();
  }

  static int _extractTimestamp(Map<String, dynamic> c) {
    final created = c['createdAt'] ?? c['timestamp'] ?? c['updatedAt'];
    if (created is Timestamp) return created.millisecondsSinceEpoch;
    if (created is String) {
      final dt = DateTime.tryParse(created);
      if (dt != null) return dt.millisecondsSinceEpoch;
    }
    return 0;
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isLoading = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final Map<String, Map<String, dynamic>> customerMap = {};

      // 1. Fetch from 'users' collection (Primary truth for registered customer accounts)
      try {
        final usersSnap = await firestore.collection('users').get();
        for (final doc in usersSnap.docs) {
          final data = doc.data();
          final role = (data['role'] as String?)?.toLowerCase();
          // Exclude provider accounts from Customer Directory
          if (role == 'provider') continue;

          customerMap[doc.id] = {
            'id': doc.id,
            ...data,
          };
        }
      } catch (e) {
        debugPrint('⚠️ Error querying users collection: $e');
      }

      // 2. Fetch & merge from 'customers' collection (Location caches & legacy customer docs)
      try {
        final custSnap = await firestore.collection('customers').get();
        for (final doc in custSnap.docs) {
          final data = doc.data();
          if (customerMap.containsKey(doc.id)) {
            // Enrich with any non-empty location/address fields
            final existing = customerMap[doc.id]!;
            data.forEach((k, v) {
              if (v != null && v.toString().trim().isNotEmpty) {
                existing.putIfAbsent(k, () => v);
              }
            });
          } else {
            customerMap[doc.id] = {
              'id': doc.id,
              ...data,
            };
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error querying customers collection: $e');
      }

      // 3. Enrich customer names, phones and booking counts from 'leads' collection
      try {
        final leadsSnap = await firestore.collection('leads').limit(300).get();
        for (final doc in leadsSnap.docs) {
          final data = doc.data();
          final cId = (data['customerId'] as String?)?.trim();
          final cName = (data['customerName'] as String?)?.trim();
          final cPhone = (data['customerPhone'] as String?)?.trim();

          if (cId != null && cId.isNotEmpty) {
            if (customerMap.containsKey(cId)) {
              final cust = customerMap[cId]!;
              final existingName = _extractName(cust);
              final existingPhone = _extractPhone(cust);
              if (existingName.isEmpty && cName != null && cName.isNotEmpty) {
                cust['fullName'] = cName;
                cust['name'] = cName;
              }
              if (existingPhone.isEmpty && cPhone != null && cPhone.isNotEmpty) {
                cust['phoneNumber'] = cPhone;
                cust['phone'] = cPhone;
              }
              cust['totalBookings'] = ((cust['totalBookings'] as int?) ?? 0) + 1;
            } else if ((cName != null && cName.isNotEmpty) || (cPhone != null && cPhone.isNotEmpty)) {
              // Customer booked via fast-lead flow
              customerMap[cId] = {
                'id': cId,
                'fullName': cName ?? 'ग्राहक',
                'name': cName ?? 'ग्राहक',
                'phoneNumber': cPhone ?? '',
                'phone': cPhone ?? '',
                'address': data['address'] ?? data['customerAddress'] ?? '',
                'jamuiArea': data['jamuiArea'] ?? '',
                'totalBookings': 1,
                'status': 'active',
              };
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error querying leads collection for customer enrichment: $e');
      }

      final list = customerMap.values.toList();
      // Sort: customers with real names first, then by date descending
      list.sort((a, b) {
        final aHasName = _extractName(a).isNotEmpty;
        final bHasName = _extractName(b).isNotEmpty;
        if (aHasName && !bHasName) return -1;
        if (!aHasName && bHasName) return 1;

        final aTime = _extractTimestamp(a);
        final bTime = _extractTimestamp(b);
        return bTime.compareTo(aTime);
      });

      setState(() {
        _allCustomers = list;
        _filteredCustomers = list;
        _currentPage = 1;
      });
    } catch (e) {
      debugPrint('Error in _fetchCustomers: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onSearch(String query) {
    _searchQuery = query.toLowerCase().trim();
    setState(() {
      _currentPage = 1;
      if (_searchQuery.isEmpty) {
        _filteredCustomers = List.from(_allCustomers);
      } else {
        _filteredCustomers = _allCustomers.where((c) {
          final id = (c['id'] ?? '').toString().toLowerCase();
          final name = _extractName(c).toLowerCase();
          final phone = _extractPhone(c).toLowerCase();
          final email = _extractEmail(c).toLowerCase();
          final area = _extractArea(c).toLowerCase();
          final address = _extractAddress(c).toLowerCase();

          return id.contains(_searchQuery) ||
              name.contains(_searchQuery) ||
              phone.contains(_searchQuery) ||
              email.contains(_searchQuery) ||
              area.contains(_searchQuery) ||
              address.contains(_searchQuery);
        }).toList();
      }
    });
  }

  List<Map<String, dynamic>> get _paginatedCustomers {
    final startIndex = (_currentPage - 1) * _pageSize;
    if (startIndex >= _filteredCustomers.length) return [];
    final endIndex = (startIndex + _pageSize).clamp(0, _filteredCustomers.length);
    return _filteredCustomers.sublist(startIndex, endIndex);
  }

  Future<void> _toggleCustomerStatus(Map<String, dynamic> customer) async {
    final currentStatus = (customer['status'] ?? 'active').toString().toLowerCase();
    final newStatus = currentStatus == 'blocked' ? 'active' : 'blocked';
    final customerId = customer['id']?.toString() ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(newStatus == 'blocked' ? 'ग्राहक को ब्लॉक करें?' : 'ग्राहक को अनब्लॉक करें?'),
        content: Text(
          newStatus == 'blocked'
              ? 'क्या आप इस ग्राहक (${_extractName(customer).isNotEmpty ? _extractName(customer) : customerId.substring(0, 8)}) को ब्लॉक करना चाहते हैं?'
              : 'क्या आप इस ग्राहक को पुनः सक्रिय (Active) करना चाहते हैं?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('रद्द करें')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'blocked' ? Colors.red : AppColors.primary,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(newStatus == 'blocked' ? 'ब्लॉक करें' : 'सक्रिय करें', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && customerId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(customerId).set({
          'status': newStatus,
          'isBlocked': newStatus == 'blocked',
          'statusUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Also sync in customers collection if doc exists
        try {
          await FirebaseFirestore.instance.collection('customers').doc(customerId).set({
            'status': newStatus,
            'isBlocked': newStatus == 'blocked',
          }, SetOptions(merge: true));
        } catch (_) {}

        setState(() {
          customer['status'] = newStatus;
          customer['isBlocked'] = newStatus == 'blocked';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ग्राहक स्थिति सफलतापूर्वक "${newStatus == 'blocked' ? 'Blocked' : 'Active'}" में बदल दी गई।'),
              backgroundColor: newStatus == 'blocked' ? Colors.red : AppColors.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('स्थिति बदलने में त्रुटि: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showCustomerDetailsDialog(Map<String, dynamic> c) {
    final name = _extractName(c);
    final phone = _extractPhone(c);
    final email = _extractEmail(c);
    final area = _extractArea(c);
    final address = _extractAddress(c);
    final status = (c['status'] ?? 'active').toString();
    final totalBookings = c['totalBookings'] ?? 0;
    final lat = c['latitude'];
    final lng = c['longitude'];

    String formattedDate = 'उपलब्ध नहीं';
    final timestamp = _extractTimestamp(c);
    if (timestamp > 0) {
      formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(timestamp));
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'G',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isNotEmpty ? name : 'ग्राहक प्रोफाइल',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${c['id']}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  StatusBadge.fromStatus(status),
                ],
              ),
              const Divider(height: 28),

              // Info Tiles
              _buildDetailRow(Icons.phone, 'मोबाइल नंबर', phone.isNotEmpty ? phone : 'उपलब्ध नहीं', isPhone: phone.isNotEmpty),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.email_outlined, 'ईमेल पता', email.isNotEmpty ? email : 'उपलब्ध नहीं', isEmail: email.isNotEmpty),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.location_city, 'क्षेत्र / ब्लॉक', area.isNotEmpty ? area : 'जमुई'),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.home_outlined, 'पूरा पता', address.isNotEmpty ? address : 'उपलब्ध नहीं'),
              const SizedBox(height: 12),
              if (lat != null && lng != null) ...[
                _buildDetailRow(Icons.pin_drop_outlined, 'GPS को-ऑर्डिनेट्स', '$lat, $lng'),
                const SizedBox(height: 12),
              ],
              _buildDetailRow(Icons.calendar_today_outlined, 'रजिस्ट्रेशन दिनांक', formattedDate),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.history_outlined, 'कुल बुकिंग / सर्विस अनुरोध', '$totalBookings'),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('बंद करें'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isPhone = false, bool isEmail = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        SizedBox(
          width: 140,
          child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              if (isPhone || isEmail)
                IconButton(
                  icon: const Icon(Icons.copy, size: 14, color: AppColors.textMuted),
                  tooltip: 'कॉपी करें',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$label क्लिपबोर्ड पर कॉपी हो गया'), duration: const Duration(seconds: 1)),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final paginated = _paginatedCustomers;
    final totalCount = _filteredCustomers.length;
    final totalPages = (totalCount / _pageSize).ceil().clamp(1, 9999);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: DataTableView(
        title: 'Customer Directory ($totalCount)',
        isLoading: _isLoading,
        onSearch: _onSearch,
        currentPage: _currentPage,
        hasNextPage: _currentPage < totalPages,
        onNextPage: () {
          if (_currentPage < totalPages) setState(() => _currentPage++);
        },
        onPrevPage: () {
          if (_currentPage > 1) setState(() => _currentPage--);
        },
        headerAction: ElevatedButton.icon(
          onPressed: _isLoading ? null : _fetchCustomers,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('रिफ्रेश करें'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        columns: const [
          DataColumnItem(label: 'CUSTOMER ID'),
          DataColumnItem(label: 'NAME'),
          DataColumnItem(label: 'PHONE'),
          DataColumnItem(label: 'EMAIL'),
          DataColumnItem(label: 'AREA / BLOCK'),
          DataColumnItem(label: 'STATUS'),
          DataColumnItem(label: 'ACTIONS'),
        ],
        rows: paginated.map((c) {
          final id = c['id']?.toString() ?? '';
          final shortId = id.length >= 8 ? id.substring(0, 8) : id;
          final name = _extractName(c);
          final phone = _extractPhone(c);
          final email = _extractEmail(c);
          final area = _extractArea(c);
          final status = (c['status'] ?? (c['isBlocked'] == true ? 'blocked' : 'active')).toString();
          final isBlocked = status.toLowerCase() == 'blocked';

          return DataRow(
            cells: [
              DataCell(
                Tooltip(
                  message: id,
                  child: Text(
                    shortId,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
              ),
              DataCell(
                Text(
                  name.isNotEmpty ? name : '—',
                  style: TextStyle(
                    fontWeight: name.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                    color: name.isNotEmpty ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
              ),
              DataCell(
                Text(
                  phone.isNotEmpty ? phone : '—',
                  style: TextStyle(color: phone.isNotEmpty ? AppColors.textPrimary : AppColors.textMuted),
                ),
              ),
              DataCell(
                Text(
                  email.isNotEmpty ? email : '—',
                  style: TextStyle(color: email.isNotEmpty ? AppColors.textPrimary : AppColors.textMuted),
                ),
              ),
              DataCell(
                Text(
                  area.isNotEmpty ? area : 'जमुई',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              DataCell(StatusBadge.fromStatus(status)),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
                      onPressed: () => _showCustomerDetailsDialog(c),
                      tooltip: 'View Profile',
                    ),
                    IconButton(
                      icon: Icon(
                        isBlocked ? Icons.check_circle_outline : Icons.block_outlined,
                        size: 18,
                        color: isBlocked ? Colors.green : Colors.red,
                      ),
                      onPressed: () => _toggleCustomerStatus(c),
                      tooltip: isBlocked ? 'Unblock Customer' : 'Block Customer',
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
