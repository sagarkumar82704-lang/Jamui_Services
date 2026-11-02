import 'package:flutter/material.dart';
import '../../data/datasources/professional_provider_remote_data_source.dart';
import '../../domain/entities/professional_shop_profile_entity.dart';

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
          const SnackBar(
            content: Text('Shop settings updated successfully!'),
            backgroundColor: Color(0xFF0F766E),
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
        title: const Text(
          'Shop Settings',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivery Settings',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 12),

                  // Home Delivery Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Home Delivery', style: TextStyle(fontSize: 13.5, color: Color(0xFF334155))),
                      Switch(
                        value: _homeDelivery,
                        activeColor: const Color(0xFF0F766E),
                        onChanged: (v) => setState(() => _homeDelivery = v),
                      ),
                    ],
                  ),
                  const Divider(height: 18),

                  // Delivery Charge
                  _buildSettingInputRow('Delivery Charge (₹)', _deliveryChargeCtrl, 'e.g. 40'),
                  const SizedBox(height: 12),

                  // Min. Order Amount
                  _buildSettingInputRow('Min. Order Amount (₹)', _minOrderCtrl, 'e.g. 199'),
                  const SizedBox(height: 12),

                  // Delivery Radius
                  _buildSettingInputRow('Delivery Radius (km)', _radiusCtrl, 'e.g. 5'),
                  const SizedBox(height: 12),

                  // Estimated Delivery Time
                  _buildSettingInputRow('Estimated Delivery Time (mins)', _estimatedTimeCtrl, 'e.g. 30'),
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
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pickup Settings',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 12),

                  // Store Pickup Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Store Pickup', style: TextStyle(fontSize: 13.5, color: Color(0xFF334155))),
                      Switch(
                        value: _pickup,
                        activeColor: const Color(0xFF0F766E),
                        onChanged: (v) => setState(() => _pickup = v),
                      ),
                    ],
                  ),
                  const Divider(height: 18),

                  // Pickup Instructions
                  const Text('Pickup Instructions', style: TextStyle(fontSize: 13.5, color: Color(0xFF334155))),
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
                    : const Text(
                        'Save Changes',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingInputRow(String label, TextEditingController ctrl, String hint) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
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

