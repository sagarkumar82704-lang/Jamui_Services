import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../widgets/add_edit_plan_dialog.dart';

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchReportQuery = '';
  String _selectedReportFilter = 'all'; // 'all', 'active', 'expiring_soon', 'expired'
  String _normalAudienceFilter = 'all'; // 'all', 'new_provider', 'existing_provider'
  String _premiumAudienceFilter = 'all'; // 'all', 'new_provider', 'existing_provider'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header & Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('प्रोवाइडर सब्सक्रिप्शन एवं डायनामिक प्लान्स (Subscriptions)', style: AppTextStyles.h2),
                      const SizedBox(height: 4),
                      Text(
                        'Normal एवं Premium श्रेणी के अलग-अलग प्लान्स, New Provider व Renewal नीतियां, कीमतें और कोटा स्वतंत्र रूप से प्रबंधित करें।',
                        style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => AddEditPlanDialog.show(context, defaultTier: 'normal', defaultAudience: 'new_provider'),
                      icon: const Icon(Icons.layers_rounded, size: 16),
                      label: const Text('+ नया Normal प्लान'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => AddEditPlanDialog.show(context, defaultTier: 'premium', defaultAudience: 'new_provider'),
                      icon: const Icon(Icons.workspace_premium_rounded, size: 16),
                      label: const Text('+ नया Premium प्लान ⭐'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade900,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Information Banner: Pending Approvals location guidance
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB), // Amber 50
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.amber.shade900, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'नए प्रोवाइडर्स के सब्सक्रिप्शन पेमेंट्स व अप्रूवल्स: नए भुगतान को सत्यापित व सक्रिय (Approve & Activate) करने के लिए साइडबार में "Payments" (Tab 0: लंबित अनुमोदन / Pending Approvals) पर जाएं।',
                      style: TextStyle(fontSize: 12.5, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.layers_rounded, size: 18),
                    text: 'Normal Plans (मानक प्लान्स)',
                  ),
                  Tab(
                    icon: Icon(Icons.workspace_premium_rounded, size: 18),
                    text: 'Premium Plans (प्रीमियम प्लान्स ⭐)',
                  ),
                  Tab(
                    icon: Icon(Icons.analytics_rounded, size: 18),
                    text: 'सब्सक्रिप्शन व रिन्यूअल रिपोर्ट (History & Report)',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab Views Container
            SizedBox(
              height: 700,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTierPlansSection(planTier: 'normal'),
                  _buildTierPlansSection(planTier: 'premium'),
                  _buildSubscriptionsReportSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1 & 2. Independent Tier Plans Section Builder (Normal vs Premium)
  Widget _buildTierPlansSection({required String planTier}) {
    final isPremium = planTier == 'premium';
    final currentAudienceFilter = isPremium ? _premiumAudienceFilter : _normalAudienceFilter;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('subscription_plans').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        final allPlans = docs.map((d) => {'id': d.id, ...(d.data() as Map<String, dynamic>)}).toList();

        // 1. Authoritative Tier Filter (Normal vs Premium with backward compatibility)
        final tierPlans = allPlans.where((p) {
          final tier = (p['planTier'] as String?)?.trim().toLowerCase();
          if (isPremium) {
            return tier == 'premium';
          } else {
            // Backward-compatible: non-specified or 'normal'
            return tier == 'normal' || tier == null || tier.isEmpty;
          }
        }).toList();

        final newCount = tierPlans.where((p) {
          final aud = (p['targetAudience'] as String?) ?? 'new_provider';
          return aud == 'new_provider' || aud == 'all' || aud.isEmpty;
        }).length;

        final renewalCount = tierPlans.where((p) {
          return (p['targetAudience'] as String?) == 'existing_provider';
        }).length;

        // 2. Audience Sub-filter
        final filteredPlans = tierPlans.where((p) {
          if (currentAudienceFilter == 'all') return true;
          final aud = (p['targetAudience'] as String?) ?? 'new_provider';
          if (currentAudienceFilter == 'new_provider') {
            return aud == 'new_provider' || aud == 'all' || aud.isEmpty;
          } else {
            return aud == 'existing_provider';
          }
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sub-filter bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Text(
                    isPremium ? '⭐ प्रीमियम श्रेणी:' : '📦 मानक (Normal) श्रेणी:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: isPremium ? Colors.amber.shade900 : Colors.blueGrey.shade800,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildAudienceChip(
                    label: 'सभी प्लान्स (${tierPlans.length})',
                    isSelected: currentAudienceFilter == 'all',
                    onTap: () {
                      setState(() {
                        if (isPremium) {
                          _premiumAudienceFilter = 'all';
                        } else {
                          _normalAudienceFilter = 'all';
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildAudienceChip(
                    label: '🌟 नए प्रोवाइडर प्लान्स ($newCount)',
                    isSelected: currentAudienceFilter == 'new_provider',
                    onTap: () {
                      setState(() {
                        if (isPremium) {
                          _premiumAudienceFilter = 'new_provider';
                        } else {
                          _normalAudienceFilter = 'new_provider';
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildAudienceChip(
                    label: '🔄 पुराने प्रोवाइडर / रिन्यूअल प्लान्स ($renewalCount)',
                    isSelected: currentAudienceFilter == 'existing_provider',
                    onTap: () {
                      setState(() {
                        if (isPremium) {
                          _premiumAudienceFilter = 'existing_provider';
                        } else {
                          _normalAudienceFilter = 'existing_provider';
                        }
                      });
                    },
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => AddEditPlanDialog.show(
                      context,
                      defaultTier: planTier,
                      defaultAudience: currentAudienceFilter == 'existing_provider' ? 'existing_provider' : 'new_provider',
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: Text('+ नया ${isPremium ? "प्रीमियम" : "नॉर्मल"} प्लान'),
                  ),
                ],
              ),
            ),

            if (filteredPlans.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isPremium ? Icons.workspace_premium_outlined : Icons.layers_outlined,
                        size: 56,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isPremium
                            ? 'कोई प्रीमियम प्लान उपलब्ध नहीं है।'
                            : 'कोई सामान्य (Normal) प्लान उपलब्ध नहीं है।',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isPremium
                            ? 'प्रीमियम कारीगरों एवं विशेष लिस्टिंग्स हेतु नया प्लान जोड़ें।'
                            : 'मानक प्रदाताओं के लिए न्यू या रिन्यूअल प्लान जोड़ें।',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => AddEditPlanDialog.show(
                          context,
                          defaultTier: planTier,
                          defaultAudience: currentAudienceFilter == 'existing_provider' ? 'existing_provider' : 'new_provider',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPremium ? Colors.amber.shade900 : Colors.blueGrey.shade800,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(isPremium ? '+ पहला प्रीमियम प्लान बनाएं ⭐' : '+ पहला नॉर्मल प्लान बनाएं'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: filteredPlans.length,
                  itemBuilder: (context, index) {
                    final plan = filteredPlans[index];
                    final name = (plan['name'] ?? 'Plan').toString();
                    final price = (plan['price'] as num?)?.toDouble() ?? 199.0;
                    final days = (plan['durationDays'] as num?)?.toInt() ?? 30;
                    final categoryLimit = (plan['categoryLimit'] as num?)?.toInt() ?? 1;
                    final isPopular = plan['isPopular'] == true;
                    final isActive = plan['isActive'] != false;
                    final features = (plan['features'] as List<dynamic>?)?.map((f) => f.toString()).toList() ?? [];

                    final isRenewal = (plan['targetAudience'] as String?) == 'existing_provider';
                    final isMandatory = plan['isPaymentMandatory'] == true;
                    final discount = (plan['discountPercentage'] as num?)?.toDouble() ?? 0.0;
                    final offerNote = (plan['offerDescription'] ?? '').toString();
                    final graceDays = (plan['gracePeriodDays'] as num?)?.toInt() ?? 0;

                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isPremium
                              ? Colors.amber.shade400
                              : (isPopular ? Colors.teal.shade400 : AppColors.border),
                          width: (isPremium || isPopular) ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isPremium
                                ? Colors.amber.shade700.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badges Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Wrap(
                                spacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isPremium ? Colors.amber.shade100 : Colors.blueGrey.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isPremium ? Colors.amber.shade400 : Colors.blueGrey.shade200,
                                      ),
                                    ),
                                    child: Text(
                                      isPremium ? '⭐ PREMIUM' : '📦 NORMAL',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: isPremium ? Colors.amber.shade900 : Colors.blueGrey.shade900,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isRenewal ? Colors.orange.shade50 : Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isRenewal ? Colors.orange.shade300 : Colors.blue.shade200,
                                      ),
                                    ),
                                    child: Text(
                                      isRenewal ? '🔄 Renewal' : '🌟 New Provider',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: isRenewal ? Colors.orange.shade900 : Colors.blue.shade900,
                                      ),
                                    ),
                                  ),
                                  if (isPopular)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(6)),
                                      child: Text('🔥 Popular', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                                    ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    tooltip: 'संपादित करें',
                                    onPressed: () => AddEditPlanDialog.show(
                                      context,
                                      plan: plan,
                                      defaultTier: planTier,
                                      defaultAudience: isRenewal ? 'existing_provider' : 'new_provider',
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    tooltip: 'हटाएं',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('प्लान हटाएं?'),
                                          content: Text('क्या आप सचमुच "$name" प्लान को हटाना चाहते हैं?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('रद्द करें')),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('हटाएं', style: TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await FirebaseFirestore.instance.collection('subscription_plans').doc(plan['id']).delete();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Plan Name & Price
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: AppTextStyles.h3.copyWith(fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '₹${price.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: isPremium ? Colors.amber.shade900 : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'वैधता: $days दिन  •  $categoryLimit सेवा श्रेणी',
                            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, fontSize: 11.5),
                          ),
                          const SizedBox(height: 8),

                          // Quota Tags
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(5)),
                                child: Text(
                                  '${plan['maxActiveListings'] ?? 10} लिस्टिंग्स',
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(5)),
                                child: Text(
                                  '${(((plan['maxTotalStorageBytes'] as num?)?.toInt() ?? (50 * 1024 * 1024)) / (1024 * 1024)).round()} MB स्टोरेज',
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900),
                                ),
                              ),
                              if (plan['isPremiumCategoryEligible'] == true)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(5)),
                                  child: Text(
                                    '⭐ प्रीमियम श्रेणी पात्र',
                                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Specific Policy Badges
                          if (!isRenewal) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isMandatory ? Colors.red.shade50 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isMandatory ? '🔒 रजिस्ट्रेशन के बाद पेमेंट अनिवार्य' : '🔓 रजिस्ट्रेशन के बाद पेमेंट वैकल्पिक',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isMandatory ? Colors.red.shade900 : Colors.black87),
                              ),
                            ),
                          ] else ...[
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (discount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                                    child: Text('🔥 $discount% विशेष छूट', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                                  ),
                                if (graceDays > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(6)),
                                    child: Text('⏳ $graceDays दिन ग्रेस पीरियड', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple.shade900)),
                                  ),
                                if (offerNote.isNotEmpty)
                                  Text('नोट: $offerNote', style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.black54)),
                              ],
                            ),
                          ],
                          const Divider(height: 16),

                          // Features List
                          Expanded(
                            child: ListView(
                              children: features.map((f) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 5.0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text(f, style: const TextStyle(fontSize: 11.5, color: AppColors.textPrimary))),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          // Active Switch
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isActive ? 'सक्रिय (Active 🟢)' : 'निष्क्रिय (Inactive ⏸️)',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isActive ? Colors.green : Colors.grey),
                              ),
                              Switch(
                                value: isActive,
                                onChanged: (val) {
                                  FirebaseFirestore.instance.collection('subscription_plans').doc(plan['id']).update({'isActive': val});
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAudienceChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  // 3. Subscriptions History & Renewal Eligibility Report Section
  Widget _buildSubscriptionsReportSection() {
    return Column(
      children: [
        // Filter and Search Toolbar
        Row(
          children: [
            Expanded(
              flex: 4,
              child: TextField(
                onChanged: (q) => setState(() => _searchReportQuery = q.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'प्रदाता का नाम, फोन या ऑर्डर ID से खोजें...',
                  prefixIcon: Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('सभी (All)')),
                ButtonSegment(value: 'active', label: Text('एक्टिव (Active)')),
                ButtonSegment(value: 'expiring_soon', label: Text('रिन्यूअल पात्र (Soon)')),
                ButtonSegment(value: 'expired', label: Text('समाप्त (Expired)')),
              ],
              selected: {_selectedReportFilter},
              onSelectionChanged: (set) {
                if (set.isNotEmpty) setState(() => _selectedReportFilter = set.first);
              },
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Realtime Data List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('subscriptions').limit(100).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('कोई सब्सक्रिप्शन इतिहास नहीं मिला'));
              }

              final now = DateTime.now();

              final filtered = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final pName = (data['providerName'] ?? data['userName'] ?? '').toString().toLowerCase();
                final orderId = (data['orderId'] ?? '').toString().toLowerCase();
                final planName = (data['planName'] ?? '').toString().toLowerCase();

                if (_searchReportQuery.isNotEmpty) {
                  final match = pName.contains(_searchReportQuery) || orderId.contains(_searchReportQuery) || planName.contains(_searchReportQuery);
                  if (!match) return false;
                }

                final expiryRaw = data['expiryDate'];
                DateTime? expiry;
                if (expiryRaw is Timestamp) {
                  expiry = expiryRaw.toDate();
                } else if (expiryRaw != null) {
                  expiry = DateTime.tryParse(expiryRaw.toString());
                }

                if (_selectedReportFilter == 'active') {
                  return expiry != null && expiry.isAfter(now);
                } else if (_selectedReportFilter == 'expiring_soon') {
                  if (expiry == null) return false;
                  final diff = expiry.difference(now).inDays;
                  return diff >= 0 && diff <= 14;
                } else if (_selectedReportFilter == 'expired') {
                  return expiry != null && expiry.isBefore(now);
                }

                return true;
              }).toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('चुने गए फिल्टर के अनुसार कोई परिणाम नहीं मिला'));
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final doc = filtered[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final providerId = (data['providerId'] ?? 'N/A').toString();
                  final providerName = (data['providerName'] ?? data['userName'] ?? providerId).toString();
                  final planName = (data['planName'] ?? 'Standard').toString();
                  final amount = (data['amountPaid'] ?? data['amount'] ?? 0).toString();
                  final isRenewal = data['isRenewal'] == true;
                  final targetAudience = (data['targetAudience'] ?? (isRenewal ? 'existing_provider' : 'new_provider')).toString();
                  final isExistingAudience = isRenewal || targetAudience == 'existing_provider';

                  final expiryRaw = data['expiryDate'];
                  final startRaw = data['startDate'];
                  DateTime? expiry;
                  String expiryStr = 'N/A';
                  String startStr = 'N/A';

                  if (expiryRaw is Timestamp) {
                    final d = expiryRaw.toDate();
                    expiry = d;
                    expiryStr = '${d.day}/${d.month}/${d.year}';
                  }
                  if (startRaw is Timestamp) {
                    final d = startRaw.toDate();
                    startStr = '${d.day}/${d.month}/${d.year}';
                  }

                  final isExpired = expiry != null && expiry.isBefore(now);
                  final isExpiringSoon = expiry != null && !isExpired && expiry.difference(now).inDays <= 14;
                  final daysLeft = expiry != null ? expiry.difference(now).inDays : 0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: isExistingAudience ? Colors.amber.shade50 : Colors.blue.shade50,
                            child: Icon(
                              isExistingAudience ? Icons.autorenew_rounded : Icons.person,
                              color: isExistingAudience ? Colors.amber.shade900 : Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(providerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isExistingAudience ? Colors.amber.shade100 : Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isExistingAudience ? '🔄 Renewal' : '🌟 New Provider',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: isExistingAudience ? Colors.amber.shade900 : Colors.blue.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'प्लान: $planName (₹$amount) | शुरू: $startStr | समाप्ति: $expiryStr',
                                  style: const TextStyle(fontSize: 11.5, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (isExpired)
                                const Chip(
                                  label: Text('समाप्त (Expired)', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  backgroundColor: Colors.red,
                                  visualDensity: VisualDensity.compact,
                                )
                              else if (isExpiringSoon)
                                Chip(
                                  label: Text('रिन्यूअल पात्र ($daysLeft दिन शेष)', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  backgroundColor: Colors.amber.shade800,
                                  visualDensity: VisualDensity.compact,
                                )
                              else
                                Chip(
                                  label: Text('एक्टिव ($daysLeft दिन शेष)', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  backgroundColor: Colors.green,
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                        ],
                      ),
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
