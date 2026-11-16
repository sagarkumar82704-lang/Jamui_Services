import 'package:flutter/material.dart';
import '../../data/datasources/professional_provider_remote_data_source.dart';
import '../../domain/entities/professional_shop_profile_entity.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../core/localization/provider_strings.dart';
import '../../../../core/localization/language_selection_modal.dart';

class ProfessionalShopSettingsPage extends StatefulWidget {
  final ProfessionalShopProfileEntity shop;

  const ProfessionalShopSettingsPage({super.key, required this.shop});

  @override
  State<ProfessionalShopSettingsPage> createState() => _ProfessionalShopSettingsPageState();
}

class _ProfessionalShopSettingsPageState extends State<ProfessionalShopSettingsPage> {
  final ProfessionalProviderRemoteDataSource _dataSource = ProfessionalProviderRemoteDataSource();

  late bool _homeDelivery;
  late bool _pickup;
  late TextEditingController _deliveryChargeCtrl;
  late TextEditingController _minOrderCtrl;
  late TextEditingController _radiusCtrl;
  late TextEditingController _estimatedTimeCtrl;
  late TextEditingController _pickupInstructionsCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _homeDelivery = widget.shop.isHomeDeliveryActive;
    _pickup = widget.shop.isPickupActive;
    _deliveryChargeCtrl = TextEditingController(text: '${widget.shop.deliveryCharges.toInt()}');
    _minOrderCtrl = TextEditingController(text: '${widget.shop.minOrderAmount.toInt()}');
    _radiusCtrl = TextEditingController(text: '${widget.shop.serviceRadiusKm.toInt()}');
    _estimatedTimeCtrl = TextEditingController(text: '${widget.shop.estimatedDeliveryTimeMinutes}');
    _pickupInstructionsCtrl = TextEditingController(text: widget.shop.pickupInstructions);
  }

  @override
  void dispose() {
    _deliveryChargeCtrl.dispose();
    _minOrderCtrl.dispose();
    _radiusCtrl.dispose();
    _estimatedTimeCtrl.dispose();
    _pickupInstructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final payload = {
      'isHomeDeliveryActive': _homeDelivery,
      'isPickupActive': _pickup,
      'deliveryCharges': double.tryParse(_deliveryChargeCtrl.text.trim()) ?? 0.0,
      'minOrderAmount': double.tryParse(_minOrderCtrl.text.trim()) ?? 0.0,
      'serviceRadiusKm': double.tryParse(_radiusCtrl.text.trim()) ?? 5.0,
      'estimatedDeliveryTimeMinutes': int.tryParse(_estimatedTimeCtrl.text.trim()) ?? 30,
      'pickupInstructions': _pickupInstructionsCtrl.text.trim(),
    };

    try {
      await _dataSource.updateShopSettings(widget.shop.id, payload);
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ProviderStrings.settingsSavedSuccess),
            backgroundColor: const Color(0xFF0F766E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update settings: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          ProviderStrings.shopSettings,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        actions: [
          IconButton(
            tooltip: ProviderStrings.selectLanguage,
            icon: const Icon(Icons.language_rounded, color: Color(0xFF0F766E)),
            onPressed: () => LanguageSelectionModal.show(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: ResponsiveFormShell(
          maxWidth: 680,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Delivery Settings Section (Matching Reference Image)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ProviderStrings.deliverySettings,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 12),

                  // Home Delivery Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(ProviderStrings.homeDelivery, style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155))),
                      Switch(
                        value: _homeDelivery,
                        activeThumbColor: const Color(0xFF0F766E),
                        onChanged: (v) => setState(() => _homeDelivery = v),
                      ),
                    ],
                  ),
                  const Divider(height: 18),

                  // Delivery Charge
                  _buildSettingInputRow(ProviderStrings.deliveryCharge, _deliveryChargeCtrl, 'e.g. 40'),
                  const SizedBox(height: 12),

                  // Min. Order Amount
                  _buildSettingInputRow(ProviderStrings.minOrderAmount, _minOrderCtrl, 'e.g. 199'),
                  const SizedBox(height: 12),

                  // Delivery Radius
                  _buildSettingInputRow(ProviderStrings.deliveryRadius, _radiusCtrl, 'e.g. 5'),
                  const SizedBox(height: 12),

                  // Estimated Delivery Time
                  _buildSettingInputRow(ProviderStrings.estimatedDeliveryTime, _estimatedTimeCtrl, 'e.g. 30'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Pickup Settings Section (Matching Reference Image)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ProviderStrings.pickupSettings,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 12),

                  // Store Pickup Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(ProviderStrings.storePickup, style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155))),
                      Switch(
                        value: _pickup,
                        activeThumbColor: const Color(0xFF0F766E),
                        onChanged: (v) => setState(() => _pickup = v),
                      ),
                    ],
                  ),
                  const Divider(height: 18),

                  // Pickup Instructions
                  Text(ProviderStrings.pickupInstructions, style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _pickupInstructionsCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g. Collect your order from Counter #1 near billing desk.',
                      hintStyle: const TextStyle(fontSize: 12.5, color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // App Language Section Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Icon(Icons.language_rounded, color: Color(0xFF0F766E), size: 20),
                  ),
                  title: Text(
                    ProviderStrings.languageSettingTitle,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  subtitle: Text(
                    ProviderStrings.languageSettingSubtitle,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF16A34A)),
                        ),
                        child: Text(
                          ProviderStrings.isHindi ? 'हिन्दी' : 'English',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    ],
                  ),
                  onTap: () => LanguageSelectionModal.show(context),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save Changes Button (Matching Reference Image)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E), // Deep Teal
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : Text(
                        ProviderStrings.saveSettings,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildSettingInputRow(String label, TextEditingController ctrl, String hint) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF334155)))),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          height: 38,
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

