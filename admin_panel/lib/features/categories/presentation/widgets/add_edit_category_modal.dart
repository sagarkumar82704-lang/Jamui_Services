import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_network_or_base64_image.dart';
import '../../../../core/utils/admin_placeholder_images.dart';
import '../../data/datasources/category_storage_remote_data_source.dart';
import '../../domain/entities/category_entity.dart';
import 'category_customer_preview_dialog.dart';
import 'universal_image_picker.dart';

/// Advanced, AI-Powered Category Builder Modal for Jamui Services Admin.
/// 
/// Features:
/// 1. 1-Click Professional Category Presets (Electrician, Plumber, AC, Carpenter, etc.)
/// 2. Interactive Sub-Services & AI Keywords Builder with Tap-to-Add Suggestions
/// 3. Visual Icon Grid & Palette Color Selector
/// 4. Live "AI Search Understanding Preview" showing how Gemini AI matches this category
/// 5. Clean 4-Step Tabbed UX for non-technical admins
class AddEditCategoryModal extends StatefulWidget {
  final CategoryEntity? category;
  final Future<void> Function(CategoryEntity category) onSave;
  final CategoryStorageRemoteDataSource? storageDataSource;

  const AddEditCategoryModal({
    super.key,
    this.category,
    required this.onSave,
    this.storageDataSource,
  });

  @override
  State<AddEditCategoryModal> createState() => _AddEditCategoryModalState();
}

class _AddEditCategoryModalState extends State<AddEditCategoryModal> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _slugController;
  late TextEditingController _titleHindiController;
  late TextEditingController _shortDescController;
  late TextEditingController _fullDescController;
  late TextEditingController _aboutCategoryController;
  late TextEditingController _whoNeedsController;
  late TextEditingController _whenToContactController;
  late TextEditingController _imageUrlInputController;

  // Price & Duration
  String _pricingType = 'contact_provider';
  late TextEditingController _startingPriceController;
  late TextEditingController _priceUnitController;
  late TextEditingController _priceNoteController;
  late TextEditingController _estimatedDurationController;

  // Requirements
  late TextEditingController _customerReqController;
  bool _customerPhotoRequired = false;
  late TextEditingController _providerReqController;
  bool _expCertRequired = false;
  bool _verificationRequired = false;

  // Safety & Notes
  late TextEditingController _safetyController;
  late TextEditingController _importantNotesController;
  late TextEditingController _disclaimerController;

  // Discovery & Visibility
  late TextEditingController _searchKeywordsController;
  late TextEditingController _tagsController;
  late TextEditingController _sortOrderController;
  CategoryStatus _status = CategoryStatus.active;
  bool _isFeatured = false;
  bool _isAutoSlug = true;

  // Visuals
  String _selectedIconName = 'bolt';
  String _selectedColorHex = '#F59E0B';

  // Dynamic Lists
  final List<String> _subServices = [];
  final List<String> _commonProblems = [];
  final List<String> _benefits = [];
  final List<CategoryFaq> _faqs = [];

  // Temporary list input controllers
  final TextEditingController _newServiceController = TextEditingController();
  final TextEditingController _newProblemController = TextEditingController();
  final TextEditingController _newBenefitController = TextEditingController();

  // Image Upload & Progress State
  Uint8List? _selectedImageBytes;
  String? _selectedImageFileName;
  String? _selectedImageMimeType;
  String _currentImageUrl = '';
  String _currentImageStoragePath = '';
  bool _isImageRemoved = false;
  bool _isUploading = false;
  String _uploadStatusText = 'Saving category...';
  String? _errorMessage;
  String? _imageValidationError;

  // Temporary Placeholder Preview State (Strictly for preview - never saved to Firestore)
  AdminPlaceholderItem? _activePlaceholder;
  bool _isPlaceholderPreviewActive = false;

  late final CategoryStorageRemoteDataSource _storageDataSource;

  // Pre-configured Trade Presets for 1-Click Setup
  static final List<Map<String, dynamic>> _tradePresets = [
    {
      'titleEnglish': 'Electrician',
      'titleHindi': 'इलेक्ट्रीशियन',
      'slug': 'electrician',
      'iconName': 'bolt',
      'colorHex': '#F59E0B',
      'shortDescription': 'घर व दुकान की वायरिंग, पंखा, लाइट और बिजली संबंधित सभी काम।',
      'fullDescription': 'जमुई के वेरिफाइड इलेक्ट्रीशियन द्वारा पंखा रिपेयर, हाउस वायरिंग, स्विच बोर्ड, एमसीबी और शॉर्ट सर्किट सुधार।',
      'startingPrice': 199.0,
      'pricingType': 'starting_from',
      'priceUnit': 'प्रति विजिट',
      'estimatedDuration': '30-60 मिनट',
      'subServices': [
        'पंखे की मरम्मत (Fan Repair)',
        'हाउस वायरिंग (House Wiring)',
        'स्विच बोर्ड रिपेयर (Switch Board)',
        'शॉर्ट सर्किट फॉल्ट (Short Circuit)',
        'इनवर्टर व बैटरी फिटिंग (Inverter)',
        'एमसीबी व फ्यूज (MCB & Fuse)',
        'कूलर रिपेयर (Cooler Repair)',
      ],
      'commonProblems': [
        'पंखा नहीं चल रहा',
        'पंखा बनाने वाला',
        'बिजली मिस्त्री',
        'शॉर्ट सर्किट हो गया',
        'करंट आ रहा है',
        'स्विच खराब है',
        'लाइट बंद है',
        'बिजली ठीक करने वाला',
        'fuse blown',
        'fan repair',
        'switch repair',
      ],
    },
    {
      'titleEnglish': 'Plumber',
      'titleHindi': 'प्लंबर',
      'slug': 'plumber',
      'iconName': 'plumbing',
      'colorHex': '#3B82F6',
      'shortDescription': 'नल, पाइप लीकेज, पानी टंकी और बाथरूम प्लंबिंग की त्वरित सेवा।',
      'fullDescription': 'अनुभवी प्लंबर द्वारा पानी पाइप लीकेज, नल फिटिंग, वाटर टैंक सफाई और मोटर पंप इंस्टालेशन।',
      'startingPrice': 199.0,
      'pricingType': 'starting_from',
      'priceUnit': 'प्रति विजिट',
      'estimatedDuration': '45-90 मिनट',
      'subServices': [
        'नल रिपेयर व फिटिंग (Tap Repair)',
        'पाइप लीकेज ठीक करना (Pipe Leakage)',
        'पानी टंकी की सफाई (Water Tank)',
        'मोटर पंप इंस्टालेशन (Motor Pump)',
        'बेसिन व सिंक रिपेयर (Basin & Sink)',
        'कमोड / टॉयलेट फिटिंग (Toilet Fitting)',
        'गीजर इंस्टालेशन (Geyser Installation)',
      ],
      'commonProblems': [
        'नल से पानी टपक रहा है',
        'नल बनाने वाला',
        'पाइप लीक हो गया',
        'पानी की टंकी भर नहीं रही',
        'नल टूटा हुआ है',
        'पानी नहीं आ रहा',
        'सीवर जाम है',
        'प्लंबर मिस्त्री',
        'tap leakage',
        'pipe burst',
        'plumber near me',
      ],
    },
    {
      'titleEnglish': 'AC & Appliance Repair',
      'titleHindi': 'एसी व फ्रिज रिपेयर',
      'slug': 'ac-appliance-repair',
      'iconName': 'ac_unit',
      'colorHex': '#06B6D4',
      'shortDescription': 'एसी, फ्रिज, वाशिंग मशीन और कूलर की रिपेयर व गैस रीफिल।',
      'fullDescription': 'सभी ब्रांड्स के स्प्लिट/विंडो एसी, सिंगल/डबल डोर फ्रिज और वाशिंग मशीन की घर बैठे सर्विसिंग।',
      'startingPrice': 299.0,
      'pricingType': 'inspection',
      'priceUnit': 'इंस्पेक्शन चार्ज',
      'estimatedDuration': '1-2 घंटे',
      'subServices': [
        'एसी सर्विसिंग (AC Servicing)',
        'गैस रीफिल (Gas Refill)',
        'फ्रिज रिपेयर (Fridge Repair)',
        'वाशिंग मशीन रिपेयर (Washing Machine)',
        'माइक्रोवेव रिपेयर (Microwave)',
        'कूलिंग समस्या सुधार (Cooling Issue)',
      ],
      'commonProblems': [
        'AC ठंडा नहीं कर रहा',
        'फ्रिज में बर्फ नहीं जम रही',
        'AC में गैस खत्म हो गई',
        'वाशिंग मशीन आवाज कर रही है',
        'कूलर हवा नहीं दे रहा',
        'fridge cooling problem',
        'ac repair',
      ],
    },
    {
      'titleEnglish': 'Carpenter',
      'titleHindi': 'बढ़ई व फर्नीचर',
      'slug': 'carpenter',
      'iconName': 'carpenter',
      'colorHex': '#8B5CF6',
      'shortDescription': 'दरवाजा, खिड़की, ताला, बेड, सोफा और लकड़ी का सारा फर्नीचर काम।',
      'fullDescription': 'कुशल बढ़ई मिस्त्री द्वारा नए फर्नीचर निर्माण, पुराने सोफा/बेड की रिपेयर और मॉडर्न फिटिंग्स।',
      'startingPrice': 249.0,
      'pricingType': 'starting_from',
      'priceUnit': 'प्रति विजिट',
      'estimatedDuration': '1-3 घंटे',
      'subServices': [
        'दरवाजा व खिड़की फिटिंग (Door/Window)',
        'ताला बदलना व रिपेयर (Lock Repair)',
        'बेड व सोफा रिपेयर (Bed & Sofa)',
        'अलमारी बनाना (Almirah/Cupboard)',
        'प्लाईवुड व मॉड्यूलर वर्क (Modular Work)',
      ],
      'commonProblems': [
        'दरवाजा बंद नहीं हो रहा',
        'ताला जाम हो गया',
        'कुर्सी टूट गई',
        'अलमारी का हैंडल खराब है',
        'बढ़ई मिस्त्री चाहिए',
        'carpenter near me',
      ],
    },
    {
      'titleEnglish': 'Painter',
      'titleHindi': 'पेंटर व पुट्टी',
      'slug': 'painter',
      'iconName': 'format_paint',
      'colorHex': '#EC4899',
      'shortDescription': 'घर की पुट्टी, डिस्टेंपर, वॉल पेंटिंग और वाटरप्रूफिंग का काम।',
      'fullDescription': 'प्रीमियम पेंटिंग सर्विसेज, इंटीरियर व एक्सटीरियर वॉल्स, सीलन का पक्का इलाज और टेक्सचर डिजाइन।',
      'startingPrice': 499.0,
      'pricingType': 'inspection',
      'priceUnit': 'स्क्वायर फीट / विजिट',
      'estimatedDuration': 'काम के अनुसार',
      'subServices': [
        'घर की पुट्टी व प्राइमर (Putty & Primer)',
        'इंटीरियर पेंटिंग (Interior Paint)',
        'एक्सटीरियर पेंटिंग (Exterior Paint)',
        'वाटरप्रूफिंग (Waterproofing)',
        'टेक्सचर डिजाइन (Texture Design)',
      ],
      'commonProblems': [
        'दीवार से पपड़ी छूट रही है',
        'दीवार में सीलन है',
        'रंग छूट गया है',
        'पुट्टी करवानी है',
        'पेंटर चाहिए',
        'wall painting',
      ],
    },
    {
      'titleEnglish': 'House Cleaning',
      'titleHindi': 'सफाई व हाउसकीपिंग',
      'slug': 'house-cleaning',
      'iconName': 'cleaning_services',
      'colorHex': '#10B981',
      'shortDescription': 'घर, किचन, बाथरूम और सोफा की डीप क्लीनिंग व सैनिटाइजेशन।',
      'fullDescription': 'प्रोफेशनल क्लीनिंग टीम द्वारा फ्लोर स्क्रबिंग, बाथरूम टाइल्स सफाई और सोफा ड्राई क्लीन।',
      'startingPrice': 399.0,
      'pricingType': 'starting_from',
      'priceUnit': 'प्रति कमरा/सर्विस',
      'estimatedDuration': '2-4 घंटे',
      'subServices': [
        'घर की फुल डीप क्लीनिंग (Full Deep Cleaning)',
        'बाथरूम टाइल्स सफाई (Bathroom Cleaning)',
        'किचन डीप क्लीनिंग (Kitchen Cleaning)',
        'सोफा व कारपेट ड्राई क्लीन (Sofa Cleaning)',
      ],
      'commonProblems': [
        'घर में बहुत गंदगी है',
        'बाथरूम के दाग नहीं छूट रहे',
        'दीवाली की सफाई करवानी है',
        'सोफा गंदा हो गया',
        'सफाई वाली चाहिए',
        'house cleaning',
      ],
    },
    {
      'titleEnglish': 'Beauty & Salon',
      'titleHindi': 'ब्यूटी पार्लर व सैलून',
      'slug': 'beauty-salon',
      'iconName': 'face_retouching_natural',
      'colorHex': '#F43F5E',
      'shortDescription': 'घर पर फेशियल, हेयर कटिंग, ब्राइडल मेकअप और वैक्सिंग की सुविधा।',
      'fullDescription': 'सत्यापित ब्यूटीशियंस द्वारा घर पर ही पार्लर जैसी सेवाएं, हाइजीन किट और प्रीमियम प्रोडक्ट्स के साथ।',
      'startingPrice': 299.0,
      'pricingType': 'starting_from',
      'priceUnit': 'प्रति सर्विस',
      'estimatedDuration': '45-90 मिनट',
      'subServices': [
        'हेयर कटिंग व स्टाइलिंग (Hair Styling)',
        'फेशियल व क्लीनअप (Facial & Cleanup)',
        'ब्राइडल मेकअप (Bridal Makeup)',
        'वैक्सिंग व थ्रेडिंग (Waxing & Threading)',
        'मेंहदी डिजाइन (Mehendi Art)',
      ],
      'commonProblems': [
        'पार्टी मेकअप चाहिए',
        'घर पर फेशियल करवाना है',
        'बाल कटवाने हैं',
        'ब्यूटीशियन चाहिए',
        'parlour at home',
      ],
    },
    {
      'titleEnglish': 'Auto Mechanic',
      'titleHindi': 'बाइक व कार मैकेनिक',
      'slug': 'auto-mechanic',
      'iconName': 'two_wheeler',
      'colorHex': '#EF4444',
      'shortDescription': 'बाइक, स्कूटर व कार की ऑन-स्पॉट सर्विसिंग, पंचर और ब्रेकडाउन मदद।',
      'fullDescription': 'रास्ते में या घर पर बाइक/कार बंद होने पर तुरंत मैकेनिक पहुंचेगा। ऑयल चेंज, बैटरी जंप-स्टार्ट और इंजन काम।',
      'startingPrice': 149.0,
      'pricingType': 'starting_from',
      'priceUnit': 'विजिट चार्ज',
      'estimatedDuration': '30-60 मिनट',
      'subServices': [
        'बाइक सर्विसिंग व ऑयल चेंज (Bike Service)',
        'ऑन-स्पॉट पंचर बनाना (Puncture Repair)',
        'बैटरी जंप स्टार्ट (Battery Jump Start)',
        'कार ब्रेकडाउन असिस्ट (Car Breakdown)',
      ],
      'commonProblems': [
        'बाइक स्टार्ट नहीं हो रही',
        'पंचर हो गया',
        'इंजन से आवाज आ रही है',
        'गाड़ी बीच रास्ते में बंद हो गई',
        'bike mechanic',
        'puncture repair',
      ],
    },
    {
      'titleEnglish': 'Unisex Salon',
      'titleHindi': 'यूनिसेक्स सैलून',
      'slug': 'unisex-salon',
      'iconName': 'content_cut',
      'colorHex': '#EC4899',
      'shortDescription': 'Hair, beauty, grooming and salon services for men and women.',
      'fullDescription': 'Jamui ke top verified unisex salons dwara hair styling, coloring, facials, beard grooming, bridal/party makeup aur premium grooming services.',
      'startingPrice': 199.0,
      'pricingType': 'starting_from',
      'priceUnit': 'प्रति सर्विस',
      'estimatedDuration': '30-120 मिनट',
      'subServices': [
        'Haircut & Styling',
        'Hair Color & Highlights',
        'Skin & Facial',
        'Beard Grooming',
        'Manicure & Pedicure',
        'Hair Treatment',
        'Bridal & Party Makeup',
        'Smoothening & Keratin',
      ],
      'commonProblems': [
        'बाल कटवाने हैं (Haircut)',
        'हेयर कलर करवाना है (Hair Color)',
        'फेशियल व स्किन केयर (Facial & Skin Care)',
        'दाढ़ी सेट करवाना है (Beard Grooming)',
        'ब्राइडल या पार्टी मेकअप (Makeup)',
        'स्मूदनिंग व केराटिन (Smoothening & Keratin)',
        'unisex salon near me',
        'salon for men and women',
      ],
    },
  ];

  static const List<Map<String, dynamic>> _availableIcons = [
    {'name': 'bolt', 'label': 'बिजली (Bolt)', 'icon': Icons.bolt_rounded},
    {'name': 'content_cut', 'label': 'सैलून / बाल (Scissors)', 'icon': Icons.content_cut_rounded},
    {'name': 'plumbing', 'label': 'प्लंबर (Plumbing)', 'icon': Icons.plumbing_rounded},
    {'name': 'ac_unit', 'label': 'एसी (AC Unit)', 'icon': Icons.ac_unit_rounded},
    {'name': 'carpenter', 'label': 'बढ़ई (Carpenter)', 'icon': Icons.carpenter_rounded},
    {'name': 'format_paint', 'label': 'पेंटर (Paint)', 'icon': Icons.format_paint_rounded},
    {'name': 'cleaning_services', 'label': 'सफाई (Cleaning)', 'icon': Icons.cleaning_services_rounded},
    {'name': 'handyman', 'label': 'कारीगर (Handyman)', 'icon': Icons.handyman_rounded},
    {'name': 'two_wheeler', 'label': 'बाइक (Bike)', 'icon': Icons.two_wheeler_rounded},
    {'name': 'directions_car', 'label': 'कार (Car)', 'icon': Icons.directions_car_rounded},
    {'name': 'face_retouching_natural', 'label': 'ब्यूटी (Beauty)', 'icon': Icons.face_retouching_natural_rounded},
    {'name': 'smartphone', 'label': 'मोबाइल (Mobile)', 'icon': Icons.smartphone_rounded},
    {'name': 'tv', 'label': 'टीवी (TV)', 'icon': Icons.tv_rounded},
    {'name': 'local_laundry_service', 'label': 'धोबी (Laundry)', 'icon': Icons.local_laundry_service_rounded},
    {'name': 'kitchen', 'label': 'किचन (Kitchen)', 'icon': Icons.kitchen_rounded},
    {'name': 'home_repair_service', 'label': 'मरम्मत (Repair)', 'icon': Icons.home_repair_service_rounded},
    {'name': 'build', 'label': 'टूल्स (Build)', 'icon': Icons.build_rounded},
  ];

  static const List<String> _paletteColors = [
    '#F59E0B', '#3B82F6', '#06B6D4', '#8B5CF6', '#EC4899',
    '#10B981', '#F43F5E', '#EF4444', '#6366F1', '#14B8A6',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _storageDataSource = widget.storageDataSource ?? FirebaseCategoryStorageRemoteDataSource();
    final c = widget.category;

    _nameController = TextEditingController(text: c?.name ?? '');
    _slugController = TextEditingController(text: c?.slug ?? '');
    _titleHindiController = TextEditingController(text: c?.titleHindi ?? '');
    _shortDescController = TextEditingController(text: c?.shortDescription.isNotEmpty == true ? c!.shortDescription : (c?.description ?? ''));
    _fullDescController = TextEditingController(text: c?.fullDescription.isNotEmpty == true ? c!.fullDescription : (c?.description ?? ''));
    _aboutCategoryController = TextEditingController(text: c?.aboutCategory ?? '');
    _whoNeedsController = TextEditingController(text: c?.whoNeeds ?? '');
    _whenToContactController = TextEditingController(text: c?.whenToContact ?? '');
    _imageUrlInputController = TextEditingController(text: c?.imageUrl ?? '');

    _pricingType = c?.pricingType ?? 'contact_provider';
    _startingPriceController = TextEditingController(text: c?.startingPrice != null ? c!.startingPrice.toString() : '');
    _priceUnitController = TextEditingController(text: c?.priceUnit ?? '');
    _priceNoteController = TextEditingController(text: c?.priceNote ?? '');
    _estimatedDurationController = TextEditingController(text: c?.estimatedDuration ?? '');

    _customerReqController = TextEditingController(text: c?.customerRequirements ?? '');
    _customerPhotoRequired = c?.customerPhotoRequired ?? false;
    _providerReqController = TextEditingController(text: c?.providerRequirements ?? '');
    _expCertRequired = c?.experienceCertificateRequired ?? false;
    _verificationRequired = c?.verificationRequired ?? false;

    _safetyController = TextEditingController(text: c?.safetyInstructions ?? '');
    _importantNotesController = TextEditingController(text: c?.importantNotes ?? '');
    _disclaimerController = TextEditingController(text: c?.disclaimer ?? '');

    _searchKeywordsController = TextEditingController(text: c?.searchKeywords.join(', ') ?? '');
    _tagsController = TextEditingController(text: c?.tags.join(', ') ?? '');
    _sortOrderController = TextEditingController(text: (c?.sortOrder ?? 0).toString());
    _status = c?.status ?? CategoryStatus.active;
    _isFeatured = c?.isFeatured ?? false;
    _isAutoSlug = c == null;

    _selectedIconName = (c?.iconName.isNotEmpty == true) ? c!.iconName : 'bolt';
    _selectedColorHex = (c?.colorHex.isNotEmpty == true) ? c!.colorHex : '#F59E0B';

    _currentImageUrl = c?.imageUrl ?? '';
    _currentImageStoragePath = c?.imageStoragePath ?? '';

    if (c != null) {
      _subServices.addAll(c.subServices);
      _commonProblems.addAll(c.commonProblems);
      _benefits.addAll(c.benefits);
      _faqs.addAll(c.faqs);
    }

    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    if (_isAutoSlug) {
      final generatedSlug = _nameController.text
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
      _slugController.text = generatedSlug;
    }
  }

  void _applyTradePreset(Map<String, dynamic> preset) {
    setState(() {
      _nameController.text = preset['titleEnglish'] ?? '';
      _titleHindiController.text = preset['titleHindi'] ?? '';
      _slugController.text = preset['slug'] ?? '';
      _shortDescController.text = preset['shortDescription'] ?? '';
      _fullDescController.text = preset['fullDescription'] ?? '';
      _selectedIconName = preset['iconName'] ?? 'bolt';
      _selectedColorHex = preset['colorHex'] ?? '#F59E0B';

      _pricingType = preset['pricingType'] ?? 'starting_from';
      _startingPriceController.text = (preset['startingPrice'] as double?)?.toInt().toString() ?? '199';
      _priceUnitController.text = preset['priceUnit'] ?? '';
      _estimatedDurationController.text = preset['estimatedDuration'] ?? '';

      _subServices.clear();
      if (preset['subServices'] is List) {
        _subServices.addAll((preset['subServices'] as List).map((s) => s.toString()));
      }

      _commonProblems.clear();
      if (preset['commonProblems'] is List) {
        _commonProblems.addAll((preset['commonProblems'] as List).map((p) => p.toString()));
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✨ ${preset['titleHindi']} (${preset['titleEnglish']}) का पूरा डेटा ऑटो-फिल हो गया!'),
        backgroundColor: _parseColor(_selectedColorHex),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _slugController.dispose();
    _titleHindiController.dispose();
    _shortDescController.dispose();
    _fullDescController.dispose();
    _aboutCategoryController.dispose();
    _whoNeedsController.dispose();
    _whenToContactController.dispose();
    _imageUrlInputController.dispose();
    _startingPriceController.dispose();
    _priceUnitController.dispose();
    _priceNoteController.dispose();
    _estimatedDurationController.dispose();
    _customerReqController.dispose();
    _providerReqController.dispose();
    _safetyController.dispose();
    _importantNotesController.dispose();
    _disclaimerController.dispose();
    _searchKeywordsController.dispose();
    _tagsController.dispose();
    _sortOrderController.dispose();
    _newServiceController.dispose();
    _newProblemController.dispose();
    _newBenefitController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  IconData _getIconData(String name) {
    for (final item in _availableIcons) {
      if (item['name'] == name) return item['icon'] as IconData;
    }
    return Icons.build_rounded;
  }

  Future<bool> _confirmReplaceImage({String? title, String? message}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.help_outline_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title ?? 'मौजूदा इमेज बदलें?'),
          ],
        ),
        content: Text(
          message ?? 'क्या आप वाकई इस कैटेगरी की मौजूदा इमेज को बदलना चाहते हैं? मूल इमेज संदर्भ सुरक्षित रखने के लिए पुष्टि करें।',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('रद्द करें (Cancel)'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('हाँ, बदलें (Proceed)', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _previewRandomPlaceholder() async {
    if (_currentImageUrl.isNotEmpty && !_isPlaceholderPreviewActive) {
      final confirmed = await _confirmReplaceImage(
        title: 'डेमो प्लेसहोल्डर प्रिव्यू',
        message: 'क्या आप अस्थायी डेमो प्लेसहोल्डर प्रिव्यू देखना चाहते हैं? आपकी मूल इमेज सुरक्षित रहेगी और डेटाबेस में तभी नई इमेज सेव होगी जब आप फ़ाइल अपलोड करेंगे।',
      );
      if (!confirmed) return;
    }
    setState(() {
      _activePlaceholder = AdminPlaceholderImages.getRandomCategoryPlaceholder(excludeId: _activePlaceholder?.id);
      _isPlaceholderPreviewActive = true;
      _selectedImageBytes = null;
      _selectedImageFileName = null;
      _imageValidationError = null;
    });
  }

  void _revertPlaceholder() {
    setState(() {
      _isPlaceholderPreviewActive = false;
      _activePlaceholder = null;
    });
  }

  Future<void> _pickImageFromPC() async {
    setState(() {
      _imageValidationError = null;
      _errorMessage = null;
    });

    if (_currentImageUrl.isNotEmpty && _selectedImageBytes == null && !_isPlaceholderPreviewActive) {
      final confirmed = await _confirmReplaceImage(
        title: 'मौजूदा इमेज बदलें?',
        message: 'क्या आप इस कैटेगरी की मौजूदा इमेज को नई PC फ़ाइल से बदलना चाहते हैं?',
      );
      if (!confirmed) return;
    }

    try {
      final picked = await UniversalImagePicker.pickImage();
      if (picked == null) return;

      final bytes = picked.bytes;
      final fileName = picked.fileName.toLowerCase();

      final validExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
      final hasValidExt = validExtensions.any((ext) => fileName.endsWith(ext)) || picked.mimeType.startsWith('image/');
      if (!hasValidExt) {
        setState(() {
          _imageValidationError = 'अमान्य फॉर्मेट। समर्थित फॉर्मेट: JPG, PNG, WEBP';
        });
        return;
      }

      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        setState(() {
          _imageValidationError = 'फाइल का आकार बहुत बड़ा है (${(bytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(1)}MB)। अधिकतम 5MB की अनुमति है।';
        });
        return;
      }

      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageFileName = picked.fileName;
        _selectedImageMimeType = picked.mimeType;
        _isPlaceholderPreviewActive = false;
        _activePlaceholder = null;
        _isImageRemoved = false;
        _imageValidationError = null;
      });
    } catch (e) {
      setState(() {
        _imageValidationError = 'फोटो चुनने में त्रुटि: $e';
      });
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImageBytes = null;
      _selectedImageFileName = null;
      _isPlaceholderPreviewActive = false;
      _activePlaceholder = null;
      _isImageRemoved = true;
      _currentImageUrl = '';
      _imageUrlInputController.clear();
      _imageValidationError = null;
    });
  }

  CategoryEntity _buildCurrentEntity({String? imageUrl, String? imageStoragePath}) {
    List<String> parseList(String text) {
      return text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final effectiveImageUrl = imageUrl ??
        (_selectedImageBytes != null
            ? _currentImageUrl
            : (_imageUrlInputController.text.trim().isNotEmpty
                ? _imageUrlInputController.text.trim()
                : (_isImageRemoved ? '' : _currentImageUrl)));

    return CategoryEntity(
      id: widget.category?.id ?? '',
      name: _nameController.text.trim(),
      slug: _slugController.text.trim(),
      titleHindi: _titleHindiController.text.trim().isNotEmpty ? _titleHindiController.text.trim() : _nameController.text.trim(),
      titleEnglish: _nameController.text.trim(),
      shortDescription: _shortDescController.text.trim(),
      fullDescription: _fullDescController.text.trim(),
      description: _shortDescController.text.trim(),
      imageUrl: effectiveImageUrl,
      imageStoragePath: imageStoragePath ?? (_isImageRemoved ? '' : _currentImageStoragePath),
      iconName: _selectedIconName,
      colorHex: _selectedColorHex,
      aboutCategory: _aboutCategoryController.text.trim(),
      whatIncludes: _subServices,
      commonProblems: _commonProblems,
      whoNeeds: _whoNeedsController.text.trim(),
      whenToContact: _whenToContactController.text.trim(),
      subServices: _subServices,
      benefits: _benefits,
      includedServices: _subServices,
      excludedServices: const [],
      pricingType: _pricingType,
      startingPrice: double.tryParse(_startingPriceController.text.trim()),
      priceUnit: _priceUnitController.text.trim(),
      priceNote: _priceNoteController.text.trim(),
      estimatedDuration: _estimatedDurationController.text.trim(),
      customerRequirements: _customerReqController.text.trim(),
      customerPhotoRequired: _customerPhotoRequired,
      providerRequirements: _providerReqController.text.trim(),
      requiredSkills: const [],
      experienceCertificateRequired: _expCertRequired,
      verificationRequired: _verificationRequired,
      requiredDocuments: const [],
      faqs: _faqs,
      safetyInstructions: _safetyController.text.trim(),
      importantNotes: _importantNotesController.text.trim(),
      disclaimer: _disclaimerController.text.trim(),
      searchKeywords: parseList(_searchKeywordsController.text),
      tags: parseList(_tagsController.text),
      sortOrder: int.tryParse(_sortOrderController.text.trim()) ?? 0,
      status: _status,
      isFeatured: _isFeatured,
      createdAt: widget.category?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  void _openPreview() {
    final previewEntity = _buildCurrentEntity();
    showDialog(
      context: context,
      builder: (context) => CategoryCustomerPreviewDialog(
        category: previewEntity,
        localImageBytes: _selectedImageBytes,
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया सभी आवश्यक फ़ील्ड भरें (* अनिवार्य है)।'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatusText = 'कैटगरी सेव हो रही है...';
    });

    String finalImageUrl = _currentImageUrl;
    String finalImageStoragePath = _currentImageStoragePath;

    try {
      if (_selectedImageBytes != null && _selectedImageBytes!.isNotEmpty) {
        setState(() => _uploadStatusText = 'Cloudflare R2 पर फोटो अपलोड हो रही है...');
        final categoryId = widget.category?.id.isNotEmpty == true
            ? widget.category!.id
            : 'cat_${DateTime.now().millisecondsSinceEpoch}';

        // STRICT R2-ONLY UPLOAD: Direct to Cloudflare R2 via R2UploadService
        // No Firebase Storage fallback to prevent unwanted cloud storage costs!
        final uploadResult = await _storageDataSource.uploadCategoryImage(
          categoryId: categoryId,
          bytes: _selectedImageBytes!,
          fileName: _selectedImageFileName ?? 'cover.jpg',
          mimeType: _selectedImageMimeType,
        );

        finalImageUrl = uploadResult.downloadUrl; // Canonical relative R2 objectKey
        finalImageStoragePath = uploadResult.storagePath;

      } else if (_isPlaceholderPreviewActive) {
        // STRICT SAFETY RULE: Placeholder is for preview ONLY - NEVER upload or save to Firestore!
        // Preserve existing saved image
        finalImageUrl = _currentImageUrl;
        finalImageStoragePath = _currentImageStoragePath;

      } else if (_imageUrlInputController.text.trim().isNotEmpty) {
        finalImageUrl = _imageUrlInputController.text.trim();
      } else if (_isImageRemoved) {
        finalImageUrl = '';
        finalImageStoragePath = '';
      }

      final entityToSave = _buildCurrentEntity(
        imageUrl: finalImageUrl,
        imageStoragePath: finalImageStoragePath,
      );

      setState(() => _uploadStatusText = widget.category != null ? 'डेटाबेस अपडेट हो रहा है...' : 'नई कैटगरी पब्लिश हो रही है...');
      await widget.onSave(entityToSave);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _isUploading = false;
          _errorMessage = errorMsg;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('त्रुटि: $errorMsg'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.category != null;
    final activeColor = _parseColor(_selectedColorHex);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 960,
        height: 880,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Modal Header with Live Visual Avatar Preview
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: activeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_getIconData(_selectedIconName), color: activeColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit ? 'कैटगरी संपादित करें: ${_nameController.text.isNotEmpty ? _nameController.text : widget.category?.name}' : 'नई सेवा श्रेणी बनाएं (Advanced AI Category Builder)',
                        style: AppTextStyles.h2.copyWith(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '1-क्लिक प्रीसेट, उप-सेवाएं, AI सर्च कीवर्ड्स और मूल्य निर्धारण सेट करें',
                        style: AppTextStyles.caption.copyWith(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _openPreview,
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                    label: const Text('कस्टमर व्यू देखें'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _isUploading ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tab Navigation Bar
            Container(
              color: Colors.grey.shade50,
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.flash_on_rounded, size: 18), text: '1. बुनियादी व प्रीसेट'),
                  Tab(icon: Icon(Icons.auto_awesome_rounded, size: 18), text: '2. उप-सेवाएं व AI कीवर्ड्स'),
                  Tab(icon: Icon(Icons.currency_rupee_rounded, size: 18), text: '3. मूल्य व नियम'),
                  Tab(icon: Icon(Icons.palette_outlined, size: 18), text: '4. आइकन, रंग व फोटो'),
                ],
              ),
            ),

            // Error Banner
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                color: Colors.red.shade50,
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12.5))),
                    IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.red), onPressed: () => setState(() => _errorMessage = null)),
                  ],
                ),
              ),

            // Form Body with Tab Views
            Expanded(
              child: Form(
                key: _formKey,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTab1BasicAndPresets(),
                    _buildTab2ServicesAndAIKeywords(),
                    _buildTab3PricingAndRules(),
                    _buildTab4VisualsAndImage(),
                  ],
                ),
              ),
            ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_subServices.length} उप-सेवाएं  •  ${_commonProblems.length} AI कीवर्ड्स  •  कीमत: ₹${_startingPriceController.text.isNotEmpty ? _startingPriceController.text : "0"}',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _isUploading ? null : () => Navigator.pop(context),
                        child: const Text('रद्द करें (Cancel)', style: TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isUploading ? null : _submit,
                        icon: _isUploading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                        label: Text(
                          _isUploading ? _uploadStatusText : (isEdit ? 'अपडेट सेव करें' : 'कैटगरी पब्लिश करें'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 1: Quick Trade Presets & Basic Names
  Widget _buildTab1BasicAndPresets() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1-Click Trade Presets Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.indigo.shade50, Colors.blue.shade50]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: Colors.indigo, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      '1-क्लिक रेडीमेड प्रीसेट्स (Quick Category Presets)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo),
                    ),
                    const Spacer(),
                    Text('टैप करते ही पूरा डेटा ऑटो-फिल हो जाएगा', style: TextStyle(fontSize: 11.5, color: Colors.indigo.shade700)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tradePresets.map((p) {
                    final color = _parseColor(p['colorHex'] as String);
                    return ActionChip(
                      avatar: Icon(_getIconData(p['iconName'] as String), size: 16, color: color),
                      label: Text('${p['titleHindi']} (${p['titleEnglish']})'),
                      labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.indigo.shade100),
                      onPressed: () => _applyTradePreset(p),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionHeader('कैटगरी का नाम व शीर्षक (Category Names)', Icons.badge_outlined),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Category Name (English) *',
                    hintText: 'e.g. Electrician, Plumber',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'नाम आवश्यक है' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _titleHindiController,
                  decoration: const InputDecoration(
                    labelText: 'कैटगरी का नाम (हिंदी) *',
                    hintText: 'उदा. इलेक्ट्रीशियन, प्लंबर',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'हिंदी नाम आवश्यक है' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _slugController,
            onChanged: (_) => setState(() => _isAutoSlug = false),
            decoration: InputDecoration(
              labelText: 'URL Slug *',
              hintText: 'e.g. electrician',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.autorenew, size: 18),
                tooltip: 'नाम से ऑटो-जनरेट करें',
                onPressed: () {
                  setState(() => _isAutoSlug = true);
                  _onNameChanged();
                },
              ),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Slug आवश्यक है' : null,
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _shortDescController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'संक्षिप्त विवरण (Short Description) *',
              hintText: 'होम स्क्रीन कार्ड्स के लिए 1-लाइन का सारांश',
              border: OutlineInputBorder(),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'संक्षिप्त विवरण आवश्यक है' : null,
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _fullDescController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'विस्तृत विवरण (Full Description)',
              hintText: 'इस श्रेणी में क्या-क्या काम होता है उसका पूरा विवरण लिखें...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 2: Sub-Services & AI Keywords
  Widget _buildTab2ServicesAndAIKeywords() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Explanation Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '🧠 Google Gemini AI को समझने के लिए कीवर्ड्स जोड़ें',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.brown),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'ग्राहक जो बोलचाल के शब्द बोलेंगे (उदा: "पंखा खराब है", "नल लीक", "करंट मार रहा है"), उन्हें यहाँ जोड़ें। इससे AI 100% सटीक मैच करेगा।',
                        style: TextStyle(fontSize: 12, color: Colors.brown),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 1. Sub-Services Section
          _buildSectionHeader('1. उपलब्ध उप-सेवाएं (Sub-Services in this Category)', Icons.build_circle_outlined),
          const SizedBox(height: 8),
          const Text('ग्राहकों को यह लिस्ट ऐप में बुकिंग के समय दिखेगी:', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newServiceController,
                  decoration: const InputDecoration(
                    hintText: 'उदा: पंखे की मरम्मत, हाउस वायरिंग, स्विच बोर्ड रिपेयर',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: (_) => _addSubService(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _addSubService,
                icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                label: const Text('जोड़ें (Add)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_subServices.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Text('अभी कोई उप-सेवा नहीं जोड़ी गई है। ऊपर लिखकर "जोड़ें" दबाएं।', style: TextStyle(fontSize: 12, color: Colors.grey))),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _subServices.asMap().entries.map((e) {
                return Chip(
                  avatar: const Icon(Icons.check_circle, size: 16, color: AppColors.primary),
                  label: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  deleteIcon: const Icon(Icons.close_rounded, size: 16),
                  onDeleted: () => setState(() => _subServices.removeAt(e.key)),
                );
              }).toList(),
            ),

          const SizedBox(height: 28),

          // 2. AI Search Keywords / Common Problems
          _buildSectionHeader('2. ग्राहक की सामान्य समस्याएं व AI सर्च कीवर्ड्स (Common Problems)', Icons.psychology_outlined),
          const SizedBox(height: 8),
          const Text('जब ग्राहक बोलकर या लिखकर यह समस्याएं बताएगा तो AI सीधे इस श्रेणी को खोलेगा:', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newProblemController,
                  decoration: const InputDecoration(
                    hintText: 'उदा: पंखा नहीं चल रहा, पानी टपक रहा है, शॉर्ट सर्किट हो गया',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: (_) => _addCommonProblem(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _addCommonProblem,
                icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                label: const Text('जोड़ें (Add)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_commonProblems.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Text('अभी कोई समस्या कीवर्ड नहीं जोड़ा गया है।', style: TextStyle(fontSize: 12, color: Colors.grey))),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _commonProblems.asMap().entries.map((e) {
                return Chip(
                  avatar: const Icon(Icons.search_rounded, size: 16, color: Colors.teal),
                  label: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                  backgroundColor: Colors.teal.shade50,
                  side: BorderSide(color: Colors.teal.shade200),
                  deleteIcon: const Icon(Icons.close_rounded, size: 16),
                  onDeleted: () => setState(() => _commonProblems.removeAt(e.key)),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  void _addSubService() {
    final text = _newServiceController.text.trim();
    if (text.isNotEmpty && !_subServices.contains(text)) {
      setState(() {
        _subServices.add(text);
        _newServiceController.clear();
      });
    }
  }

  void _addCommonProblem() {
    final text = _newProblemController.text.trim();
    if (text.isNotEmpty && !_commonProblems.contains(text)) {
      setState(() {
        _commonProblems.add(text);
        _newProblemController.clear();
      });
    }
  }

  // TAB 3: Pricing, Duration & Booking Rules
  Widget _buildTab3PricingAndRules() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('मूल्य निर्धारण (Pricing Structure)', Icons.currency_rupee_rounded),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _pricingType,
                  decoration: const InputDecoration(labelText: 'मूल्य का प्रकार (Pricing Type)', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'contact_provider', child: Text('कारीगर से बात करें (Contact Provider)')),
                    DropdownMenuItem(value: 'starting_from', child: Text('शुरुआती कीमत (Starting From)')),
                    DropdownMenuItem(value: 'inspection', child: Text('देखने के बाद तय होगा (Price On Inspection)')),
                    DropdownMenuItem(value: 'fixed', child: Text('फिक्स कीमत (Fixed Price)')),
                  ],
                  onChanged: (val) => setState(() => _pricingType = val ?? 'contact_provider'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _startingPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'शुरुआती कीमत (₹ Starting Price)',
                    hintText: 'उदा. 199',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _priceUnitController,
                  decoration: const InputDecoration(
                    labelText: 'कीमत की इकाई (Unit)',
                    hintText: 'उदा. प्रति विजिट, प्रति घंटा',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _priceNoteController,
            decoration: const InputDecoration(
              labelText: 'मूल्य नियम / शर्तें (Price Terms)',
              hintText: 'उदा. सामान का खर्च ग्राहक को अलग से देना होगा।',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionHeader('समय व ग्राहक नियम (Duration & Requirements)', Icons.timer_outlined),
          const SizedBox(height: 14),

          TextFormField(
            controller: _estimatedDurationController,
            decoration: const InputDecoration(
              labelText: 'अनुमानित समय (Estimated Duration)',
              hintText: 'उदा. 30-60 मिनट, 1-2 घंटे',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _customerReqController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'ग्राहक को क्या उपलब्ध कराना होगा?',
              hintText: 'उदा. सीढ़ी, पानी या बिजली का सॉकेट',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('बुकिंग के समय ग्राहक से फोटो मांगना जरूरी करें', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            subtitle: const Text('अगर हाँ, तो ग्राहक को समस्या की फोटो खींचकर भेजनी होगी', style: TextStyle(fontSize: 11.5)),
            value: _customerPhotoRequired,
            onChanged: (val) => setState(() => _customerPhotoRequired = val),
          ),
        ],
      ),
    );
  }

  // TAB 4: Visuals, Icons, Color Palette & Laptop Image Upload
  Widget _buildTab4VisualsAndImage() {
    final activeColor = _parseColor(_selectedColorHex);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('1. कैटगरी का आइकन चुनें (Select Icon)', Icons.emoji_symbols_rounded),
          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemCount: _availableIcons.length,
            itemBuilder: (context, index) {
              final item = _availableIcons[index];
              final isSelected = _selectedIconName == item['name'];
              return InkWell(
                onTap: () => setState(() => _selectedIconName = item['name'] as String),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? activeColor : Colors.grey.shade300, width: isSelected ? 2 : 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item['icon'] as IconData, color: isSelected ? activeColor : Colors.grey.shade700, size: 24),
                      const SizedBox(height: 4),
                      Text(
                        (item['name'] as String).replaceAll('_', ' '),
                        style: TextStyle(fontSize: 9, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? activeColor : Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          _buildSectionHeader('2. ब्रांड रंग चुनें (Theme Color)', Icons.color_lens_outlined),
          const SizedBox(height: 12),

          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: _paletteColors.map((hex) {
              final c = _parseColor(hex);
              final isSelected = _selectedColorHex.toLowerCase() == hex.toLowerCase();
              return GestureDetector(
                onTap: () => setState(() => _selectedColorHex = hex),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? Colors.black : Colors.transparent, width: 3),
                    boxShadow: [
                      if (isSelected) BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          _buildSectionHeader('3. बैनर / कवर फोटो (Laptop/PC Image Upload)', Icons.image_outlined),
          const SizedBox(height: 12),
          _buildImageUploadBox(),
        ],
      ),
    );
  }

  Widget _buildImageUploadBox() {
    final hasSelectedBytes = _selectedImageBytes != null && _selectedImageBytes!.isNotEmpty;
    final hasPlaceholder = _isPlaceholderPreviewActive && _activePlaceholder != null;
    final hasExistingUrl = _currentImageUrl.isNotEmpty && !_isImageRemoved;
    final hasUrlInput = _imageUrlInputController.text.trim().isNotEmpty;
    final hasImage = hasSelectedBytes || hasPlaceholder || hasExistingUrl || hasUrlInput;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasPlaceholder ? Colors.amber.shade400 : Colors.grey.shade200,
          width: hasPlaceholder ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview Box
              Container(
                width: 140,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasPlaceholder ? Colors.amber.shade600 : Colors.grey.shade300,
                    width: hasPlaceholder ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: hasSelectedBytes
                    ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
                    : (hasPlaceholder
                        ? AdminPlaceholderImages.buildPlaceholderWidget(
                            placeholder: _activePlaceholder!,
                            width: 140,
                            height: 100,
                          )
                        : (hasExistingUrl
                            ? AppNetworkOrBase64Image(
                                imageUrl: _currentImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                              )
                            : (hasUrlInput
                                ? AppNetworkOrBase64Image(
                                    imageUrl: _imageUrlInputController.text.trim(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                  )
                                : Center(
                                    child: Icon(
                                      _getIconData(_selectedIconName),
                                      color: _parseColor(_selectedColorHex),
                                      size: 36,
                                    ),
                                  )))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badge
                    if (hasSelectedBytes)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Text(
                          '⚡ नई फ़ाइल: ${_selectedImageFileName ?? "image"} (R2 अपलोड प्रतीक्षारत)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                        ),
                      )
                    else if (hasPlaceholder)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.shade400),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline, size: 14, color: Colors.amber),
                            SizedBox(width: 4),
                            Text(
                              '⚠️ डेमो प्रिव्यू सक्रिय (डेटाबेस में सेव नहीं होगा)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                            ),
                          ],
                        ),
                      )
                    else if (hasExistingUrl)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          '✓ सहेजी गई कैटेगरी इमेज (सक्रिय)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                        ),
                      ),

                    // Action Buttons
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickImageFromPC,
                          icon: const Icon(Icons.upload_file_rounded, size: 16, color: Colors.white),
                          label: Text(
                            hasImage ? 'फ़ाइल बदलें (Change File)' : 'कंप्यूटर से फ़ाइल चुनें (R2 Upload)',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _previewRandomPlaceholder,
                          icon: const Icon(Icons.shuffle_rounded, size: 16, color: Colors.deepPurple),
                          label: const Text(
                            '🎲 रैंडम डेमो प्लेसहोल्डर',
                            style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.deepPurple),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        if (hasPlaceholder)
                          TextButton.icon(
                            onPressed: _revertPlaceholder,
                            icon: const Icon(Icons.undo_rounded, size: 16, color: Colors.teal),
                            label: const Text('↩️ मूल इमेज वापस लाएं', style: TextStyle(color: Colors.teal, fontSize: 12)),
                          ),
                        if (hasImage && !hasPlaceholder)
                          TextButton.icon(
                            onPressed: _removeImage,
                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                            label: const Text('फोटो हटाएं (Remove)', style: TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'नया अपलोड सीधे Cloudflare R2 पर होता है। समर्थित: JPG, PNG, WEBP (अधिकतम 5MB)।',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_imageValidationError != null) ...[
            const SizedBox(height: 8),
            Text(_imageValidationError!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }
}
