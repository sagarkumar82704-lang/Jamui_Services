import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class OtherServiceData {
  final String serviceName;
  final String serviceDescription;
  final String offeredServices;
  final String fullName;
  final String phoneNumber;
  final String fullAddress;
  final String jamuiArea;
  final int experienceYears;
  final double visitingCharge;

  OtherServiceData({
    required this.serviceName,
    required this.serviceDescription,
    required this.offeredServices,
    required this.fullName,
    required this.phoneNumber,
    required this.fullAddress,
    required this.jamuiArea,
    required this.experienceYears,
    required this.visitingCharge,
  });
}

class OtherServiceDetailsModal extends StatefulWidget {
  final String initialFullName;
  final String initialPhoneNumber;
  final String initialFullAddress;
  final String initialJamuiArea;
  final int initialExperienceYears;
  final double initialVisitingCharge;
  final OtherServiceData? existingData;
  final Function(OtherServiceData data) onSubmitted;

  const OtherServiceDetailsModal({
    super.key,
    required this.initialFullName,
    required this.initialPhoneNumber,
    required this.initialFullAddress,
    required this.initialJamuiArea,
    required this.initialExperienceYears,
    required this.initialVisitingCharge,
    this.existingData,
    required this.onSubmitted,
  });

  static Future<OtherServiceData?> show(
    BuildContext context, {
    required String initialFullName,
    required String initialPhoneNumber,
    required String initialFullAddress,
    required String initialJamuiArea,
    required int initialExperienceYears,
    required double initialVisitingCharge,
    OtherServiceData? existingData,
  }) {
    return showModalBottomSheet<OtherServiceData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OtherServiceDetailsModal(
        initialFullName: initialFullName,
        initialPhoneNumber: initialPhoneNumber,
        initialFullAddress: initialFullAddress,
        initialJamuiArea: initialJamuiArea,
        initialExperienceYears: initialExperienceYears,
        initialVisitingCharge: initialVisitingCharge,
        existingData: existingData,
        onSubmitted: (data) => Navigator.pop(ctx, data),
      ),
    );
  }

  @override
  State<OtherServiceDetailsModal> createState() => _OtherServiceDetailsModalState();
}

class _OtherServiceDetailsModalState extends State<OtherServiceDetailsModal> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _serviceNameController;
  late TextEditingController _serviceDescController;
  late TextEditingController _offeredServicesController;
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _areaController;
  late TextEditingController _expController;
  late TextEditingController _chargeController;

  @override
  void initState() {
    super.initState();
    _serviceNameController = TextEditingController(text: widget.existingData?.serviceName ?? '');
    _serviceDescController = TextEditingController(text: widget.existingData?.serviceDescription ?? '');
    _offeredServicesController = TextEditingController(text: widget.existingData?.offeredServices ?? '');
    _fullNameController = TextEditingController(
      text: widget.existingData?.fullName ?? (widget.initialFullName.isNotEmpty ? widget.initialFullName : 'कारीगर'),
    );
    _phoneController = TextEditingController(
      text: widget.existingData?.phoneNumber ?? widget.initialPhoneNumber,
    );
    _addressController = TextEditingController(
      text: widget.existingData?.fullAddress ?? widget.initialFullAddress,
    );
    _areaController = TextEditingController(
      text: widget.existingData?.jamuiArea ?? (widget.initialJamuiArea.isNotEmpty ? widget.initialJamuiArea : 'जमुई'),
    );
    _expController = TextEditingController(
      text: (widget.existingData?.experienceYears ?? widget.initialExperienceYears).toString(),
    );
    _chargeController = TextEditingController(
      text: (widget.existingData?.visitingCharge ?? widget.initialVisitingCharge).toInt().toString(),
    );
  }

  @override
  void dispose() {
    _serviceNameController.dispose();
    _serviceDescController.dispose();
    _offeredServicesController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _areaController.dispose();
    _expController.dispose();
    _chargeController.dispose();
    super.dispose();
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    final data = OtherServiceData(
      serviceName: _serviceNameController.text.trim(),
      serviceDescription: _serviceDescController.text.trim(),
      offeredServices: _offeredServicesController.text.trim(),
      fullName: _fullNameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      fullAddress: _addressController.text.trim(),
      jamuiArea: _areaController.text.trim(),
      experienceYears: int.tryParse(_expController.text.trim()) ?? 1,
      visitingCharge: double.tryParse(_chargeController.text.trim()) ?? 100.0,
    );

    widget.onSubmitted(data);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title and explanation
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: const Icon(Icons.design_services_rounded, color: Color(0xFF15803D), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'अन्य सेवा आवेदन (Other Service Form)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'यदि आपका काम लिस्ट में नहीं है तो यहाँ विवरण भरें।',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Notice box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade900, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'यह विकल्प एडमिन समीक्षा (Admin Review) के लिए जमा होगा। एडमिन द्वारा सत्यापित होने के बाद आपकी श्रेणी एक्टिव कर दी जाएगी।',
                        style: TextStyle(fontSize: 11.5, color: Colors.amber.shade900, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 1. Proposed Service Name
              TextFormField(
                controller: _serviceNameController,
                decoration: InputDecoration(
                  labelText: 'आपकी सेवा / काम का नाम (Trade / Service Name) *',
                  hintText: 'उदा. सोलर पैनल रिपेयर, CCTV इंस्टॉलेशन, RO सर्विस',
                  prefixIcon: const Icon(Icons.handyman_rounded, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'कृपया अपनी सेवा का नाम दर्ज करें।';
                  }
                  if (val.trim().length < 3) {
                    return 'सेवा का नाम कम से कम 3 अक्षरों का होना चाहिए।';
                  }
                  if (val.trim().length > 60) {
                    return 'अधिकतम 60 अक्षर ही दर्ज करें।';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // 2. Work Description
              TextFormField(
                controller: _serviceDescController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'कार्य का विवरण (Describe what work you perform) *',
                  hintText: 'उदा. हम सभी प्रकार के ऑन-ग्रिड व ऑफ-ग्रिड सोलर सिस्टम लगाते हैं और इनवर्टर-बैटरी ठीक करते हैं...',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.description_outlined, color: AppColors.primary),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'कृपया कार्य का संक्षिप्त विवरण दर्ज करें।';
                  }
                  if (val.trim().length < 10) {
                    return 'कृपया कम से कम 10 अक्षरों में विवरण लिखें।';
                  }
                  if (val.trim().length > 600) {
                    return 'विवरण 600 अक्षरों से अधिक न हो।';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // 3. Specific Services Offered
              TextFormField(
                controller: _offeredServicesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'आप कौन-कौन से काम करते हैं? (Offered Services) *',
                  hintText: 'उदा. नया सोलर लगाना, केबल वायरिंग, पैनल सफाई, इन्वर्टर रिपेयर',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Icon(Icons.checklist_rounded, color: AppColors.primary),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'कृपया दी जाने वाली सेवाओं की सूची दर्ज करें।';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // 4. Provider & Mobile (Reused & Verified)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: 'कारीगर का नाम *',
                        prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'नाम दर्ज करें' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'पंजीकृत मोबाइल 🔒',
                        prefixIcon: const Icon(Icons.phone_rounded, color: Colors.green),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 5. Experience & Fees
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'अनुभव (वर्ष)',
                        prefixIcon: const Icon(Icons.work_history_outlined, color: AppColors.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _chargeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'अनुमानित विजिट फीस (₹)',
                        prefixIcon: const Icon(Icons.currency_rupee, color: AppColors.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 6. Address & Area
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'दुकान या कार्य का पूरा पता',
                  prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('रद्द करें'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _onSave,
                      icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                      label: const Text('प्रस्ताव सबमिट करें', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
        ),
      ),
    );
  }
}
