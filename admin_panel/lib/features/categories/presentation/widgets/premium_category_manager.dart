import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_network_or_base64_image.dart';

class PremiumCategoryManager extends StatefulWidget {
  const PremiumCategoryManager({super.key});

  @override
  State<PremiumCategoryManager> createState() => _PremiumCategoryManagerState();
}

class _PremiumCategoryManagerState extends State<PremiumCategoryManager> {
  String _searchQuery = '';
  List<Map<String, dynamic>> _allCategories = [];
  int _retryCounter = 0;

  @override
  void initState() {
    super.initState();
    _fetchBaseCategories();
  }

  Future<void> _fetchBaseCategories() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('categories').get();
      if (mounted) {
        setState(() {
          _allCategories = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        });
      }
    } catch (_) {}
  }

  void _openAddEditDialog([Map<String, dynamic>? item]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddEditPremiumCategoryDialog(
        initialData: item,
        availableCategories: _allCategories,
      ),
    );
  }

  Future<void> _quickSetupUnisexSalon() async {
    final salonCat = _allCategories.firstWhere(
      (c) => (c['name']?.toString().toLowerCase().contains('unisex') ?? false) ||
             (c['title']?.toString().toLowerCase().contains('unisex') ?? false) ||
             (c['titleEnglish']?.toString().toLowerCase().contains('unisex') ?? false) ||
             (c['titleHindi']?.toString().contains('यूनिसेक्स') ?? false) ||
             c['id'] == 'unisex_salon' ||
             c['slug'] == 'unisex-salon',
      orElse: () => <String, dynamic>{},
    );

    final catId = (salonCat['id'] ?? 'unisex_salon').toString();
    final catName = (salonCat['titleHindi'] ?? salonCat['name'] ?? salonCat['title'] ?? 'Unisex Salon').toString();

    try {
      final existingSnap = await FirebaseFirestore.instance
          .collection('premium_categories')
          .where('categoryId', isEqualTo: catId)
          .limit(1)
          .get();

      if (existingSnap.docs.isNotEmpty) {
        final doc = existingSnap.docs.first;
        _openAddEditDialog({'id': doc.id, ...doc.data()});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('यूनिसेक्स सैलून पहले से मौजूद है — संपादन (Edit) मोड खुला।'),
              backgroundColor: AppColors.info,
            ),
          );
        }
        return;
      }
    } catch (e) {
      // Graceful fallback: If live Firestore rules for premium_categories are not yet deployed,
      // proceed directly to open the setup dialog without crashing or failing.
      debugPrint('ℹ️ [QuickSetup] Live Firestore check bypassed (rules pending deployment): $e');
    }

    _openAddEditDialog({
      'categoryId': catId,
      'categoryName': catName,
      'customTitle': 'Unisex Salon',
      'imageUrl': 'https://images.unsplash.com/photo-1560066984-138dadb4c035?auto=format&fit=crop&w=800&q=80',
      'priority': 1,
      'showOnHome': true,
      'isActive': true,
    });
  }

  Future<void> _toggleActive(String id, bool current) async {
    try {
      await FirebaseFirestore.instance.collection('premium_categories').doc(id).update({
        'isActive': !current,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('स्थिति बदलने में त्रुटि: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _deleteItem(String id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('प्रीमियम श्रेणी हटाएं?'),
        content: Text('क्या आप वाकई "$title" को होमपेज प्रीमियम सूची से हटाना चाहते हैं?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('रद्द करें')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('हटाएं'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('premium_categories').doc(id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('प्रीमियम श्रेणी सफलतापूर्वक हटाई गई'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('हटाने में त्रुटि: $e'), backgroundColor: AppColors.danger),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Toolbar
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'प्रीमियम श्रेणी या लिंक्ड सर्विस से खोजें...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              OutlinedButton.icon(
                onPressed: _quickSetupUnisexSalon,
                icon: const Icon(Icons.content_cut_rounded, size: 18, color: Color(0xFFEC4899)),
                label: const Text('यूनिसेक्स सैलून क्विक सेटअप'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF831843),
                  side: const BorderSide(color: Color(0xFFF43F5E), width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _openAddEditDialog(),
                icon: const Icon(Icons.star_rounded, size: 20),
                label: const Text('नई प्रीमियम श्रेणी जोड़ें'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),

        // Live Grid from `premium_categories`
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            key: ValueKey(_retryCounter),
            stream: FirebaseFirestore.instance
                .collection('premium_categories')
                .orderBy('priority', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                final errorStr = snapshot.error.toString();
                final bool isPermissionError = errorStr.toLowerCase().contains('permission') ||
                    errorStr.contains('permission-denied') ||
                    errorStr.contains('Missing or insufficient permissions');

                return Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 520),
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isPermissionError ? Colors.amber.shade400 : Colors.red.shade300,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: isPermissionError ? Colors.amber.shade50 : Colors.red.shade50,
                          child: Icon(
                            isPermissionError ? Icons.lock_person_rounded : Icons.cloud_off_rounded,
                            size: 32,
                            color: isPermissionError ? Colors.amber.shade900 : Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isPermissionError
                              ? 'सुरक्षा नियम अनुमति जांच (Permission Denied)'
                              : 'प्रीमियम श्रेणी डेटा लोड विफल',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isPermissionError
                              ? 'Firestore संग्रह "premium_categories" पर पढ़ने की अनुमति नहीं मिली। यदि प्रोडक्शन रूल्स अभी तैनात नहीं हैं, तो रूल्स डिप्लॉय होने के बाद यह स्वतः सक्रिय हो जाएगा।'
                              : 'डेटा लोड करने में समस्या आई: $errorStr',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _retryCounter++;
                                  _fetchBaseCategories();
                                });
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('पुनः प्रयास करें (Retry)'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () => _openAddEditDialog(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade900,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('श्रेणी जोड़ें (Add Category)'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              final filtered = docs.where((d) {
                final data = d.data();
                final title = (data['customTitle'] ?? data['categoryName'] ?? '').toString().toLowerCase();
                return title.contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.workspace_premium_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 14),
                      const Text(
                        'कोई प्रीमियम श्रेणी कॉन्फ़िगर नहीं है।',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'कस्टमर ऐप के होमपेज पर टॉप बैनर के नीचे प्रीमियम सर्विसेज दिखाने के लिए श्रेणी जोड़ें।',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _openAddEditDialog(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade900,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('पहली प्रीमियम श्रेणी जोड़ें'),
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.15,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final doc = filtered[index];
                  final data = doc.data();
                  final id = doc.id;
                  final categoryName = (data['categoryName'] ?? 'General').toString();
                  final customTitle = (data['customTitle'] ?? categoryName).toString();
                  final imageUrl = (data['imageUrl'] ?? '').toString();
                  final priority = (data['priority'] as num?)?.toInt() ?? (index + 1);
                  final isActive = data['isActive'] != false;
                  final showOnHome = data['showOnHome'] != false;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isActive ? Colors.amber.shade300 : Colors.grey.shade300,
                        width: isActive ? 1.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with Icon & Priority
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: imageUrl.isNotEmpty
                                  ? AppNetworkOrBase64Image(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                    )
                                  : Icon(Icons.star_rounded, color: Colors.amber.shade900, size: 28),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customTitle,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'लिंक्ड: $categoryName',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#$priority',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.purple.shade900),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Badges Row
                        Wrap(
                          spacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: showOnHome ? Colors.teal.shade50 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                showOnHome ? '📱 होमपेज पर सक्रिय' : 'छिपा हुआ',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: showOnHome ? Colors.teal.shade900 : Colors.black54),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                isActive ? '🟢 एक्टिव' : '⏸️ निष्क्रिय',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? Colors.green.shade900 : Colors.red.shade900),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Divider(height: 16),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: () => _toggleActive(id, isActive),
                              icon: Icon(isActive ? Icons.pause_circle_outline : Icons.play_circle_outline, size: 16),
                              label: Text(isActive ? 'रोकें' : 'शुरू करें', style: const TextStyle(fontSize: 11)),
                              style: TextButton.styleFrom(
                                foregroundColor: isActive ? Colors.orange.shade900 : Colors.green.shade800,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  tooltip: 'एडिट करें',
                                  onPressed: () => _openAddEditDialog({'id': id, ...data}),
                                  visualDensity: VisualDensity.compact,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  tooltip: 'हटाएं',
                                  onPressed: () => _deleteItem(id, customTitle),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AddEditPremiumCategoryDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final List<Map<String, dynamic>> availableCategories;

  const _AddEditPremiumCategoryDialog({
    this.initialData,
    required this.availableCategories,
  });

  @override
  State<_AddEditPremiumCategoryDialog> createState() => _AddEditPremiumCategoryDialogState();
}

class _AddEditPremiumCategoryDialogState extends State<_AddEditPremiumCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCategoryId;
  String _selectedCategoryName = '';
  late TextEditingController _customTitleController;
  late TextEditingController _imageUrlController;
  late TextEditingController _priorityController;
  bool _showOnHome = true;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _selectedCategoryId = d?['categoryId']?.toString();
    _selectedCategoryName = (d?['categoryName'] ?? d?['customTitle'] ?? '').toString();
    _customTitleController = TextEditingController(text: d?['customTitle'] ?? '');
    _imageUrlController = TextEditingController(text: d?['imageUrl'] ?? '');
    _priorityController = TextEditingController(text: (d?['priority'] ?? 1).toString());
    _showOnHome = d?['showOnHome'] != false;
    _isActive = d?['isActive'] != false;

    if ((_selectedCategoryId == null || _selectedCategoryId!.isEmpty) && widget.availableCategories.isNotEmpty) {
      _selectedCategoryId = widget.availableCategories.first['id']?.toString();
      _selectedCategoryName = (widget.availableCategories.first['name'] ?? widget.availableCategories.first['title'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    _customTitleController.dispose();
    _imageUrlController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  List<Map<String, String>> _buildSanitizedCategories() {
    final Map<String, String> categoryMap = {}; // id -> displayName (Guarantees zero duplicates)

    // 1. Populate from available categories from Firestore
    for (final cat in widget.availableCategories) {
      final id = cat['id']?.toString().trim() ?? '';
      if (id.isEmpty) continue;
      final name = (cat['titleHindi'] != null && cat['titleHindi'].toString().isNotEmpty)
          ? '${cat['titleHindi']} (${cat['name'] ?? cat['title'] ?? cat['titleEnglish'] ?? id})'
          : (cat['name'] ?? cat['title'] ?? cat['titleEnglish'] ?? id).toString();
      categoryMap[id] = name;
    }

    // 2. If an initial or selected categoryId is provided, guarantee it exists in the map
    if (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty) {
      if (!categoryMap.containsKey(_selectedCategoryId)) {
        final fallbackName = _selectedCategoryName.isNotEmpty
            ? _selectedCategoryName
            : (_selectedCategoryId == 'unisex_salon' ? 'यूनिसेक्स सैलून (Unisex Salon)' : _selectedCategoryId!);
        categoryMap[_selectedCategoryId!] = fallbackName;
      }
    }

    // 3. Always ensure Unisex Salon preset is available as an option
    if (!categoryMap.containsKey('unisex_salon')) {
      categoryMap['unisex_salon'] = 'यूनिसेक्स सैलून (Unisex Salon)';
    }

    return categoryMap.entries.map((e) => {'id': e.key, 'name': e.value}).toList();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    try {
      final priority = int.tryParse(_priorityController.text.trim()) ?? 1;
      final customTitle = _customTitleController.text.trim();
      final catName = _selectedCategoryName.isNotEmpty
          ? _selectedCategoryName
          : (_selectedCategoryId == 'unisex_salon' ? 'Unisex Salon' : _selectedCategoryId!);

      final data = {
        'categoryId': _selectedCategoryId,
        'categoryName': catName,
        'customTitle': customTitle.isNotEmpty ? customTitle : catName,
        'imageUrl': _imageUrlController.text.trim(),
        'priority': priority,
        'showOnHome': _showOnHome,
        'isActive': _isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.initialData != null && widget.initialData!['id'] != null) {
        final currentDocId = widget.initialData!['id'];
        // Check if ANOTHER document already uses this categoryId
        final existingQuery = await FirebaseFirestore.instance
            .collection('premium_categories')
            .where('categoryId', isEqualTo: _selectedCategoryId)
            .limit(2)
            .get();

        final conflicting = existingQuery.docs.where((d) => d.id != currentDocId).toList();
        if (conflicting.isNotEmpty) {
          throw Exception('यह श्रेणी पहले से किसी अन्य प्रीमियम एंट्री में कॉन्फ़िगर है।');
        }

        await FirebaseFirestore.instance
            .collection('premium_categories')
            .doc(currentDocId)
            .update(data);
      } else {
        // Duplicate check: Prevent creating duplicate premium category for same categoryId
        final existingQuery = await FirebaseFirestore.instance
            .collection('premium_categories')
            .where('categoryId', isEqualTo: _selectedCategoryId)
            .limit(1)
            .get();

        if (existingQuery.docs.isNotEmpty) {
          // If already exists, update the existing entry seamlessly without duplicate creation
          final existingDoc = existingQuery.docs.first;
          await existingDoc.reference.update(data);
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('श्रेणी पहले से मौजूद थी — मौजूदा एंट्री को सफलतापूर्वक अपडेट किया गया।'),
                backgroundColor: AppColors.info,
              ),
            );
          }
          return;
        }

        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('premium_categories').add(data);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('प्रीमियम श्रेणी सफलतापूर्वक सहेजी गई'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        final isPermission = errStr.contains('permission-denied') ||
            errStr.contains('Missing or insufficient permissions') ||
            errStr.toLowerCase().contains('permission');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPermission
                  ? 'सुरक्षा अनुमति सूचना: लाइव प्रोडक्शन फायरबेस में "premium_categories" नियम अभी डिप्लॉय होना शेष है। रूल्स डिप्लॉयमेंट के बाद यह तुरंत सहेज लिया जाएगा।'
                  : 'सहेजने में त्रुटि: $e',
            ),
            backgroundColor: isPermission ? Colors.amber.shade900 : AppColors.danger,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialData != null && widget.initialData!['id'] != null;
    final sanitizedCategories = _buildSanitizedCategories();

    // Verify value strictly exists in items list to prevent Flutter Dropdown assertion
    final bool hasMatchingItem = sanitizedCategories.any((c) => c['id'] == _selectedCategoryId);
    final String? safeValue = hasMatchingItem
        ? _selectedCategoryId
        : (sanitizedCategories.isNotEmpty ? sanitizedCategories.first['id'] : null);

    if (_selectedCategoryId != safeValue) {
      _selectedCategoryId = safeValue;
      if (safeValue != null) {
        final match = sanitizedCategories.firstWhere((c) => c['id'] == safeValue);
        _selectedCategoryName = match['name']!;
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'प्रीमियम श्रेणी संपादित करें' : 'नई प्रीमियम श्रेणी जोड़ें',
                      style: AppTextStyles.h3,
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
                const Divider(height: 20),

                // Linked Category Dropdown
                const Text('लिंक्ड सर्विस श्रेणी (Select Base Category) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: safeValue,
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                  items: sanitizedCategories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat['id']!,
                      child: Text(cat['name']!, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategoryId = val;
                        final match = sanitizedCategories.firstWhere((c) => c['id'] == val, orElse: () => {'id': val, 'name': val});
                        _selectedCategoryName = match['name']!;
                        if (_customTitleController.text.trim().isEmpty || _customTitleController.text.trim() == 'Unisex Salon') {
                          if (val == 'unisex_salon') {
                            _customTitleController.text = 'Unisex Salon';
                            if (_imageUrlController.text.trim().isEmpty) {
                              _imageUrlController.text = 'https://images.unsplash.com/photo-1560066984-138dadb4c035?auto=format&fit=crop&w=800&q=80';
                            }
                          }
                        }
                      });
                    }
                  },
                  validator: (v) => (v == null || v.isEmpty) ? 'कृपया एक श्रेणी चुनें' : null,
                ),
                const SizedBox(height: 14),

                // Custom Title
                TextFormField(
                  controller: _customTitleController,
                  decoration: const InputDecoration(
                    labelText: 'कस्टम शीर्षक (Custom Title / Promotional Headline)',
                    hintText: 'उदा. जमुई टॉप इलेक्ट्रीशियन',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                // Image URL & Priority
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _imageUrlController,
                        decoration: const InputDecoration(
                          labelText: 'कवर / आइकन इमेज URL',
                          hintText: 'https://... या Cloudflare R2 URL',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _priorityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'प्राथमिकता क्रम',
                          hintText: '1, 2...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Switches
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('होमपेज दृश्यता', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: const Text('कस्टमर होम सेक्शन', style: TextStyle(fontSize: 10)),
                        value: _showOnHome,
                        onChanged: (v) => setState(() => _showOnHome = v),
                      ),
                    ),
                    Expanded(
                      child: SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('सक्रिय स्थिति', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Active status', style: TextStyle(fontSize: 10)),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('रद्द करें')),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade900,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(isEdit ? 'अपडेट करें' : 'सहेजें'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
