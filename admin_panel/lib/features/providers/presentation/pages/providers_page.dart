import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/admin_image_utils.dart';
import '../../../../core/widgets/data_table_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/whatsapp_image_viewer.dart';
import '../../data/models/provider_filter_criteria.dart';
import '../widgets/provider_advanced_filter_bar.dart';

class ProvidersPage extends StatefulWidget {
  const ProvidersPage({super.key});

  @override
  State<ProvidersPage> createState() => _ProvidersPageState();
}

class _ProvidersPageState extends State<ProvidersPage> {
  int _selectedTab = 0; // 0 = Directory, 1 = Other Service Applications
  bool _isLoading = true;
  String? _fetchError;
  List<Map<String, dynamic>> _providers = [];
  int _dbTotalProvidersCount = 0;
  List<String> _distinctAreas = [];

  // Advanced Filter state
  ProviderFilterCriteria _filterCriteria = ProviderFilterCriteria.initial;
  final TextEditingController _searchController = TextEditingController();

  // Pagination state
  int _currentPage = 1;
  int _pageSize = 25;

  bool _isLoadingCustomApps = false;
  String _customAppsSearchQuery = '';
  List<Map<String, dynamic>> _customApplications = [];
  List<Map<String, dynamic>> _adminCategories = [];

  @override
  void initState() {
    super.initState();
    _fetchProviders();
    _fetchCustomApplications();
    _fetchAdminCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProviders() async {
    setState(() {
      _isLoading = true;
      _fetchError = null;
    });
    try {
      // 1. Fetch exact total database count via Firestore aggregation
      try {
        final countSnap = await FirebaseFirestore.instance.collection('providers').count().get();
        _dbTotalProvidersCount = countSnap.count ?? 0;
      } catch (e) {
        debugPrint('Could not fetch server provider count: $e');
      }

      // 2. Fetch providers collection (order by createdAt descending when possible)
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await FirebaseFirestore.instance
            .collection('providers')
            .orderBy('createdAt', descending: true)
            .limit(500)
            .get();
      } catch (_) {
        // Fallback without orderBy in case createdAt is unindexed or missing on legacy documents
        snap = await FirebaseFirestore.instance.collection('providers').limit(500).get();
      }



      final list = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      final Set<String> areasSet = {
        'जमुई मुख्य बाजार',
        'झाझा (Jhajha)',
        'सोनो (Sono)',
        'खैरा (Khaira)',
        'चकाई (Chakai)',
        'गिद्धौर (Gidhaur)',
        'बरहट (Barhat)',
        'अलीगंज (Aliganj)',
        'सिकंदरा (Sikandra)',
        'इस्लाम नगर (Islam Nagar)',
      };
      for (final p in list) {
        final area = (p['jamuiArea'] ?? p['area'] ?? '').toString().trim();
        if (area.isNotEmpty) areasSet.add(area);
      }
      final sortedAreas = areasSet.toList()..sort();

      setState(() {
        _providers = list;
        _distinctAreas = sortedAreas;
        if (_dbTotalProvidersCount == 0) {
          _dbTotalProvidersCount = list.length;
        }
      });
    } catch (e) {
      debugPrint('Error fetching providers in admin: $e');
      setState(() {
        _fetchError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchCustomApplications() async {
    setState(() => _isLoadingCustomApps = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('custom_service_applications').get();
      final list = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      try {
        final catSnap = await FirebaseFirestore.instance.collection('category_requests').get();
        final existingIds = list.map((e) => e['id']).toSet();
        for (var doc in catSnap.docs) {
          if (!existingIds.contains(doc.id)) {
            list.add({'id': doc.id, ...doc.data()});
          }
        }
      } catch (_) {}

      list.sort((a, b) {
        final aTime = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final bTime = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
      setState(() {
        _customApplications = list;
      });
    } catch (e) {
      debugPrint('Error fetching custom service applications: $e');
    }
    setState(() => _isLoadingCustomApps = false);
  }

  Future<void> _fetchAdminCategories() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('categories').get();
      final baseList = snap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .where((c) => c['isDeleted'] != true && c['isActive'] != false).toList(); /*
          .toList();
      setState(() {
*/    final Set<String> premiumCatIds = {};
      final Map<String, Map<String, dynamic>> premiumMeta = {};
      try {
        final premSnap = await FirebaseFirestore.instance.collection('premium_categories').get();
        for (var pDoc in premSnap.docs) {
          final pData = pDoc.data();
          if (pData['isActive'] != false && pData['isDeleted'] != true) {
            final catId = (pData['categoryId'] ?? pDoc.id).toString().trim();
            if (catId.isNotEmpty) {
              premiumCatIds.add(catId);
              premiumMeta[catId] = pData;
            }
          }
        }
      } catch (err) {
        debugPrint('Note: Error fetching premium_categories: $err');
      }

      final List<Map<String, dynamic>> enrichedList = [];
      final Set<String> processedIds = {};

      for (var c in baseList) {
        final id = c['id'].toString().trim();
        processedIds.add(id);
        final isPrem = (c['categoryType']?.toString().toLowerCase() == 'premium') ||
            (c['isPremium'] == true) ||
            premiumCatIds.contains(id) ||
            id == 'unisex_salon' ||
            id == 'salon';
        c['categoryType'] = isPrem ? 'premium' : 'general';
        c['isPremium'] = isPrem;
        enrichedList.add(c);
      }

      for (var pEntry in premiumMeta.entries) {
        if (!processedIds.contains(pEntry.key)) {
          final pData = pEntry.value;
          enrichedList.add({
            'id': pEntry.key,
            'titleHindi': pData['customTitle'] ?? pData['categoryName'] ?? pData['title'] ?? pEntry.key,
            'titleEnglish': pData['categoryName'] ?? pData['customTitle'] ?? pEntry.key,
            'categoryType': 'premium',
            'isPremium': true,
            'isActive': true,
          });
          processedIds.add(pEntry.key);
        }
      }

      enrichedList.sort((a, b) {
        final aPrem = a['isPremium'] == true ? 0 : 1;
        final bPrem = b['isPremium'] == true ? 0 : 1;
        if (aPrem != bPrem) return aPrem.compareTo(bPrem);
        final aTitle = (a['titleHindi'] ?? a['titleEnglish'] ?? a['id'] ?? '').toString();
        final bTitle = (b['titleHindi'] ?? b['titleEnglish'] ?? b['id'] ?? '').toString();
        return aTitle.compareTo(bTitle);
      });

      if (mounted) setState(() { _adminCategories = enrichedList;
      });
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  Future<void> _updateProviderField(String docId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();

      if (updates['status'] == 'approved') {
        final callable = FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable('adminApproveProvider');
        await callable.call({'providerId': docId});
      } else {
        await FirebaseFirestore.instance.collection('providers').doc(docId).update(updates);
      }
      
      // Audit log (safeguarded)
      try {
        await FirebaseFirestore.instance.collection('audit_logs').add({
          'action': 'PROVIDER_UPDATE',
          'targetId': docId,
          'updates': updates.map((key, value) => MapEntry(key, value.toString())),
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ प्रोवाइडर विवरण सफलतापूर्वक अपडेट हुआ'), backgroundColor: Colors.green),
      );
      _fetchProviders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('अपडेट विफल: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _showToggleActiveDialog(Map<String, dynamic> provider, bool newActive) async {
    final reasonController = TextEditingController();
    final String pName = (provider['fullName'] ?? provider['businessName'] ?? provider['name'] ?? 'Provider').toString();
    final String pPhone = (provider['phoneNumber'] ?? provider['phone'] ?? '-').toString();
    final String pId = (provider['id'] ?? '').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              newActive ? Icons.check_circle_outline : Icons.pause_circle_outline,
              color: newActive ? Colors.green : Colors.orange.shade800,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                newActive ? 'प्रदाता खाता सक्रिय करें?' : 'प्रदाता खाता निष्क्रिय करें?',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('प्रदाता (Provider): $pName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text('मोबाइल (Phone): $pPhone', style: const TextStyle(fontSize: 12)),
                    Text('UID: $pId', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.blueGrey)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                newActive
                    ? '• खाता तुरंत पुनः सक्रिय (Active) हो जाएगा।\n• यदि सब्सक्रिप्शन और सत्यापन स्वीकृत हैं, तो प्रदाता ग्राहक ऐप पर दिखाई देगा।'
                    : '• खाता तुरंत निष्क्रिय (Inactive) हो जाएगा।\n• ग्राहक ऐप की सर्च और लिस्टिंग से प्रदाता छिप जाएगा।\n• प्रदाता के डैशबोर्ड पर निष्क्रियता का कारण प्रदर्शित होगा।\n• नई ग्राहक लीड्स तुरंत ब्लॉक हो जाएंगी।',
                style: TextStyle(fontSize: 12.5, color: newActive ? Colors.green.shade900 : Colors.orange.shade900, height: 1.4),
              ),
              if (!newActive) ...[
                const SizedBox(height: 14),
                const Text('निष्क्रिय करने का कारण (Reason for Deactivation):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'उदा. शिकायत, असत्यापित दस्तावेज, या अस्थायी निलंबन...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(10),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('रद्द करें (Cancel)'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newActive ? Colors.green : Colors.orange.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(newActive ? 'हाँ, सक्रिय करें (Activate)' : 'हाँ, निष्क्रिय करें (Deactivate)'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable('adminToggleProviderStatus');
      final resp = await callable.call({
        'providerId': pId,
        'isActive': newActive,
        'reason': reasonController.text.trim(),
      });

      if (mounted) Navigator.pop(context); // close loader

      if (resp.data != null && resp.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ प्रदाता खाता सफलतापूर्वक ${newActive ? "सक्रिय" : "निष्क्रिय"} किया गया'),
              backgroundColor: newActive ? Colors.green : Colors.orange.shade800,
            ),
          );
        }
        await _fetchProviders();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // close loader
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('कार्रवाई विफल: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showSoftDeleteDialog(Map<String, dynamic> provider) async {
    final reasonController = TextEditingController();
    final String pName = (provider['fullName'] ?? provider['businessName'] ?? provider['name'] ?? 'Provider').toString();
    final String pPhone = (provider['phoneNumber'] ?? provider['phone'] ?? '-').toString();
    final String pId = (provider['id'] ?? '').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'प्रदाता सुरक्षित रूप से हटाएं? (Safe Soft Delete)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('प्रदाता (Provider): $pName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                    const SizedBox(height: 2),
                    Text('मोबाइल (Phone): $pPhone', style: const TextStyle(fontSize: 12)),
                    Text('UID: $pId', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.blueGrey)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'सुरक्षा व डेटा संरक्षण प्रभाव:\n'
                '1. प्रदाता तुरंत ग्राहक ऐप से हटा दिया जाएगा (Unlisted & Hidden)।\n'
                '2. प्रदाता का Firebase Auth लॉगिन स्थायी रूप से अक्षम (Disabled) हो जाएगा।\n'
                '3. सभी ऐतिहासिक पेमेंट्स, रिफंड्स, और ऑडिट लॉग्स डेटा सुरक्षा और ऑडिट नियमों के तहत सुरक्षित रहेंगे।',
                style: TextStyle(fontSize: 12, height: 1.45, color: Colors.black87),
              ),
              const SizedBox(height: 14),
              const Text('हटाने का कारण (Reason for Deletion):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)),
              const SizedBox(height: 6),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'उदा. प्रदाता का अनुरोध, अनधिकृत गतिविधि या स्थायी प्रतिबंध...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('रद्द करें (Cancel)'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('हाँ, सुरक्षित हटाएं (Delete & Revoke)'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable('adminSoftDeleteProvider');
      final resp = await callable.call({
        'providerId': pId,
        'reason': reasonController.text.trim(),
      });

      if (mounted) Navigator.pop(context); // close loader

      if (resp.data != null && resp.data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ प्रदाता खाता सुरक्षित रूप से हटाया गया और एक्सेस रद्द कर दिया गया'),
              backgroundColor: Colors.red,
            ),
          );
        }
        await _fetchProviders();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // close loader
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('हटाने में त्रुटि: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showPermanentDeleteSuccess(String pName) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ प्रदाता ($pName) का खाता, स्टोरेज फाइल्स और ऑथेंटिकेशन स्थायी रूप से हटा दिया गया है।'),
        backgroundColor: Colors.green.shade800,
        duration: const Duration(seconds: 4),
      ),
    );
    _fetchProviders();
  }

  void _showPermanentDeleteError(dynamic e) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (errCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('स्थायी विलोपन विफल (Failed)'),
          ],
        ),
        content: Text('त्रुटि विवरण:\n$e\n\nकृपया ऑडिट लॉग या पुनः प्रयास करें।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(errCtx),
            child: const Text('ठीक है'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPermanentDeleteDialog(Map<String, dynamic> provider) async {
    final reasonController = TextEditingController();
    final confirmController = TextEditingController();
    final String pName = (provider['fullName'] ?? provider['businessName'] ?? provider['name'] ?? 'Provider').toString();
    final String pPhone = (provider['phoneNumber'] ?? provider['phone'] ?? '-').toString();
    final String pEmail = (provider['email'] ?? '-').toString();
    final String pId = (provider['id'] ?? '').toString();

    bool isDeleting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sbCtx, setDialogState) {
            final isConfirmed = confirmController.text.trim() == 'DELETE';

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'स्थायी रूप से हटाएं (Permanent Delete)',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Target Profile Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('प्रदाता नाम (Name): $pName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                            const SizedBox(height: 4),
                            Text('मोबाइल नंबर (Phone): $pPhone', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            Text('ईमेल (Email): $pEmail', style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 2),
                            Text('UID: $pId', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.blueGrey)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Strict Warning Banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade400),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'अपरिवर्तनीय विलोपन चेतावनी (Irreversible Deletion):',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.brown),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              '• प्रदाता का मुख्य प्रोफाइल (/providers/{uid}) और सब-कलेक्शंस नष्ट हो जाएंगे।\n'
                              '• Firebase Storage की सभी KYC फ़ाइलें, आधार, पैन, और फ़ोटो स्थायी रूप से डिलीट होंगी।\n'
                              '• प्रदाता का Firebase Auth लॉगिन खाता नष्ट हो जाएगा (वह उसी फ़ोन/ईमेल से दोबारा नया खाता बना सकेगा)।\n'
                              '• वित्तीय लेन-देन रिकॉर्ड्स (Razorpay) से व्यक्तिगत पहचान हटाकर केवल न्यूनतम ऑडिट लेज़र सुरक्षित रखा जाएगा।\n'
                              '• यह क्रिया वापस नहीं लाई जा सकती (CANNOT BE UNDONE)!',
                              style: TextStyle(fontSize: 11.5, height: 1.45, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'हटाने का कारण दर्ज करें (Mandatory Reason):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: reasonController,
                        enabled: !isDeleting,
                        decoration: const InputDecoration(
                          hintText: 'उदा. प्रदाता का स्थायी अनुरोध, फर्जी प्रोफाइल या व्यावसायिक नीति उल्लंघन...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(10),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'पुष्टि के लिए बॉक्स में "DELETE" टाइप करें (Type DELETE):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: confirmController,
                        enabled: !isDeleting,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: InputDecoration(
                          hintText: 'DELETE',
                          hintStyle: TextStyle(color: Colors.red.shade200),
                          border: OutlineInputBorder(borderSide: BorderSide(color: Colors.red.shade400)),
                          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                  child: const Text('रद्द करें (Cancel)'),
                ),
                ElevatedButton.icon(
                  icon: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.delete_forever_rounded, size: 18),
                  label: Text(isDeleting ? 'हटाया जा रहा है...' : 'स्थायी हटाएं (Confirm Permanent Delete)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade800,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.red.shade200,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: (!isConfirmed || isDeleting)
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);
                          try {
                            final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
                                .httpsCallable('adminPermanentDeleteProvider');
                            final resp = await callable.call({
                              'providerId': pId,
                              'confirmationText': 'DELETE',
                              'reason': reasonController.text.trim(),
                            });

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }

                            if (resp.data != null && resp.data['success'] == true) {
                              _showPermanentDeleteSuccess(pName);
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              setDialogState(() => isDeleting = false);
                            }
                            _showPermanentDeleteError(e);
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditCategoryDialog(Map<String, dynamic> provider) async {
    final String pId = (provider['id'] ?? '').toString().trim();
    final String pName = (provider['fullName'] ?? provider['businessName'] ?? provider['name'] ?? 'Service Provider').toString();
    final String pPhone = (provider['phoneNumber'] ?? provider['phone'] ?? '-').toString();
    final String currentCatId = (provider['primaryCategoryId'] ?? provider['categoryId'] ?? provider['selectedCategoryId'] ?? '').toString().trim();
    final String currentCatTitle = (provider['primaryCategoryTitle'] ?? provider['categoryTitle'] ?? provider['category'] ?? (currentCatId.isNotEmpty ? currentCatId : 'अघोषित')).toString();

    final bool isCurrentPremium = (provider['categoryType']?.toString().toLowerCase() == 'premium') ||
        (provider['isPremiumCategory'] == true) ||
        currentCatId == 'unisex_salon' ||
        currentCatId == 'salon';

    final bool isPaidOrActive = (provider['paymentVerified'] == true) || (provider['isSubscriptionActive'] == true);

    String? selectedCatId;
    if (_adminCategories.isNotEmpty) {
      final match = _adminCategories.firstWhere(
        (c) => c['id'] == currentCatId,
        orElse: () => _adminCategories.first,
      );
      selectedCatId = match['id'].toString();
    }

    final reasonController = TextEditingController();
    bool isSubmitting = false;
    String? reasonError;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final selectedCatMap = _adminCategories.firstWhere(
              (c) => c['id'].toString() == selectedCatId,
              orElse: () => <String, dynamic>{},
            );
            final bool isTargetPremium = (selectedCatMap['categoryType']?.toString().toLowerCase() == 'premium') ||
                (selectedCatMap['isPremium'] == true) ||
                selectedCatId == 'unisex_salon' ||
                selectedCatId == 'salon';
            final String targetCatTitle = (selectedCatMap['titleHindi'] ?? selectedCatMap['titleEnglish'] ?? selectedCatMap['name'] ?? selectedCatId ?? '').toString();

            final bool isSameCategory = selectedCatId == currentCatId;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.edit_note_rounded, color: Colors.teal.shade800),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'श्रेणी बदलें (Edit Provider Category)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 540,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Provider Quick Info
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_outline, size: 18, color: Colors.indigo),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    pName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ),
                                Text(
                                  pPhone,
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Provider ID: $pId',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Current Category Details
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'वर्तमान श्रेणी (Current Category):',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currentCatTitle,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'ID: $currentCatId',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isCurrentPremium ? Colors.purple.shade50 : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCurrentPremium ? Colors.purple.shade300 : Colors.blue.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isCurrentPremium ? Icons.workspace_premium : Icons.layers_outlined,
                                  size: 14,
                                  color: isCurrentPremium ? Colors.purple.shade700 : Colors.blue.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isCurrentPremium ? 'Premium Category' : 'Normal Category',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrentPremium ? Colors.purple.shade800 : Colors.blue.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Safety Lock Notice if Provider has Paid / Active Subscription
                      if (isPaidOrActive) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.block, color: Colors.red, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '⛔ श्रेणी परिवर्तन अवरुद्ध (Locked):\nइस प्रोवाइडर का भुगतान सत्यापित (Verified Payment) या सब्सक्रिप्शन पहले से सक्रिय (Active) है। सुरक्षा नीति के अनुसार एक्टिव/पेड प्रोवाइडर की श्रेणी नहीं बदली जा सकती।',
                                  style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w600, fontSize: 13, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        // Select New Category
                        const Text(
                          'नई श्रेणी चुनें (Select New Category) *:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        if (_adminCategories.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                SizedBox(width: 8),
                                Text('कैटलॉग से श्रेणियां लोड हो रही हैं...', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.teal.shade300),
                              color: Colors.teal.shade50.withValues(alpha: 0.3),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _adminCategories.any((c) => c['id'].toString() == selectedCatId)
                                    ? selectedCatId
                                    : (_adminCategories.isNotEmpty ? _adminCategories.first['id'].toString() : null),
                                items: _adminCategories.map((c) {
                                  final catIdStr = c['id'].toString();
                                  final catPrem = c['isPremium'] == true;
                                  final catTitle = (c['titleHindi'] ?? c['titleEnglish'] ?? c['name'] ?? catIdStr).toString();
                                  return DropdownMenuItem<String>(
                                    value: catIdStr,
                                    child: Row(
                                      children: [
                                        Icon(
                                          catPrem ? Icons.workspace_premium : Icons.build_outlined,
                                          size: 16,
                                          color: catPrem ? Colors.purple.shade700 : Colors.teal.shade700,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '$catTitle ($catIdStr)',
                                            style: TextStyle(
                                              fontWeight: catPrem ? FontWeight.bold : FontWeight.normal,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: catPrem ? Colors.purple.shade100 : Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            catPrem ? 'PREMIUM' : 'NORMAL',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: catPrem ? Colors.purple.shade900 : Colors.grey.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: isSubmitting
                                    ? null
                                    : (val) {
                                        if (val != null) {
                                          setDialogState(() => selectedCatId = val);
                                        }
                                      },
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),

                        // Transition Type & Explanation Banner
                        if (selectedCatId != null && !isSameCategory) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isTargetPremium ? Colors.purple.shade50 : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isTargetPremium ? Colors.purple.shade200 : Colors.blue.shade200,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  isTargetPremium ? Icons.auto_awesome : Icons.info_outline,
                                  color: isTargetPremium ? Colors.purple.shade800 : Colors.blue.shade800,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isTargetPremium
                                        ? '💡 Normal ➔ Premium बदलाव: श्रेणी बदलने के बाद प्रोवाइडर ऐप में प्रीमियम सब्सक्रिप्शन प्लान्स दिखाई देंगे। प्रोवाइडर को प्रीमियम प्लान का भुगतान करना अनिवार्य होगा।'
                                        : '💡 Premium ➔ Normal बदलाव: श्रेणी बदलने के बाद प्रोवाइडर ऐप में सामान्य (Normal) सब्सक्रिप्शन प्लान्स दिखाई देंगे।',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isTargetPremium ? Colors.purple.shade900 : Colors.blue.shade900,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Mandatory Reason Field
                        TextFormField(
                          controller: reasonController,
                          maxLines: 2,
                          enabled: !isSubmitting,
                          decoration: InputDecoration(
                            labelText: 'श्रेणी बदलने का कारण (Change Reason) *',
                            hintText: 'उदा. पंजीकरण के समय गलत श्रेणी चुनी गई थी / दुकान का सही व्यापार सैलून है',
                            errorText: reasonError,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'नोट: बदलाव का कारण ऑडिट लॉग में हमेशा के लिए सुरक्षित रहेगा।',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('रद्द करें (Cancel)'),
                ),
                if (!isPaidOrActive)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(isSubmitting ? 'सहेज रहे हैं...' : 'सुरक्षित सहेजें (Save Changes)'),
                    onPressed: isSubmitting || isSameCategory
                        ? null
                        : () async {
                            final reason = reasonController.text.trim();
                            if (reason.isEmpty) {
                              setDialogState(() {
                                reasonError = 'कृपया श्रेणी बदलने का कारण अवश्य दर्ज करें।';
                              });
                              return;
                            }
                            setDialogState(() => reasonError = null);

                            // Confirmation Dialog
                            final confirmed = await showDialog<bool>(
                              context: ctx,
                              builder: (cCtx) => AlertDialog(
                                title: const Row(
                                  children: [
                                    Icon(Icons.help_outline, color: Colors.teal),
                                    SizedBox(width: 8),
                                    Text('पुष्टि करें (Confirm Change)'),
                                  ],
                                ),
                                content: Text(
                                  'क्या आप निश्चित रूप से प्रोवाइडर \'$pName\' की श्रेणी \'$currentCatTitle\' से बदलकर \'$targetCatTitle\' (${isTargetPremium ? "प्रीमियम" : "सामान्य"}) करना चाहते हैं?\n\nकारण: $reason',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(cCtx, false),
                                    child: const Text('नहीं (Cancel)'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                                    onPressed: () => Navigator.pop(cCtx, true),
                                    child: const Text('हाँ, बदलें (Confirm)'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed != true) return;

                            setDialogState(() => isSubmitting = true);
                            try {
                              final callable = FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable('adminChangeProviderCategory');
                              final res = await callable.call({
                                'providerId': pId,
                                'newCategoryId': selectedCatId,
                                'changeReason': reason,
                              });

                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('✅ श्रेणी सफलतापूर्वक बदलकर \'${res.data['newCategoryTitle'] ?? targetCatTitle}\' कर दी गई।'),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                                _fetchProviders();
                              }
                            } catch (err) {
                              if (ctx.mounted) {
                                setDialogState(() => isSubmitting = false);
                              }
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(() {
                                      if (err is FirebaseFunctionsException) {
                                        if (err.code == 'internal' && (err.message == null || err.message == 'internal')) {
                                          return '❌ क्लाउड फंक्शन सर्वर पर उपलब्ध नहीं है (Function adminChangeProviderCategory is not deployed or unreachable on asia-south1).';
                                        }
                                        if (err.code == 'permission-denied') {
                                          return '❌ अनुमति अस्वीकृत: ${err.message ?? "केवल सक्रिय एडमिन ही श्रेणी बदल सकते हैं।"}';
                                        }
                                        if (err.code == 'unauthenticated') {
                                          return '❌ प्रमाणीकरण आवश्यक: कृपया एडमिन पोर्टल में पुनः लॉगिन करें।';
                                        }
                                        if (err.code == 'not-found') {
                                          return '❌ डेटा नहीं मिला: ${err.message ?? "प्रोवाइडर या श्रेणी मौजूद नहीं है।"}';
                                        }
                                        if (err.code == 'failed-precondition') {
                                          return '❌ अमान्य स्थिति: ${err.message ?? "इस स्थिति में श्रेणी नहीं बदली जा सकती।"}';
                                        }
                                        if (err.message != null && err.message!.isNotEmpty && err.message != 'internal') {
                                          return '❌ ${err.message}';
                                        }
                                        return '❌ सर्वर त्रुटि (${err.code}): ${err.message ?? "कृपया पुनः प्रयास करें।"}';
                                      }
                                      return '❌ श्रेणी बदलने में विफलता: $err';
                                    }()),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              }
                            }
                          },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _showProviderDetailModal(Map<String, dynamic> p) {
    final TextEditingController overrideLimitController = TextEditingController(
      text: (p['adminCategoryOverrideLimit'] ?? '').toString(),
    );
    final TextEditingController rejectionReasonController = TextEditingController(
      text: (p['rejectionReason'] ?? '').toString(),
    );
    String selectedStatus = (p['status'] ?? p['verificationStatus'] ?? 'pendingReview').toString();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final String name = (p['fullName'] ?? p['ownerName'] ?? p['name'] ?? 'N/A').toString();
            final String phone = (p['phoneNumber'] ?? p['phone'] ?? 'N/A').toString();
            final String business = (p['businessName'] ?? 'N/A').toString();
            final String businessDesc = (p['businessDescription'] ?? 'N/A').toString();
            final String email = (p['email'] ?? 'N/A').toString();
            final String primaryCategory = (p['primaryCategoryTitle'] ?? p['category'] ?? 'N/A').toString();
            final List<dynamic> categoriesList = (p['selectedCategoryIds'] as List<dynamic>?) ?? [];
            final String plan = (p['subscriptionPlan'] ?? 'free_trial').toString().toUpperCase();
            final String area = (p['jamuiArea'] ?? 'N/A').toString();
            final String address = (p['fullAddress'] ?? 'N/A').toString();
            final double lat = (p['latitude'] as num?)?.toDouble() ?? 0.0;
            final double lng = (p['longitude'] as num?)?.toDouble() ?? 0.0;
            final double visitingCharge = (p['visitingCharge'] as num?)?.toDouble() ?? 0.0;
            final int exp = (p['experienceYears'] as num?)?.toInt() ?? 0;
            final num radius = (p['serviceRadiusKm'] as num?) ?? 10;

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.verified_user, color: Colors.indigo),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$name ($business)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 500,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('संपर्क व प्रोफाइल (Profile & Contact)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              final profilePic = AdminImageUtils.extractProfileImageUrl(p);
                              if (profilePic.isNotEmpty) {
                                WhatsAppImageViewerDialog.show(
                                  context,
                                  imageUrl: profilePic,
                                  title: 'प्रोफाइल फोटो: $name',
                                  subtitle: business,
                                );
                              }
                            },
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.indigo.shade50,
                              backgroundImage: AdminImageUtils.getImageProvider(AdminImageUtils.extractProfileImageUrl(p)),
                              child: AdminImageUtils.getImageProvider(AdminImageUtils.extractProfileImageUrl(p)) == null
                                  ? const Icon(Icons.person, color: Colors.indigo, size: 30)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('मालिक / नाम: $name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('दुकान / बिज़नेस नाम: $business', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (businessDesc != 'N/A' && businessDesc.isNotEmpty)
                        Text('विवरण: $businessDesc', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                      Text('फोन नंबर: $phone | ईमेल: $email'),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Chip(
                            avatar: const Icon(Icons.phone_android, size: 14, color: Colors.green),
                            label: const Text('Mobile OTP Verified 🟢', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            backgroundColor: Colors.green.shade50,
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            avatar: const Icon(Icons.email, size: 14, color: Colors.green),
                            label: const Text('Email Verified 🟢', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            backgroundColor: Colors.green.shade50,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('अनुभव: $exp वर्ष | विज़िटिंग फीस: ₹$visitingCharge | सेवा दायरा: $radius km'),
                      const Divider(height: 20),

                      const Text('अनुभव प्रमाण पत्र सत्यापन (Experience Certificate Verification)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (p['experienceCertificateStatus'] ?? '') == 'verified'
                              ? Colors.green.shade50
                              : ((p['experienceCertificateStatus'] ?? '') == 'pendingReview' ? Colors.amber.shade50 : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (p['experienceCertificateStatus'] ?? '') == 'verified'
                                ? Colors.green.shade300
                                : ((p['experienceCertificateStatus'] ?? '') == 'pendingReview' ? Colors.amber.shade300 : Colors.grey.shade300),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'सर्टिफिकेट स्टेटस: ${(p['experienceCertificateStatus'] ?? '') == 'verified' ? "सत्यापित (Verified ✓)" : ((p['experienceCertificateStatus'] ?? '') == 'pendingReview' ? "समीक्षाधीन (Pending Review ⏳)" : "उपलब्ध नहीं / Not Uploaded")}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: (p['experienceCertificateStatus'] ?? '') == 'verified'
                                    ? Colors.green.shade900
                                    : ((p['experienceCertificateStatus'] ?? '') == 'pendingReview' ? Colors.amber.shade900 : Colors.black87),
                              ),
                            ),
                            if ((p['previousOrganization'] ?? '').toString().isNotEmpty)
                              Text('संस्थान / Employer: ${p['previousOrganization']}'),
                            if ((p['experienceDescription'] ?? '').toString().isNotEmpty)
                              Text('विवरण: ${p['experienceDescription']}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if ((p['experienceCertificateUrl'] ?? '').toString().isNotEmpty) ...[
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      WhatsAppImageViewerDialog.show(
                                        context,
                                        imageUrl: (p['experienceCertificateUrl'] ?? '').toString(),
                                        title: 'अनुभव प्रमाण पत्र: $name',
                                        subtitle: (p['previousOrganization'] ?? '').toString(),
                                      );
                                    },
                                    icon: const Icon(Icons.zoom_in, size: 14),
                                    label: const Text('सर्टिफिकेट देखें (Zoom)'),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.indigo, visualDensity: VisualDensity.compact),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                ElevatedButton.icon(
                                  onPressed: () {
                                    _updateProviderField(p['id'], {
                                      'experienceCertificateStatus': 'verified',
                                      'certificateVerifiedAt': DateTime.now().toIso8601String(),
                                    });
                                    Navigator.pop(ctx);
                                  },
                                  icon: const Icon(Icons.verified, size: 14),
                                  label: const Text('वेरिफाई करें'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    _updateProviderField(p['id'], {
                                      'experienceCertificateStatus': 'rejected',
                                      'certificateRejectionReason': 'अनुभव प्रमाण पत्र स्पष्ट नहीं है या अमान्य है',
                                    });
                                    Navigator.pop(ctx);
                                  },
                                  icon: const Icon(Icons.close, size: 14),
                                  label: const Text('अस्वीकृत करें'),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, visualDensity: VisualDensity.compact),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 20),

                      const Text('स्थान विवरण (GPS & Address)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
                      const SizedBox(height: 6),
                      Text('जमुई क्षेत्र: $area'),
                      Text('पूरा पता: $address'),
                      Text('GPS अक्षांश/देशांतर: $lat, $lng'),
                      const Divider(height: 20),

                      const Text('सब्सक्रिप्शन व भुगतान स्थिति (Subscription & Payment Verification)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: p['paymentVerified'] == true
                              ? Colors.green.shade50
                              : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: p['paymentVerified'] == true
                                ? Colors.green.shade300
                                : Colors.amber.shade300,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  p['paymentVerified'] == true ? Icons.check_circle : Icons.warning_amber,
                                  size: 16,
                                  color: p['paymentVerified'] == true ? Colors.green.shade700 : Colors.amber.shade800,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  p['paymentVerified'] == true
                                      ? 'Razorpay भुगतान सत्यापित (Verified ✓)'
                                      : 'भुगतान असत्यापित / लंबित (Unverified / Hidden on App)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: p['paymentVerified'] == true ? Colors.green.shade900 : Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'प्लान: $plan | वैधता स्थिति: ${p['isSubscriptionActive'] == true ? "सक्रिय (Active)" : (p['paymentVerified'] == true ? "भुगतान सत्यापित — एक्टिवेशन लंबित (Activation Pending)" : "निष्क्रिय / अनपेड (Inactive / Unpaid)")}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (p['paymentVerifiedAt'] != null)
                              Text('भुगतान तिथि: ${p['paymentVerifiedAt']}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                            const SizedBox(height: 4),
                            Text(
                              (p['paymentVerified'] == true && p['isSubscriptionActive'] == true && p['status'] == 'approved')
                                  ? '🟢 ग्राहक ऐप पर दृश्यमान (Live on App)'
                                  : '🔒 ग्राहक ऐप पर अदृश्य (भुगतान / सब्सक्रिप्शन एक्टिवेशन / KYC लंबित)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: (p['paymentVerified'] == true && p['isSubscriptionActive'] == true && p['status'] == 'approved')
                                    ? Colors.green.shade900
                                    : Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('मुख्य कैटगरी: $primaryCategory'),
                      Text('चुनी गई कैटगरीज (IDs): ${categoriesList.isEmpty ? primaryCategory : categoriesList.join(', ')}'),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          const Expanded(
                            child: Text('एडमिन कैटगरी लिमिट ओवरराइड:\n(Admin Category Override Limit)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: overrideLimitController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'उदा. 5',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      const Text('अकाउंट स्थिति (Account Status)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: ['approved', 'rejected', 'pendingReview', 'suspended', 'blocked'].contains(selectedStatus)
                            ? selectedStatus
                            : 'pendingReview',
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'approved', child: Text('KYC स्वीकृत (KYC Approved)')),
                          DropdownMenuItem(value: 'pendingReview', child: Text('रिव्यू हेतु लंबित (Pending Review)')),
                          DropdownMenuItem(value: 'rejected', child: Text('अस्वीकृत (Rejected)')),
                          DropdownMenuItem(value: 'suspended', child: Text('निलंबित (Suspended)')),
                          DropdownMenuItem(value: 'blocked', child: Text('ब्लॉक है (Blocked)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedStatus = val);
                          }
                        },
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'सूचना: KYC स्वीकृति से केवल प्रोफाइल सत्यापित होती है। ग्राहक ऐप पर लाइव होना Payments सेक्शन में भुगतान सत्यापन व सक्रियण पर निर्भर करता है।',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                      if (p['status'] != 'approved') ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.verified_user_outlined, size: 16, color: Colors.indigo),
                          label: const Text('त्वरित KYC स्वीकृति (Approve KYC Only)', style: TextStyle(color: Colors.indigo, fontSize: 12)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showQuickApproveDialog(p);
                          },
                        ),
                      ],
                      if (selectedStatus == 'rejected') ...[
                        const SizedBox(height: 10),
                        const Text('अस्वीकृति का कारण (Rejection Reason):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: rejectionReasonController,
                          decoration: const InputDecoration(
                            hintText: 'उदा. आधार कार्ड स्पष्ट नहीं है या पता अपूर्ण है',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('रद्द करें'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final int? overrideLimit = int.tryParse(overrideLimitController.text.trim());
                    final updates = <String, dynamic>{
                      'status': selectedStatus,
                      'kycStatus': selectedStatus == 'approved' ? 'approved' : (selectedStatus == 'rejected' ? 'rejected' : 'pendingReview'),
                      'verificationStatus': selectedStatus,
                      'isVerified': selectedStatus == 'approved',
                    };
                    if (overrideLimit != null && overrideLimit > 0) {
                      updates['adminCategoryOverrideLimit'] = overrideLimit;
                    }
                    if (selectedStatus == 'rejected' && rejectionReasonController.text.trim().isNotEmpty) {
                      updates['rejectionReason'] = rejectionReasonController.text.trim();
                    } else if (selectedStatus == 'approved') {
                      updates['rejectionReason'] = FieldValue.delete();
                    }
                    Navigator.pop(ctx);
                    _updateProviderField(p['id'], updates);
                  },
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('à¤¸à¥‡à¤µ à¤•à¤°à¥‡à¤‚ / à¤…à¤ªà¤¡à¥‡à¤Ÿ à¤•à¤°à¥‡à¤‚ (Save)'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingAppsCount = _customApplications.where((a) => a['status'] == 'pending_review').length;

    // Apply Advanced Filtering via ProviderFilterEvaluator
    final filtered = _providers
        .where((p) => ProviderFilterEvaluator.matches(p, _filterCriteria))
        .toList();

    // Pagination calculations
    final totalFiltered = filtered.length;
    final totalPages = (totalFiltered / _pageSize).ceil().clamp(1, 999999);
    if (_currentPage > totalPages) {
      _currentPage = totalPages;
    }
    final startIndex = totalFiltered == 0 ? 0 : (_currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize) > totalFiltered ? totalFiltered : (startIndex + _pageSize);
    final paginatedProviders = totalFiltered == 0
        ? <Map<String, dynamic>>[]
        : filtered.sublist(startIndex, endIndex);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Tabs Switcher
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() {
                        _selectedTab = 0;
                        _currentPage = 1;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? Colors.indigo : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.storefront, size: 16, color: _selectedTab == 0 ? Colors.white : Colors.blueGrey),
                            const SizedBox(width: 8),
                            Text(
                              '🏢 प्रोवाइडर डायरेक्टरी (${_providers.length})',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _selectedTab == 0 ? Colors.white : Colors.blueGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() {
                        _selectedTab = 1;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? Colors.indigo : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.assignment_outlined, size: 16, color: _selectedTab == 1 ? Colors.white : Colors.blueGrey),
                            const SizedBox(width: 8),
                            Text(
                              '📝 अन्य सेवा आवेदन (Other Services)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _selectedTab == 1 ? Colors.white : Colors.blueGrey,
                              ),
                            ),
                            if (pendingAppsCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade700,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$pendingAppsCount लंबित',
                                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Tab 0 Quick Stats Indicator
              if (_selectedTab == 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_user_outlined, size: 16, color: Colors.indigo),
                      const SizedBox(width: 6),
                      Text(
                        'कुल डेटाबेस: $_dbTotalProvidersCount | फ़िल्टर: $totalFiltered',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Error Banner if Firestore fetch failed
          if (_fetchError != null && _selectedTab == 0) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'डेटा लोड करने में त्रुटि: $_fetchError',
                      style: const TextStyle(color: Colors.red, fontSize: 12.5),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _fetchProviders,
                    icon: const Icon(Icons.refresh, size: 16, color: Colors.red),
                    label: const Text('पुनः प्रयास करें (Retry)', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          Expanded(
            child: _selectedTab == 0
                ? _buildProvidersTable(
                    paginatedProviders: paginatedProviders,
                    totalFiltered: totalFiltered,
                    totalPages: totalPages,
                    startIndex: startIndex,
                    endIndex: endIndex,
                  )
                : _buildOtherServiceApplicationsTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildProvidersTable({
    required List<Map<String, dynamic>> paginatedProviders,
    required int totalFiltered,
    required int totalPages,
    required int startIndex,
    required int endIndex,
  }) {
    return DataTableView(
      title: 'Service Provider & Multi-Category Directory (Jamui Service)',
      isLoading: _isLoading,
      currentPage: _currentPage,
      hasNextPage: _currentPage < totalPages,
      onNextPage: () => setState(() => _currentPage++),
      onPrevPage: () => setState(() => _currentPage--),
      paginationInfo: 'प्रदाता ${totalFiltered == 0 ? 0 : startIndex + 1}-$endIndex / $totalFiltered (पृष्ठ $_currentPage / $totalPages)',
      rowsPerPageSelector: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('प्रति पृष्ठ: ', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _pageSize,
              isDense: true,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
              items: const [
                DropdownMenuItem(value: 10, child: Text('10')),
                DropdownMenuItem(value: 25, child: Text('25')),
                DropdownMenuItem(value: 50, child: Text('50')),
                DropdownMenuItem(value: 100, child: Text('100')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _pageSize = val;
                    _currentPage = 1;
                  });
                }
              },
            ),
          ),
        ],
      ),
      searchWidget: SizedBox(
        width: 320,
        height: 38,
        child: TextField(
          controller: _searchController,
          onChanged: (q) {
            setState(() {
              _filterCriteria = _filterCriteria.copyWith(searchQuery: q);
              _currentPage = 1;
            });
          },
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'नाम, फ़ोन, ईमेल, दुकान, ID से खोजें...',
            hintStyle: const TextStyle(fontSize: 11.5, color: Colors.grey),
            prefixIcon: const Icon(Icons.search, size: 18, color: Colors.blueGrey),
            suffixIcon: _filterCriteria.searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _filterCriteria = _filterCriteria.copyWith(searchQuery: '');
                        _currentPage = 1;
                      });
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
        ),
      ),
      filterWidget: ProviderAdvancedFilterBar(
        criteria: _filterCriteria,
        onCriteriaChanged: (newCriteria) {
          setState(() {
            _filterCriteria = newCriteria;
            _currentPage = 1;
          });
        },
        onClearAll: () {
          _searchController.clear();
          setState(() {
            _filterCriteria = ProviderFilterCriteria.initial;
            _currentPage = 1;
          });
        },
        availableCategories: _adminCategories,
        availableAreas: _distinctAreas,
        totalCount: _dbTotalProvidersCount > 0 ? _dbTotalProvidersCount : _providers.length,
        filteredCount: totalFiltered,
        onRefresh: _fetchProviders,
      ),
      emptyWidget: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.indigo.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.filter_list_off_rounded, size: 40, color: Colors.indigo),
              ),
              const SizedBox(height: 16),
              const Text(
                'कोई प्रदाता नहीं मिला (No Providers Found)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 6),
              Text(
                _filterCriteria.hasActiveFilters
                    ? 'चुने गए फ़िल्टर मानदंडों के अनुसार कोई प्रदाता रिकॉर्ड नहीं मिला। कृपया फ़िल्टर बदलें या रीसेट करें।'
                    : 'डेटाबेस में कोई प्रदाता रिकॉर्ड उपलब्ध नहीं है।',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
              if (_filterCriteria.hasActiveFilters) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _filterCriteria = ProviderFilterCriteria.initial;
                      _currentPage = 1;
                    });
                  },
                  icon: const Icon(Icons.clear_all_rounded, size: 16),
                  label: const Text('सभी फ़िल्टर साफ़ करें (Reset All Filters)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      columns: const [
        DataColumnItem(label: 'BUSINESS / OWNER'),
        DataColumnItem(label: 'PHONE'),
        DataColumnItem(label: 'CATEGORIES'),
        DataColumnItem(label: 'SUBSCRIPTION'),
        DataColumnItem(label: 'STATUS'),
        DataColumnItem(label: 'ACCOUNT STATE'),
        DataColumnItem(label: 'ACTIONS'),
      ],
      rows: paginatedProviders.map((p) {
        final String ownerName = (p['fullName'] ?? p['ownerName'] ?? p['name'] ?? 'N/A').toString();
        final String businessName = (p['businessName'] ?? '').toString();
        final String phone = (p['phoneNumber'] ?? p['phone'] ?? 'N/A').toString();
        final String primaryCategory = (p['primaryCategoryTitle'] ?? p['category'] ?? 'General').toString();
        final List<dynamic> catList = (p['selectedCategoryIds'] as List<dynamic>?) ?? [];
        final String plan = (p['subscriptionPlan'] ?? 'free_trial').toString().toUpperCase();
        final String status = (p['status'] ?? p['verificationStatus'] ?? 'pending').toString();
        final bool isDeleted = p['isDeleted'] == true;
        final bool isActive = p['isActive'] != false && !isDeleted;

        return DataRow(
          cells: [
            DataCell(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(ownerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  if (businessName.isNotEmpty)
                    Text(businessName, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            DataCell(Text(phone)),
            DataCell(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(primaryCategory, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  if (catList.length > 1)
                    Text('+${catList.length - 1} additional', style: const TextStyle(fontSize: 10, color: Colors.indigo, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            DataCell(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Chip(
                    label: Text(plan, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                    backgroundColor: plan.contains('PREMIUM')
                        ? Colors.purple
                        : (plan.contains('PRO') ? Colors.indigo : Colors.grey.shade700),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (p['paymentVerified'] == true) ...[
                    if (p['isSubscriptionActive'] == true)
                      const Text('✓ Paid & Active', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold))
                    else
                      const Text('⏳ Payment Verified — Activation Pending', style: TextStyle(fontSize: 10, color: Colors.indigo, fontWeight: FontWeight.bold)),
                  ] else
                    const Text('⚠️ Unpaid / Pending', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            DataCell(StatusBadge.fromStatus(status)),
            // Account State Column
            DataCell(
              isDeleted
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline, size: 12, color: Colors.red),
                          SizedBox(width: 4),
                          Text('Deleted', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                        ],
                      ),
                    )
                  : (!isActive
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.pause_circle_outline, size: 12, color: Colors.orange.shade800),
                              const SizedBox(width: 4),
                              Text('Inactive', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline, size: 12, color: Colors.green),
                              SizedBox(width: 4),
                              Text('Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                        )),
            ),
            // Actions Column
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'पूरा विवरण व KYC जांचें (View Details & KYC)',
                    icon: const Icon(Icons.visibility_outlined, color: Colors.indigo),
                    onPressed: () => _showProviderDetailModal(p),
                  ),
                  IconButton(
                    tooltip: 'त्वरित अस्वीकृती (Quick Reject)',
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                    onPressed: () => _showQuickRejectDialog(p),
                  ),
                  // Edit Category Button (Pending & Unpaid Providers)
                  IconButton(
                    tooltip: ((p['paymentVerified'] == true) || (p['isSubscriptionActive'] == true))
                        ? 'सक्रिय/भुगतान किया हुआ खाता (श्रेणी लॉक्ड)'
                        : 'श्रेणी बदलें (Edit Category)',
                    icon: Icon(
                      Icons.category_outlined,
                      color: ((p['paymentVerified'] == true) || (p['isSubscriptionActive'] == true))
                          ? Colors.grey.shade400
                          : Colors.teal.shade700,
                    ),
                    onPressed: () => _showEditCategoryDialog(p),
                  ),
                  if (!isDeleted) ...[
                    // Active / Inactive Toggle Button
                    IconButton(
                      tooltip: isActive ? 'खाता निष्क्रिय करें (Deactivate)' : 'खाता सक्रिय करें (Activate)',
                      icon: Icon(
                        isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                        color: isActive ? Colors.orange.shade800 : Colors.green,
                      ),
                      onPressed: () => _showToggleActiveDialog(p, !isActive),
                    ),
                    // Safe Delete Button (Soft Delete)
                    IconButton(
                      tooltip: 'सॉफ्ट डिलीट (Safe Soft Delete)',
                      icon: const Icon(Icons.delete_outline, color: Colors.orange),
                      onPressed: () => _showSoftDeleteDialog(p),
                    ),
                    // Permanent Delete Button
                    IconButton(
                      tooltip: 'स्थायी रूप से हटाएं (Permanent Delete)',
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: () => _showPermanentDeleteDialog(p),
                    ),
                  ] else ...[
                    // Restore option for deleted providers
                    IconButton(
                      tooltip: 'पुनर्स्थापित करें (Restore Account)',
                      icon: const Icon(Icons.restore, color: Colors.blue),
                      onPressed: () => _showToggleActiveDialog(p, true),
                    ),
                    // Permanent Delete option for already soft-deleted providers
                    IconButton(
                      tooltip: 'स्थायी रूप से हटाएं (Permanent Delete)',
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: () => _showPermanentDeleteDialog(p),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildOtherServiceApplicationsTable() {
    final filtered = _customApplications.where((a) {
      if (_customAppsSearchQuery.isEmpty) return true;
      final q = _customAppsSearchQuery.toLowerCase();
      final name = (a['providerName'] ?? '').toString().toLowerCase();
      final phone = (a['phoneNumber'] ?? '').toString().toLowerCase();
      final service = (a['serviceName'] ?? '').toString().toLowerCase();
      final desc = (a['serviceDescription'] ?? '').toString().toLowerCase();
      final area = (a['jamuiArea'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q) || service.contains(q) || desc.contains(q) || area.contains(q);
    }).toList();

    return DataTableView(
      title: 'अन्य सेवा पंजीकरण आवेदन (Custom Service Applications Review)',
      isLoading: _isLoadingCustomApps,
      onSearch: (q) => setState(() => _customAppsSearchQuery = q),
      columns: const [
        DataColumnItem(label: 'PROVIDER & VERIFIED PHONE'),
        DataColumnItem(label: 'PROPOSED SERVICE'),
        DataColumnItem(label: 'WORK DETAILS'),
        DataColumnItem(label: 'LOCATION / AREA'),
        DataColumnItem(label: 'SUBMITTED ON'),
        DataColumnItem(label: 'STATUS'),
        DataColumnItem(label: 'ACTIONS'),
      ],
      rows: filtered.map((app) {
        final String name = (app['providerName'] ?? 'N/A').toString();
        final String phone = (app['phoneNumber'] ?? 'N/A').toString();
        final String service = (app['serviceName'] ?? 'N/A').toString();
        final String desc = (app['serviceDescription'] ?? '').toString();
        final String area = (app['jamuiArea'] ?? 'Jamui').toString();
        final String status = (app['status'] ?? 'pending_review').toString();
        final int exp = (app['experienceYears'] as num?)?.toInt() ?? 0;
        final double charge = (app['visitingCharge'] as num?)?.toDouble() ?? 0.0;

        return DataRow(
          cells: [
            DataCell(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Row(
                    children: [
                      const Icon(Icons.phone_in_talk, size: 12, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(phone, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                ],
              ),
            ),
            DataCell(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(service, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
                  Text('$exp वर्ष अनुभव • ₹${charge.toInt()}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            DataCell(
              SizedBox(
                width: 200,
                child: Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
            DataCell(Text(area)),
            DataCell(Text(_formatDateTime(app['createdAt']), style: const TextStyle(fontSize: 11))),
            DataCell(_buildStatusBadgeForCustom(status)),
            DataCell(
              IconButton(
                tooltip: 'आवेदन की पूर्ण समीक्षा करें (Review)',
                icon: const Icon(Icons.rate_review_rounded, color: Colors.indigo),
                onPressed: () => _showCustomApplicationDetailModal(app),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    }
    return timestamp.toString();
  }

  void _showCustomApplicationDetailModal(Map<String, dynamic> app) {
    final String appId = app['id'] ?? '';
    final String providerId = app['providerId'] ?? appId;
    final String providerName = (app['providerName'] ?? 'N/A').toString();
    final String currentCat = (app['currentApprovedCategoryTitle'] ?? app['currentApprovedCategoryId'] ?? 'कोई नहीं (नया आवेदन)').toString();
    final String phoneNumber = (app['phoneNumber'] ?? 'N/A').toString();
    final String serviceName = (app['serviceName'] ?? 'N/A').toString();
    final String serviceDescription = (app['serviceDescription'] ?? 'N/A').toString();
    final String offeredServices = (app['offeredServices'] ?? '').toString();
    final int experienceYears = (app['experienceYears'] as num?)?.toInt() ?? 0;
    final double visitingCharge = (app['visitingCharge'] as num?)?.toDouble() ?? 0.0;
    final String fullAddress = (app['fullAddress'] ?? 'N/A').toString();
    final String jamuiArea = (app['jamuiArea'] ?? 'N/A').toString();
    final String currentStatus = (app['status'] ?? 'pending_review').toString();
    final String existingFeedback = (app['adminFeedback'] ?? '').toString();
    final String existingMappedCat = (app['mappedCategoryTitle'] ?? app['mappedCategoryId'] ?? '').toString();

    bool isCreatingNewCategory = false;
    String? selectedCategoryId;
    String selectedCategoryTitle = '';

    if (_adminCategories.isNotEmpty) {
      selectedCategoryId = _adminCategories.first['id'].toString();
      selectedCategoryTitle = (_adminCategories.first['titleHindi'] ?? _adminCategories.first['titleEnglish'] ?? selectedCategoryId).toString();
    }

    final TextEditingController newCatIdController = TextEditingController(
      text: serviceName.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_'),
    );
    final TextEditingController newCatTitleHindiController = TextEditingController(text: serviceName);
    final TextEditingController newCatTitleEngController = TextEditingController(text: serviceName);
    final TextEditingController newCatDescController = TextEditingController(text: serviceDescription);
    final TextEditingController feedbackController = TextEditingController(text: existingFeedback);
    final TextEditingController rejectionReasonController = TextEditingController();
    final TextEditingController infoRequestController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.handyman_rounded, color: Colors.indigo),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'विशेष सेवा आवेदन समीक्षा: $serviceName',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  _buildStatusBadgeForCustom(currentStatus),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 600,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Prominent Verified Mobile Number & Contact Banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFF22C55E),
                              radius: 20,
                              child: Icon(Icons.phone, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'सत्यापित पंजीकृत मोबाइल नंबर (Verified Mobile):',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                                  ),
                                  const SizedBox(height: 2),
                                  SelectableText(
                                    phoneNumber,
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'प्रदाता: $providerName • UID: $providerId',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.chat, size: 14, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text('WhatsApp', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Submitted Work Details Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('कार्य एवं सेवा का पूर्ण विवरण (Submitted Work Details)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
                              const Divider(height: 16),
                              _buildDetailRow('वर्तमान स्वीकृत श्रेणी (Current Category):', currentCat),
                              _buildDetailRow('अनुरोधित सेवा श्रेणी (Requested Service):', serviceName, isBold: true),
                              _buildDetailRow('कार्य विवरण (Description):', serviceDescription),
                              if (offeredServices.isNotEmpty)
                                _buildDetailRow('दी जाने वाली सेवाएं (Offered):', offeredServices),
                              _buildDetailRow('अनुभव व विजिटिंग शुल्क:', '$experienceYears वर्ष का अनुभव • ₹${visitingCharge.toInt()} विजिटिंग चार्ज'),
                              _buildDetailRow('पता व क्षेत्र:', '$fullAddress, $jamuiArea'),
                              _buildDetailRow('सबमिशन समय:', _formatDateTime(app['createdAt'])),
                              if (existingMappedCat.isNotEmpty)
                                _buildDetailRow('मैप की गई श्रेणी:', existingMappedCat, isBold: true),
                              if (existingFeedback.isNotEmpty)
                                _buildDetailRow('पिछला एडमिन संदेश:', existingFeedback),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Category Mapping & Review Options
                      const Text('एडमिन अनुमोदन व श्रेणी मैपिंग (Category Mapping Controls):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('मौजूदा एडमिन श्रेणी में मैप करें'),
                            selected: !isCreatingNewCategory,
                            onSelected: (val) => setModalState(() => isCreatingNewCategory = false),
                          ),
                          const SizedBox(width: 10),
                          ChoiceChip(
                            label: const Text('+ नई श्रेणी बनाएं (Create New Category)'),
                            selected: isCreatingNewCategory,
                            onSelected: (val) => setModalState(() => isCreatingNewCategory = true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (!isCreatingNewCategory) ...[
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'मान्य एडमिन श्रेणी चुनें (Select Existing Category) *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _adminCategories.map((c) {
                            final title = (c['titleHindi'] as String?)?.isNotEmpty == true
                                ? '${c['titleHindi']} (${c['titleEnglish'] ?? c['id']})'
                                : (c['titleEnglish'] ?? c['id']).toString();
                            return DropdownMenuItem<String>(
                              value: c['id'].toString(),
                              child: Text(title),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedCategoryId = val;
                                final cat = _adminCategories.firstWhere((c) => c['id'] == val, orElse: () => {});
                                selectedCategoryTitle = (cat['titleHindi'] ?? cat['titleEnglish'] ?? val).toString();
                              });
                            }
                          },
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('नई श्रेणी विवरण (New Database Category Record):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: newCatTitleHindiController,
                                decoration: const InputDecoration(
                                  labelText: 'श्रेणी का हिंदी नाम (Title Hindi) *',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: newCatTitleEngController,
                                decoration: const InputDecoration(
                                  labelText: 'श्रेणी का अंग्रेजी नाम (Title English) *',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: newCatIdController,
                                decoration: const InputDecoration(
                                  labelText: 'Category ID (Slug) *',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      TextField(
                        controller: feedbackController,
                        decoration: const InputDecoration(
                          labelText: 'एडमिन टिप्पणी / संदेश (Admin Feedback / Note):',
                          hintText: 'उदा. आपकी विशेष श्रेणी स्वीकृत कर दी गई है।',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('बंद करें'),
                ),
                // Request More Info Button
                OutlinedButton.icon(
                  icon: const Icon(Icons.contact_support_outlined, size: 16),
                  label: const Text('अतिरिक्त जानकारी मांगें'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade800,
                    side: BorderSide(color: Colors.orange.shade400),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (infoCtx) => AlertDialog(
                        title: const Text('अतिरिक्त जानकारी का अनुरोध करें'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('प्रदाता: $providerName ($phoneNumber)'),
                            const SizedBox(height: 12),
                            TextField(
                              controller: infoRequestController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'प्रदाता को क्या अतिरिक्त जानकारी देनी होगी? *',
                                hintText: 'उदा. कार्य के औजारों, अनुभव प्रमाण या कार्यस्थल का विवरण भेजें',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(infoCtx), child: const Text('रद्द करें')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                            onPressed: () {
                              final msg = infoRequestController.text.trim();
                              if (msg.isEmpty) return;
                              Navigator.pop(infoCtx);
                              Navigator.pop(ctx);
                              _reviewApplication(
                                applicationId: appId,
                                providerId: providerId,
                                action: 'more_info_required',
                                adminFeedback: msg,
                              );
                            },
                            child: const Text('संदेश भेजें'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // Reject Button
                OutlinedButton.icon(
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('अस्वीकृत करें'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (rejectCtx) => AlertDialog(
                        title: const Text('कस्टम सेवा आवेदन अस्वीकृत करें', style: TextStyle(color: Colors.red)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('सेवा: $serviceName • प्रदाता: $providerName'),
                            const SizedBox(height: 12),
                            TextField(
                              controller: rejectionReasonController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'अस्वीकृति का कारण (Rejection Reason) *',
                                hintText: 'उदा. यह सेवा हमारी नीतियों के अंतर्गत नहीं आती है',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(rejectCtx), child: const Text('रद्द करें')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            onPressed: () {
                              final reason = rejectionReasonController.text.trim();
                              Navigator.pop(rejectCtx);
                              Navigator.pop(ctx);
                              _reviewApplication(
                                applicationId: appId,
                                providerId: providerId,
                                action: 'rejected',
                                adminFeedback: reason.isNotEmpty ? reason : 'कस्टम सेवा आवेदन अस्वीकृत किया गया',
                              );
                            },
                            child: const Text('अस्वीकृत करें'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // Approve & Map Category Button
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('स्वीकृत करें व श्रेणी मैप करें'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                  onPressed: () {
                    Map<String, dynamic>? newCat;
                    String? finalCatId = selectedCategoryId;
                    String? finalCatTitle = selectedCategoryTitle;

                    if (isCreatingNewCategory) {
                      final id = newCatIdController.text.trim();
                      final hi = newCatTitleHindiController.text.trim();
                      final en = newCatTitleEngController.text.trim();
                      if (id.isEmpty || hi.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('कृपया नई श्रेणी का नाम व ID भरें।'), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      newCat = {
                        'id': id,
                        'titleHindi': hi,
                        'titleEnglish': en.isNotEmpty ? en : hi,
                        'description': newCatDescController.text.trim(),
                        'icon': 'handyman',
                        'subServices': offeredServices.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                      };
                      finalCatId = id;
                      finalCatTitle = hi;
                    }

                    if (finalCatId == null || finalCatId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('कृपया मैप करने के लिए श्रेणी चुनें।'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    _reviewApplication(
                      applicationId: appId,
                      providerId: providerId,
                      action: 'approved',
                      mappedCategoryId: finalCatId,
                      mappedCategoryTitle: finalCatTitle,
                      newCategoryData: newCat,
                      adminFeedback: feedbackController.text.trim().isNotEmpty
                          ? feedbackController.text.trim()
                          : 'विशेष सेवा आवेदन स्वीकृत किया गया है।',
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadgeForCustom(String status) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'approved':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        label = 'स्वीकृत (Approved)';
        break;
      case 'rejected':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        label = 'अस्वीकृत (Rejected)';
        break;
      case 'more_info_required':
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFFC2410C);
        label = 'अधिक जानकारी प्रतीक्षित';
        break;
      case 'pending_review':
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = 'लंबित (Pending Review)';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Future<void> _reviewApplication({
    required String applicationId,
    required String providerId,
    required String action, // 'approved' | 'rejected' | 'more_info_required'
    String? mappedCategoryId,
    String? mappedCategoryTitle,
    Map<String, dynamic>? newCategoryData,
    String? adminFeedback,
  }) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final now = FieldValue.serverTimestamp();

      // If creating new category
      if (newCategoryData != null && newCategoryData['id'] != null) {
        final catId = newCategoryData['id'].toString().trim();
        final newCatRef = FirebaseFirestore.instance.collection('categories').doc(catId);
        batch.set(newCatRef, {
          'id': catId,
          'titleHindi': newCategoryData['titleHindi'] ?? catId,
          'titleEnglish': newCategoryData['titleEnglish'] ?? catId,
          'description': newCategoryData['description'] ?? '',
          'icon': newCategoryData['icon'] ?? 'handyman',
          'imageUrl': '',
          'subServices': (newCategoryData['subServices'] as List<dynamic>?) ?? [],
          'priorityOrder': 99,
          'isActive': true,
          'status': 'active',
          'isDeleted': false,
          'createdAt': now,
          'updatedAt': now,
        }, SetOptions(merge: true));

        mappedCategoryId = catId;
        mappedCategoryTitle = (newCategoryData['titleHindi'] as String?)?.isNotEmpty == true
            ? newCategoryData['titleHindi']
            : (newCategoryData['titleEnglish'] ?? catId);
      }

      final appRef = FirebaseFirestore.instance.collection('custom_service_applications').doc(applicationId);
      final providerRef = FirebaseFirestore.instance.collection('providers').doc(providerId);

      if (action == 'approved') {
        batch.update(appRef, {
          'status': 'approved',
          'mappedCategoryId': mappedCategoryId ?? '',
          'mappedCategoryTitle': mappedCategoryTitle ?? '',
          'adminFeedback': adminFeedback ?? 'विशेष सेवा आवेदन स्वीकृत किया गया है।',
          'reviewedAt': now,
          'updatedAt': now,
        });

        batch.update(providerRef, {
          'primaryCategoryId': mappedCategoryId ?? '',
          'primaryCategoryTitle': mappedCategoryTitle ?? '',
          'selectedCategoryIds': FieldValue.arrayUnion([mappedCategoryId]),
          'selectedCategoryId': mappedCategoryId ?? '',
          'customServiceStatus': 'approved',
          'categoryRequestStatus': 'approved',
          'categoryApprovalStatus': 'approved',
          'requestedCategoryId': FieldValue.delete(),
          'requestedCategoryTitle': FieldValue.delete(),
          'categoryRejectionReason': FieldValue.delete(),
          'registrationStatus': 'category_approved',
          'currentStep': 2,
          'updatedAt': now,
        });
      } else if (action == 'rejected') {
        batch.update(appRef, {
          'status': 'rejected',
          'adminFeedback': adminFeedback ?? 'आवेदन अस्वीकृत किया गया।',
          'reviewedAt': now,
          'updatedAt': now,
        });

        batch.update(providerRef, {
          'customServiceStatus': 'rejected',
          'categoryRequestStatus': 'rejected',
          'categoryApprovalStatus': 'rejected',
          'categoryRejectionReason': adminFeedback ?? 'कस्टम सेवा आवेदन अस्वीकृत किया गया',
          'rejectionReason': adminFeedback ?? 'कस्टम सेवा आवेदन अस्वीकृत किया गया',
          'updatedAt': now,
        });
      } else if (action == 'more_info_required') {
        batch.update(appRef, {
          'status': 'more_info_required',
          'adminFeedback': adminFeedback ?? 'कृपया अतिरिक्त जानकारी प्रदान करें।',
          'reviewedAt': now,
          'updatedAt': now,
        });

        batch.update(providerRef, {
          'customServiceStatus': 'more_info_required',
          'rejectionReason': adminFeedback ?? 'कृपया अतिरिक्त जानकारी प्रदान करें',
          'updatedAt': now,
        });
      }

      // Audit log
      final auditRef = FirebaseFirestore.instance.collection('audit_logs').doc();
      batch.set(auditRef, {
        'action': 'CUSTOM_SERVICE_REVIEW',
        'applicationId': applicationId,
        'providerId': providerId,
        'reviewAction': action,
        'mappedCategory': mappedCategoryId ?? 'N/A',
        'feedback': adminFeedback ?? '',
        'timestamp': now,
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(action == 'approved'
              ? '✓ विशेष सेवा आवेदन स्वीकृत व श्रेणी मैप कर दी गई है।'
              : (action == 'rejected' ? '✓ आवेदन अस्वीकृत किया गया।' : '✓ अतिरिक्त जानकारी हेतु संदेश भेजा गया।')),
          backgroundColor: action == 'approved' ? Colors.green : (action == 'rejected' ? Colors.red : Colors.orange),
        ),
      );

      _fetchCustomApplications();
      _fetchProviders();
      _fetchAdminCategories();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('समीक्षा सबमिट विफल: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showQuickRejectDialog(Map<String, dynamic> p) {
    final TextEditingController reasonController = TextEditingController(
      text: (p['rejectionReason'] ?? 'आधार कार्ड / दस्तावेज़ स्पष्ट नहीं है').toString(),
    );

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('प्रोवाइडर अस्वीकृत करें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('प्रोवाइडर: ${(p['fullName'] ?? p['ownerName'] ?? 'N/A')}'),
              const SizedBox(height: 12),
              if (p['paymentVerified'] == true) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.brown),
                          SizedBox(width: 6),
                          Text('भुगतान प्राप्त प्रोवाइडर', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.brown)),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        'रिफंड नीति: अस्वीकृति पर सिस्टम से स्वतः रिफंड नहीं कटेगा। रिफंड की आवश्यकता होने पर कृपया Razorpay डैशबोर्ड से नीति के अनुसार मैन्युअल रिफंड प्रोसेस करें।',
                        style: TextStyle(fontSize: 11, color: Colors.brown),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text('अस्वीकृति का कारण (Rejection Reason):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'उदा. आधार कार्ड स्पष्ट नहीं है या विवरण अधूरा है',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('रद्द करें'),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                Navigator.pop(dialogCtx);
                _updateProviderField(p['id'], {
                  'status': 'rejected',
                  'verificationStatus': 'rejected',
                  'kycStatus': 'rejected',
                  'isVerified': false,
                  'rejectionReason': reason.isNotEmpty ? reason : 'आधार कार्ड / विवरण अमान्य है',
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('अस्वीकृत करें (Reject)'),
            ),
          ],
        );
      },
    );
  }

  void _showQuickApproveDialog(Map<String, dynamic> p) {
    final String pName = (p['fullName'] ?? p['businessName'] ?? p['ownerName'] ?? 'Provider').toString();
    final String pId = (p['id'] ?? '').toString();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: Colors.indigo),
              SizedBox(width: 8),
              Text('प्रोवाइडर KYC स्वीकृत करें (Approve KYC)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('क्या आप प्रदाता "$pName" का KYC स्वीकृत (Approved) करना चाहते हैं?'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• इससे केवल प्रदाता का रजिस्ट्रेशन व KYC विवरण स्वीकृत (Approved ✓) होगा।\n'
                      '• ⚠️ महत्वपूर्ण: यह सब्सक्रिप्शन सक्रिय (Activate) नहीं करता है।\n'
                      '• प्रदाता ग्राहक ऐप पर तभी लाइव होगा जब Payments सेक्शन में उसका भुगतान सत्यापित व सक्रिय किया जाएगा।',
                      style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('रद्द करें'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _updateProviderField(pId, {
                  'status': 'approved',
                  'verificationStatus': 'approved',
                  'kycStatus': 'approved',
                  'isVerified': true,
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              child: const Text('हाँ, केवल KYC स्वीकृत करें (Approve KYC Only)'),
            ),
          ],
        );
      },
    );
  }
}

