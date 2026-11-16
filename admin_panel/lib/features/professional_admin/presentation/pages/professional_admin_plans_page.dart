import 'package:flutter/material.dart';
import '../../data/datasources/professional_admin_remote_data_source.dart';

/// Dedicated Admin Panel Section: Professional Marketplace → Subscription Plans
/// Strictly manages 'diamond_subscription_plans' and has ZERO impact on Normal Providers.
class ProfessionalAdminPlansPage extends StatefulWidget {
  final ProfessionalAdminRemoteDataSource? dataSource;

  const ProfessionalAdminPlansPage({super.key, this.dataSource});

  @override
  State<ProfessionalAdminPlansPage> createState() => _ProfessionalAdminPlansPageState();
}

class _ProfessionalAdminPlansPageState extends State<ProfessionalAdminPlansPage> {
  late final ProfessionalAdminRemoteDataSource _dataSource;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? ProfessionalAdminRemoteDataSource();
  }

  void _openPlanDialog({Map<String, dynamic>? plan}) {
    final isEditing = plan != null;
    final formKey = GlobalKey<FormState>();

    final nameCtrl = TextEditingController(text: plan?['name']?.toString() ?? '');
    final priceCtrl = TextEditingController(
      text: plan != null ? (plan['price'] ?? 0).toString() : '299',
    );
    final durationCtrl = TextEditingController(
      text: plan != null ? (plan['durationDays'] ?? 30).toString() : '30',
    );
    final prodsCtrl = TextEditingController(
      text: plan != null
          ? (plan['maxProducts'] ?? plan['productLimit'] ?? 50).toString()
          : '50',
    );
    final variantsCtrl = TextEditingController(
      text: plan != null
          ? (plan['maxVariantsPerProduct'] ?? plan['variantLimit'] ?? 5).toString()
          : '5',
    );
    final imagesCtrl = TextEditingController(
      text: plan != null
          ? (plan['maxImagesPerMonth'] ?? plan['imageLimit'] ?? 100).toString()
          : '100',
    );
    final storageCtrl = TextEditingController(
      text: plan != null
          ? (plan['storageMb'] ?? plan['storageLimitMb'] ?? 500).toString()
          : '500',
    );

    final rawFeatures = plan?['features'] is Map
        ? Map<String, dynamic>.from(plan!['features'] as Map)
        : <String, dynamic>{};

    bool advancedAnalytics = plan?['advancedAnalytics'] == true || rawFeatures['advancedAnalytics'] == true;
    bool promotionalTools = plan?['promotionalTools'] == true || rawFeatures['promotionalTools'] == true;
    bool lowStockAlerts = plan?['lowStockAlerts'] != false && rawFeatures['lowStockAlerts'] != false;
    bool customAttributes = plan?['customAttributes'] != false && rawFeatures['customAttributes'] != false;

    bool isSaving = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  isEditing ? Icons.edit_note_rounded : Icons.add_card_rounded,
                  color: const Color(0xFF4F46E5),
                ),
                const SizedBox(width: 8),
                Text(
                  isEditing ? 'Edit Professional Plan: ${plan['name'] ?? ''}' : 'Create New Professional Plan',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFEF4444)),
                          ),
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12.5),
                          ),
                        ),

                      // Plan Name
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Plan Name *',
                          hintText: 'e.g. Pro Silver Seller Plan',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Please enter plan name' : null,
                      ),
                      const SizedBox(height: 12),

                      // Price and Duration
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: priceCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Price (₹) *',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                final p = double.tryParse(v?.trim() ?? '');
                                if (p == null || p < 0) return 'Invalid price (≥ 0)';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: durationCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Duration in Days *',
                                hintText: '30, 90, 365',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                final d = int.tryParse(v?.trim() ?? '');
                                if (d == null || d <= 0 || d > 3650) return '1 - 3650 days';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Limits Row 1: Max Products & Max Variants
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: prodsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Max Products Limit *',
                                hintText: '50',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                final p = int.tryParse(v?.trim() ?? '');
                                if (p == null || p <= 0) return 'Must be > 0';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Selling Options',
                                border: OutlineInputBorder(),
                              ),
                              child: Text('Unlimited sizes & packs', style: TextStyle(fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Limits Row 2: Images & Storage
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: imagesCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Images / Month *',
                                hintText: '100',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                final img = int.tryParse(v?.trim() ?? '');
                                if (img == null || img < 0) return 'Must be ≥ 0';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: storageCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Storage (MB) *',
                                hintText: '500',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                final s = int.tryParse(v?.trim() ?? '');
                                if (s == null || s <= 0) return 'Must be > 0';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Feature Controls & Entitlements',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Enable or disable features for sellers subscribed to this tier:',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 8),

                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Advanced Analytics & Sales Charts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Access to 7-day revenue trends, IST delivered metrics, and KPI graphs', style: TextStyle(fontSize: 11)),
                        value: advancedAnalytics,
                        activeTrackColor: const Color(0xFF4F46E5),
                        activeThumbColor: Colors.white,
                        onChanged: (val) => setDialogState(() => advancedAnalytics = val),
                      ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Promotional Tools & Banners', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Create promotional banners, holiday notices, and custom shop discounts', style: TextStyle(fontSize: 11)),
                        value: promotionalTools,
                        activeTrackColor: const Color(0xFF4F46E5),
                        activeThumbColor: Colors.white,
                        onChanged: (val) => setDialogState(() => promotionalTools = val),
                      ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Low Stock Alerts & Inventory Warnings', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Automatic warnings when variant inventory falls below threshold', style: TextStyle(fontSize: 11)),
                        value: lowStockAlerts,
                        activeTrackColor: const Color(0xFF4F46E5),
                        activeThumbColor: Colors.white,
                        onChanged: (val) => setDialogState(() => lowStockAlerts = val),
                      ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Custom Store Attributes & Templates', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Ability to define custom product specification keys', style: TextStyle(fontSize: 11)),
                        value: customAttributes,
                        activeTrackColor: const Color(0xFF4F46E5),
                        activeThumbColor: Colors.white,
                        onChanged: (val) => setDialogState(() => customAttributes = val),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          isSaving = true;
                          errorMessage = null;
                        });

                        try {
                          final name = nameCtrl.text.trim();
                          final price = double.parse(priceCtrl.text.trim());
                          final duration = int.parse(durationCtrl.text.trim());
                          final maxProds = int.parse(prodsCtrl.text.trim());
                          final maxVars = int.parse(variantsCtrl.text.trim());
                          final maxImgs = int.parse(imagesCtrl.text.trim());
                          final storage = int.parse(storageCtrl.text.trim());

                          if (isEditing) {
                            await _dataSource.updatePlan(
                              planId: plan['id'].toString(),
                              name: name,
                              price: price,
                              durationDays: duration,
                              maxProducts: maxProds,
                              maxVariantsPerProduct: maxVars,
                              maxImagesPerMonth: maxImgs,
                              storageMb: storage,
                              advancedAnalytics: advancedAnalytics,
                              promotionalTools: promotionalTools,
                              lowStockAlerts: lowStockAlerts,
                              customAttributes: customAttributes,
                            );
                          } else {
                            await _dataSource.addPlan(
                              name: name,
                              price: price,
                              durationDays: duration,
                              maxProducts: maxProds,
                              maxVariantsPerProduct: maxVars,
                              maxImagesPerMonth: maxImgs,
                              storageMb: storage,
                              advancedAnalytics: advancedAnalytics,
                              promotionalTools: promotionalTools,
                              lowStockAlerts: lowStockAlerts,
                              customAttributes: customAttributes,
                            );
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isEditing
                                    ? 'Professional plan updated successfully!'
                                    : 'New Professional plan published successfully!'),
                                backgroundColor: const Color(0xFF059669),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSaving = false;
                            errorMessage = 'Error saving plan: $e';
                          });
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isEditing ? 'Save Changes' : 'Publish Plan'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Professional Marketplace — Subscription Plans',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Manage Seller Tiers, Pricing, Product Limits, Variant Capacities & Entitlements (Zero impact on Normal Providers)',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _openPlanDialog(),
                  icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                  label: const Text('Create New Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Real-Time Plans Stream
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _dataSource.streamPlans(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()));
                }

                final plans = snap.data ?? [];
                if (plans.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.card_membership_outlined, size: 48, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 12),
                          const Text(
                            'No Professional Subscription Plans Found',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Click "Create New Plan" to publish your first tier for local professional sellers.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _openPlanDialog(),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                            child: const Text('Create First Plan', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: plans.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final p = plans[index];
                    return _buildPlanCard(p);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> p) {
    final planId = (p['id'] ?? '').toString();
    final name = (p['name'] ?? 'Unnamed Plan').toString();
    final price = (p['price'] as num?)?.toDouble() ?? 0.0;
    final duration = (p['durationDays'] as num?)?.toInt() ?? 30;
    final maxProds = (p['maxProducts'] as num?)?.toInt() ?? (p['productLimit'] as num?)?.toInt() ?? 50;
    final maxImgs = (p['maxImagesPerMonth'] as num?)?.toInt() ?? (p['imageLimit'] as num?)?.toInt() ?? 100;
    final storage = (p['storageMb'] as num?)?.toInt() ?? (p['storageLimitMb'] as num?)?.toInt() ?? 500;
    final bool isActive = (p['isActive'] as bool?) ?? true;

    final rawFeatures = p['features'] is Map ? Map<String, dynamic>.from(p['features'] as Map) : <String, dynamic>{};
    final bool advAnalytics = p['advancedAnalytics'] == true || rawFeatures['advancedAnalytics'] == true;
    final bool promoTools = p['promotionalTools'] == true || rawFeatures['promotionalTools'] == true;
    final bool lowStock = p['lowStockAlerts'] != false && rawFeatures['lowStockAlerts'] != false;
    final bool customAttr = p['customAttributes'] != false && rawFeatures['customAttributes'] != false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isActive ? Colors.grey.shade200 : Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFF4F46E5), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${price % 1 == 0 ? price.toInt() : price} for $duration Days',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isActive ? const Color(0xFF059669) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Switch(
                    value: isActive,
                    activeTrackColor: const Color(0xFF059669),
                    activeThumbColor: Colors.white,
                    onChanged: (val) => _dataSource.togglePlanActive(planId, val),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF4F46E5)),
                    tooltip: 'Edit Plan & Features',
                    onPressed: () => _openPlanDialog(plan: p),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24, thickness: 1, color: Color(0xFFF1F5F9)),

          // Limits Row
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildLimitPill(Icons.inventory_2_outlined, '$maxProds Products Limit'),
              _buildLimitPill(Icons.layers_outlined, 'Unlimited sizes & packs'),
              _buildLimitPill(Icons.photo_outlined, '$maxImgs Images/Mo'),
              _buildLimitPill(Icons.cloud_outlined, '$storage MB Storage'),
            ],
          ),
          const SizedBox(height: 12),

          // Features Row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildFeatureBadge('Advanced Analytics', advAnalytics),
              _buildFeatureBadge('Promotional Tools', promoTools),
              _buildFeatureBadge('Low Stock Alerts', lowStock),
              _buildFeatureBadge('Custom Attributes', customAttr),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLimitPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF475569)),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(String feature, bool enabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: enabled ? const Color(0xFF86EFAC) : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
            size: 12,
            color: enabled ? const Color(0xFF15803D) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 4),
          Text(
            feature,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: enabled ? const Color(0xFF15803D) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
