import 'provider_locale_controller.dart';

/// Comprehensive bilingual localized strings for Apna Jamui Provider App.
///
/// Features:
/// - Pure Dart getters switching dynamically based on `ProviderLocaleController.instance.isHindi`
/// - 100% type-safe, zero external code-generation overhead
/// - Preserves raw backend / Firestore values untouched while providing localized UI display
class ProviderStrings {
  ProviderStrings._();

  static bool get _hi => ProviderLocaleController.instance.isHindi;
  static bool get isHindi => _hi;

  // ===========================================================================
  // 1. SETTINGS & LANGUAGE SELECTOR
  // ===========================================================================
  static String get languageSettingTitle => _hi ? 'भाषा चुनें' : 'Language';
  static String get languageSettingSubtitle => _hi ? 'हिन्दी (डिफ़ॉल्ट)' : 'English';
  static String get selectLanguage => _hi ? 'भाषा चुनें' : 'Select Language';
  static String get changeLanguage => _hi ? 'भाषा बदलें' : 'Change Language';
  static String get switchLanguageBtn => _hi ? 'बदलें' : 'Switch';
  static String get appSettingsAndLanguage =>
      _hi ? 'ऐप सेटिंग्स और भाषा' : 'App Settings & Language';
  static String get hindi => 'हिन्दी';
  static String get english => 'English';
  static String get languageSwitched =>
      _hi ? 'भाषा बदलकर हिन्दी कर दी गई' : 'Language switched to English';
  static String get appPreferences => _hi ? 'ऐप प्राथमिकताएं' : 'App Preferences';
  static String get businessAndProfileManagement =>
      _hi ? 'व्यवसाय व प्रोफाइल प्रबन्धन' : 'Business & Profile Management';
  static String get businessProfile =>
      _hi ? 'बिजनेस प्रोफाइल' : 'Business Profile';
  static String get businessProfileSubtitle =>
      _hi ? 'प्रीमियम बिजनेस कार्ड, फोटो गैलरी व सोशल लिंक्स' : 'Premium business card, photo gallery & social links';
  static String get editProfile =>
      _hi ? 'प्रोफाइल संपादित करें' : 'Edit Profile';
  static String get editProfileSubtitle =>
      _hi ? 'व्यापार विवरण, सेवा श्रेणियां व पता अपडेट करें' : 'Update business details, service categories & address';
  static String get serviceLocation =>
      _hi ? 'सर्विस लोकेशन व मैप' : 'Service Location & Map';
  static String get accountSecurity =>
      _hi ? 'खाता सुरक्षा व गोपनीयता' : 'Account Security & Privacy';
  static String get changePassword =>
      _hi ? 'पासवर्ड बदलें' : 'Change Password';
  static String get changePasswordSubtitle =>
      _hi ? 'ईमेल रीसेट लिंक भेजें' : 'Send email reset link';
  static String get privacyPolicy =>
      _hi ? 'गोपनीयता नीति' : 'Privacy Policy';
  static String get privacyPolicySubtitle =>
      _hi ? 'डेटा सुरक्षा और उपयोग शर्तें पढ़ें' : 'Read data security and usage terms';
  static String get appHelpAndTerms =>
      _hi ? 'ऐप सहायता व शर्तें' : 'App Help & Terms';
  static String get termsAndConditions =>
      _hi ? 'नियम व शर्तें' : 'Terms & Conditions';
  static String get termsSubtitle =>
      _hi ? 'JAMUI SERVICE पार्टनर सर्विस एग्रीमेंट' : 'Jamui Service partner agreement';
  static String get signOut =>
      _hi ? 'साइन आउट करें' : 'Sign Out';
  static String get deleteAccount =>
      _hi ? 'खाता हटाएं' : 'Delete Account';

  // ===========================================================================
  // 2. PROMOTIONAL BANNER MANAGEMENT (REFERENCE UI AUDIT)
  // ===========================================================================
  static String get promotionalBanner =>
      _hi ? 'प्रचार बैनर' : 'Promotional Banner';
  static String get storefrontBannerPreview =>
      _hi ? 'स्टोरफ़्रंट बैनर पूर्वावलोकन' : 'Storefront Banner Preview';
  static String get liveOnStorefront =>
      _hi ? 'स्टोर पर लाइव' : 'LIVE ON STOREFRONT';
  static String get hiddenInactive =>
      _hi ? 'छिपा हुआ / निष्क्रिय' : 'HIDDEN / INACTIVE';
  static String get bannerActiveStatus =>
      _hi ? 'बैनर सक्रिय स्थिति' : 'Banner Active Status';
  static String get bannerActiveSubtitle =>
      _hi ? 'आपके स्टोर पर आने वाले ग्राहकों को दिखाई देगा' : 'Visible to customers visiting your store';
  static String get bannerImageStorage =>
      _hi ? 'बैनर छवि (पब्लिक स्टोरेज)' : 'Banner Image (Public Storage)';
  static String get changeBannerImage =>
      _hi ? 'बैनर छवि बदलें' : 'Change Banner Image';
  static String get removeImage =>
      _hi ? 'छवि हटाएं' : 'Remove Image';
  static String get bannerTitle =>
      _hi ? 'बैनर शीर्षक' : 'Banner Title';
  static String get bannerSubtitle =>
      _hi ? 'बैनर उपशीर्षक' : 'Banner Subtitle';
  static String get optionalOfferBadgeText =>
      _hi ? 'ऑफ़र बैज टेक्स्ट (वैकल्पिक)' : 'Optional Offer Badge Text';
  static String get scheduleValidityOptional =>
      _hi ? 'समय सीमा वैधता (वैकल्पिक)' : 'Schedule Validity (Optional)';
  static String get startDate =>
      _hi ? 'आरंभ तिथि' : 'Start Date';
  static String get endDate =>
      _hi ? 'अंतिम तिथि' : 'End Date';
  static String get savePromotionalBanner =>
      _hi ? 'प्रचार बैनर सहेजें' : 'Save Promotional Banner';
  static String get savingBanner =>
      _hi ? 'सहेजा जा रहा है...' : 'Saving Banner...';
  static String get deleteBannerTitle =>
      _hi ? 'प्रचार बैनर हटाएं?' : 'Delete Promotional Banner?';
  static String get deleteBannerConfirmation =>
      _hi ? 'यह आपके ग्राहक स्टोरफ़्रंट से तुरंत प्रचार बैनर को हटा देगा।' : 'This will remove the promotional banner from your customer storefront immediately.';
  static String get delete =>
      _hi ? 'हटाएं' : 'Delete';
  static String get cancel =>
      _hi ? 'रद्द करें' : 'Cancel';
  static String get bannerSavedSuccess =>
      _hi ? 'प्रचार बैनर सफलतापूर्वक सहेजा गया!' : 'Promotional banner saved successfully!';
  static String get bannerDeletedSuccess =>
      _hi ? 'प्रचार बैनर हटा दिया गया।' : 'Promotional banner deleted.';
  static String get bannerUploadSuccess =>
      _hi ? 'बैनर छवि सफलतापूर्वक अपलोड हुई!' : 'Promotional banner image uploaded successfully!';
  static String get bannerUploadFailed =>
      _hi ? 'बैनर छवि अपलोड विफल: ' : 'Failed to upload banner image: ';
  static String get bannerContentRequired =>
      _hi ? 'कृपया बैनर शीर्षक, उपशीर्षक, ऑफ़र टेक्स्ट दर्ज करें या एक बैनर छवि अपलोड करें।' : 'Please enter a banner title, subtitle, offer text, or upload a banner image.';
  static String get endDateBeforeStartDate =>
      _hi ? 'अंतिम तिथि आरंभ तिथि से पहले नहीं हो सकती।' : 'End date cannot be earlier than start date.';

  // ===========================================================================
  // 3. WORKSPACE NAVIGATION SHELL
  // ===========================================================================
  static String get navHome => _hi ? 'होम' : 'Home';
  static String get navProducts => _hi ? 'उत्पाद' : 'Products';
  static String get navOrders => _hi ? 'ऑर्डर्स' : 'Orders';
  static String get navInventory => _hi ? 'इन्वेंट्री' : 'Inventory';
  static String get navEarnings => _hi ? 'बिक्री / आय' : 'Earnings & Revenue';
  static String get navBanner => _hi ? 'प्रचार बैनर' : 'Promotional Banner';
  static String get navSettings => _hi ? 'स्टोर सेटिंग्स' : 'Store Settings';
  static String get navProfile => _hi ? 'प्रोफाइल' : 'Profile';
  static String get navMore => _hi ? 'स्टोर व अन्य' : 'Store & More';
  static String get shopOpen => _hi ? 'खुली है' : 'Open';
  static String get shopClosed => _hi ? 'बंद है' : 'Closed';
  static String get shopOpenBadge => _hi ? 'खुली है (Open)' : 'Open';
  static String get shopClosedBadge => _hi ? 'बंद है (Closed)' : 'Closed';
  static String get professionalStore => _hi ? 'प्रोफेशनल स्टोर' : 'Professional Store';
  static String get sellerWorkspace => _hi ? 'विक्रेता डैशबोर्ड' : 'Seller Workspace';

  // ===========================================================================
  // 4. SELLER HOME DASHBOARD
  // ===========================================================================
  static String get businessOverview =>
      _hi ? 'व्यापार अवलोकन' : 'Business Overview';
  static String get totalSales =>
      _hi ? 'कुल बिक्री' : 'Total Sales';
  static String get totalOrders =>
      _hi ? 'कुल ऑर्डर्स' : 'Total Orders';
  static String get pendingOrders =>
      _hi ? 'लंबित ऑर्डर्स' : 'Pending Orders';
  static String get totalProducts =>
      _hi ? 'कुल उत्पाद' : 'Total Products';
  static String get activeProducts =>
      _hi ? 'सक्रिय उत्पाद' : 'Active Products';
  static String get outOfStock =>
      _hi ? 'आउट ऑफ स्टॉक' : 'Out of Stock';
  static String get inStock =>
      _hi ? 'स्टॉक में उपलब्ध' : 'In Stock';
  static String get lowStock =>
      _hi ? 'कम स्टॉक' : 'Low Stock';
  static String get salesTrend7Days =>
      _hi ? 'पिछले 7 दिनों की बिक्री' : '7-Day Sales Trend';
  static String get quickActions =>
      _hi ? 'त्वरित कार्य' : 'Quick Actions';
  static String get addNewProduct =>
      _hi ? 'नया उत्पाद जोड़ें' : 'Add New Product';
  static String get manageCategories =>
      _hi ? 'श्रेणियां प्रबंधित करें' : 'Manage Categories';
  static String get previewStore =>
      _hi ? 'स्टोर पूर्वावलोकन' : 'Preview Store';
  static String get manageBanner =>
      _hi ? 'प्रचार बैनर' : 'Promotional Banner';
  static String get recentOrders =>
      _hi ? 'हालिया ऑर्डर्स' : 'Recent Orders';
  static String get viewAllOrders =>
      _hi ? 'सभी ऑर्डर्स देखें' : 'View All Orders';
  static String get noOrdersYet =>
      _hi ? 'अभी तक कोई ऑर्डर नहीं मिला' : 'No orders yet';

  // ===========================================================================
  // 5. STORE SETTINGS
  // ===========================================================================
  static String get shopSettings =>
      _hi ? 'स्टोर सेटिंग्स' : 'Shop Settings';
  static String get storeSettings =>
      _hi ? 'स्टोर सेटिंग्स' : 'Store Settings';
  static String get deliveryAndPickupSettings =>
      _hi ? 'डिलीवरी एवं पिकअप सेटिंग्स' : 'Delivery & Pickup Settings';
  static String get deliverySettings =>
      _hi ? 'डिलीवरी सेटिंग्स' : 'Delivery Settings';
  static String get homeDelivery =>
      _hi ? 'होम डिलीवरी' : 'Home Delivery';
  static String get deliveryCharge =>
      _hi ? 'डिलीवरी शुल्क (₹)' : 'Delivery Charge (₹)';
  static String get minOrderAmount =>
      _hi ? 'न्यूनतम ऑर्डर राशि (₹)' : 'Min. Order Amount (₹)';
  static String get deliveryRadius =>
      _hi ? 'डिलीवरी दायरा (किमी)' : 'Delivery Radius (km)';
  static String get estimatedDeliveryTime =>
      _hi ? 'अनुमानित डिलीवरी समय (मिनट)' : 'Estimated Delivery Time (mins)';
  static String get pickupSettings =>
      _hi ? 'पिकअप सेटिंग्स' : 'Pickup Settings';
  static String get storePickup =>
      _hi ? 'दुकान से पिकअप' : 'Store Pickup';
  static String get pickupInstructions =>
      _hi ? 'पिकअप निर्देश (वैकल्पिक)' : 'Pickup Instructions (Optional)';
  static String get saveSettings =>
      _hi ? 'सेटिंग्स सहेजें' : 'Save Settings';
  static String get savingSettings =>
      _hi ? 'सहेजा जा रहा है...' : 'Saving Settings...';
  static String get settingsSavedSuccess =>
      _hi ? 'स्टोर सेटिंग्स सफलतापूर्वक अपडेट की गईं!' : 'Shop settings updated successfully!';

  // ===========================================================================
  // 6. PRODUCTS & CATALOGUE
  // ===========================================================================
  static String get productCatalogue =>
      _hi ? 'उत्पाद सूची' : 'Product Catalogue';
  static String get searchProducts =>
      _hi ? 'उत्पाद खोजें...' : 'Search products...';
  static String get all => _hi ? 'सभी' : 'All';
  static String get editProduct =>
      _hi ? 'उत्पाद संपादित करें' : 'Edit Product';
  static String get productDetails =>
      _hi ? 'उत्पाद विवरण' : 'Product Details';
  static String get step1Details =>
      _hi ? 'चरण 1: उत्पाद विवरण' : 'Step 1: Product Details';
  static String get step2Pricing =>
      _hi ? 'चरण 2: मूल्य व विकल्प' : 'Step 2: Pricing & Variants';
  static String get productName =>
      _hi ? 'उत्पाद का नाम' : 'Product Name';
  static String get productDescription =>
      _hi ? 'उत्पाद विवरण' : 'Description';
  static String get storeCategory =>
      _hi ? 'स्टोर श्रेणी' : 'Store Category';
  static String get selectCategory =>
      _hi ? 'श्रेणी चुनें' : 'Select Category';
  static String get productImages =>
      _hi ? 'उत्पाद की तस्वीरें' : 'Product Images';
  static String get uploadImage =>
      _hi ? 'तस्वीर जोड़ें' : 'Add Image';
  static String get packVariants =>
      _hi ? 'पैक विकल्प (वेरिएंट)' : 'Pack Options & Variants';
  static String get bulkStock =>
      _hi ? 'थोक स्टॉक' : 'Bulk Stock';
  static String get sellingPrice =>
      _hi ? 'विक्रय मूल्य' : 'Selling Price';
  static String get discountPrice =>
      _hi ? 'छूट मूल्य (ऑफ़र)' : 'Discounted Price';
  static String get costPrice =>
      _hi ? 'खरीद मूल्य (निजी)' : 'Cost Price (Private)';
  static String get quantity =>
      _hi ? 'मात्रा' : 'Quantity';
  static String get stockAvailable =>
      _hi ? 'उपलब्ध स्टॉक' : 'Available Stock';
  static String get saveProduct =>
      _hi ? 'उत्पाद सहेजें' : 'Save Product';
  static String get savingProduct =>
      _hi ? 'उत्पाद सहेजा जा रहा है...' : 'Saving Product...';
  static String get productSavedSuccess =>
      _hi ? 'उत्पाद सफलतापूर्वक सहेजा गया!' : 'Product saved successfully!';

  // ===========================================================================
  // 7. INVENTORY MANAGEMENT
  // ===========================================================================
  static String get inventoryManagement =>
      _hi ? 'इन्वेंट्री प्रबंधन' : 'Inventory Management';
  static String get stockItems =>
      _hi ? 'स्टॉक स्थिति' : 'Stock Items';
  static String get movementHistory =>
      _hi ? 'स्टॉक लेजर (इतिहास)' : 'Stock Ledger (History)';
  static String get adjustStock =>
      _hi ? 'स्टॉक समायोजित करें' : 'Adjust Stock';
  static String get stockIn =>
      _hi ? 'स्टॉक जोड़ें (+)' : 'Stock In (+)';
  static String get stockOut =>
      _hi ? 'स्टॉक घटाएं (-)' : 'Stock Out (-)';
  static String get auditCorrection =>
      _hi ? 'संशोधन (ऑडिट)' : 'Correction (Audit)';
  static String get reasonNotes =>
      _hi ? 'टिप्पणी / कारण दर्ज करें' : 'Enter reason / notes';
  static String get saveAdjustment =>
      _hi ? 'समायोजन सहेजें' : 'Save Adjustment';

  // ===========================================================================
  // 8. ORDERS MANAGEMENT
  // ===========================================================================
  static String get ordersManagement =>
      _hi ? 'ऑर्डर प्रबंधन' : 'Orders Management';
  static String get allOrders => _hi ? 'सभी' : 'All';
  static String get newOrders => _hi ? 'नए' : 'New';
  static String get preparingOrders => _hi ? 'तैयारी' : 'Preparing';
  static String get outOrders => _hi ? 'डिलीवरी' : 'Out';
  static String get completedOrders => _hi ? 'पूर्ण' : 'Completed';
  static String get rejectedOrders => _hi ? 'अस्वीकृत' : 'Rejected';
  static String get sellerOrderNo =>
      _hi ? 'दुकान ऑर्डर नंबर' : 'Seller Order No';
  static String get platformOrderNo =>
      _hi ? 'ऑर्डर नंबर' : 'Order ID';
  static String get customer => _hi ? 'ग्राहक' : 'Customer';
  static String get itemsCount => _hi ? 'आइटम' : 'Items';
  static String get acceptOrder =>
      _hi ? 'ऑर्डर स्वीकार करें' : 'Accept Order';
  static String get rejectOrder =>
      _hi ? 'ऑर्डर अस्वीकार करें' : 'Reject Order';
  static String get markPacked =>
      _hi ? 'पैक हो गया' : 'Mark Packed';
  static String get sendForDelivery =>
      _hi ? 'डिलीवरी पर भेजें' : 'Send for Delivery';
  static String get readyForPickup =>
      _hi ? 'पिकअप के लिए तैयार' : 'Ready for Pickup';
  static String get completePickup =>
      _hi ? 'पिकअप पूरा करें' : 'Complete Pickup';
  static String get packingSlip =>
      _hi ? 'पैकिंग स्लिप' : 'Packing Slip';
  static String get orderDetails =>
      _hi ? 'ऑर्डर विवरण' : 'Order Details';
  static String get rejectionReasonPrompt =>
      _hi ? 'अस्वीकार करने का कारण दर्ज करें:' : 'Enter rejection reason:';
  static String get newOrderAlert =>
      _hi ? 'नया ऑर्डर प्राप्त हुआ!' : 'New Order Received!';

  // ===========================================================================
  // 9. PACKING SLIP & RECEIPT SHEET
  // ===========================================================================
  static String get packingSlipTitle =>
      _hi ? 'पैकिंग स्लिप' : 'Packing Slip';
  static String get downloadPdf =>
      _hi ? 'PDF डाउनलोड करें' : 'Download PDF';
  static String get sharePdf =>
      _hi ? 'शेयर करें' : 'Share PDF';
  static String get whatsappCustomer =>
      _hi ? 'ग्राहक को WhatsApp करें' : 'WhatsApp to Customer';
  static String get deliveryType =>
      _hi ? 'डिलीवरी प्रकार' : 'Fulfillment Type';
  static String get homeDeliveryType =>
      _hi ? 'होम डिलीवरी' : 'Home Delivery';
  static String get pickupDeliveryType =>
      _hi ? 'दुकान पिकअप' : 'Store Pickup';
  static String get subtotal => _hi ? 'उप-योग' : 'Subtotal';
  static String get deliveryFee => _hi ? 'डिलीवरी शुल्क' : 'Delivery Fee';
  static String get freeWithZero => _hi ? 'मुफ़्त (₹0)' : 'Free (₹0)';
  static String get total => _hi ? 'कुल योग' : 'Total';

  // ===========================================================================
  // 10. SUBSCRIPTION & BILLING
  // ===========================================================================
  static String get professionalSubscription =>
      _hi ? 'प्रोफेशनल सदस्यता' : 'Professional Subscription';
  static String get currentPlan =>
      _hi ? 'वर्तमान प्लान' : 'Current Plan';
  static String get planValidity =>
      _hi ? 'प्लान वैधता' : 'Plan Validity';
  static String get upgradePlan =>
      _hi ? 'प्लान अपग्रेड करें' : 'Upgrade Plan';
  static String get paymentHistory =>
      _hi ? 'भुगतान इतिहास' : 'Payment History';

  // ===========================================================================
  // 6. SELLER-FIRST PRODUCT ARCHETYPES & ADD/EDIT UX
  // ===========================================================================
  static String get productTypeHeading =>
      _hi ? 'सामान का प्रकार' : 'Product Type';
  static String get productTypeSubheading =>
      _hi ? 'अपनी दुकान के सामान के अनुसार सही विकल्प चुनें' : 'Choose the right option for your shop item';

  static String get archetypePieceTitle =>
      _hi ? 'पैकेट / पीस' : 'Piece / Packet';
  static String get archetypePieceSubtitle =>
      _hi ? 'साबुन, बिस्कुट, तेल की बोतल, शैम्पू आदि (फिक्स्ड पैकेट या पीस)' : 'Soap, biscuits, oil bottle, shampoo, etc. (Fixed packet or single piece)';

  static String get archetypeLooseTitle =>
      _hi ? 'खुला सामान' : 'Loose by Weight / Volume';
  static String get archetypeLooseSubtitle =>
      _hi ? 'खुला चावल, चीनी, दाल, तेल आदि (किलो या लीटर में बिकने वाला सामान)' : 'Loose rice, sugar, dal, oil, etc. (Sold by weight or volume in kg/L)';

  static String get archetypeVariantsTitle =>
      _hi ? 'साइज / अलग-अलग पैक' : 'Sizes / Separate Packs';
  static String get archetypeVariantsSubtitle =>
      _hi ? 'कपड़े (S/M/L), जूते (6/7/8), बोतल (100ml/200ml) - प्रत्येक का अलग स्टॉक' : 'Clothes (S/M/L), shoes, bottles - each option has separate physical stock';

  static String get measurementUnit =>
      _hi ? 'नाप की इकाई' : 'Measurement Unit';
  static String get kilogram =>
      _hi ? 'किलोग्राम (kg)' : 'Kilogram (kg)';
  static String get liter =>
      _hi ? 'लीटर (L)' : 'Litre (L)';
  static String get pricePerKg =>
      _hi ? 'प्रति किलो बिक्री मूल्य' : 'Selling Price per kg';
  static String get pricePerLitre =>
      _hi ? 'प्रति लीटर बिक्री मूल्य' : 'Selling Price per Litre';
  static String get pricePerPiece =>
      _hi ? 'बिक्री मूल्य (प्रति पीस/पैकेट)' : 'Selling Price (per piece/packet)';
  static String get mrpOptional =>
      _hi ? 'MRP / अधिकतम खुदरा मूल्य (वैकल्पिक)' : 'MRP / Maximum Retail Price (Optional)';
  static String get totalStockAvailable =>
      _hi ? 'दुकान में कुल उपलब्ध स्टॉक' : 'Total Available Stock';
  static String get decimalStockHint =>
      _hi ? 'उदाहरण: 25.5 (दशमलव मान्य है)' : 'e.g. 25.5 (decimal supported)';
  static String get customerBuyingShortcuts =>
      _hi ? 'ग्राहकों के लिए आसान खरीद विकल्प' : 'Customer Buying Shortcuts';
  static String get customerBuyingShortcutsHelp =>
      _hi ? 'ग्राहक इन पैकों में से चुनकर आसानी से ऑर्डर कर सकते हैं (सबका स्टॉक एक ही जगह से कटेगा)' : 'Customers can quickly choose from these buying options (all deduct from one shared stock)';
  static String get advancedOptionalFields =>
      _hi ? 'अतिरिक्त विवरण (वैकल्पिक)' : 'Additional Details (Optional)';
  static String get costPricePerUnit =>
      _hi ? 'खरीद मूल्य / लागत मूल्य (गोपनीय)' : 'Purchase / Cost Price (Confidential)';
  static String get lowStockThreshold =>
      _hi ? 'कम स्टॉक अलर्ट सीमा' : 'Low Stock Alert Threshold';
  static String get stockLockedNotice =>
      _hi ? 'स्टॉक सुरक्षा: मौजूदा उत्पाद का स्टॉक बदलने के लिए इन्वेंट्री टैब का उपयोग करें' : 'Stock Security: To adjust stock for existing products, please use the Inventory tab';
  static String get goToInventory =>
      _hi ? 'इन्वेंट्री में जाएं' : 'Go to Inventory';
  static String get optionTitle =>
      _hi ? 'विकल्प का नाम' : 'Option Title';
  static String get addOption =>
      _hi ? '+ नया विकल्प जोड़ें' : '+ Add Option';
  static String get deleteOption =>
      _hi ? 'हटाएं' : 'Delete';
  static String get stockPerOption =>
      _hi ? 'इस विकल्प का स्टॉक' : 'Stock for this option';
  static String get sellingPricePerOption =>
      _hi ? 'बिक्री मूल्य' : 'Selling Price';
  static String get invalidStockError =>
      _hi ? 'कृपया मान्य स्टॉक दर्ज करें (शून्य या अधिक)' : 'Please enter a valid stock amount (0 or more)';
  static String get invalidPriceError =>
      _hi ? 'कृपया शून्य से अधिक मान्य मूल्य दर्ज करें' : 'Please enter a valid price greater than 0';
  static String get mrpLowerThanPriceError =>
      _hi ? 'MRP बिक्री मूल्य से कम नहीं हो सकता' : 'MRP cannot be less than selling price';

  // ===========================================================================
  // HELPER FORMATTERS
  // ===========================================================================
  /// Localizes unit names (e.g. kg -> किलो, gm -> ग्राम)
  static String localizeUnitName(String rawUnit) {
    if (!_hi) return rawUnit;
    switch (rawUnit.trim().toLowerCase()) {
      case 'kg':
        return 'किलो';
      case 'gm':
      case 'g':
        return 'ग्राम';
      case 'ltr':
      case 'l':
        return 'लीटर';
      case 'ml':
        return 'मिली';
      case 'pc':
      case 'piece':
      case 'pcs':
        return 'पीस';
      case 'pack':
      case 'pkt':
        return 'पैकेट';
      case 'bottle':
        return 'बोतल';
      case 'box':
        return 'डिब्बा';
      case 'dozen':
        return 'दर्जन';
      case 'plate':
        return 'प्लेट';
      default:
        return rawUnit;
    }
  }

  /// Formats quantity and unit into localized label (e.g., 1 किलो / 1 kg)
  static String formatUnit(double unitValue, String rawUnit) {
    final valStr = unitValue % 1 == 0
        ? unitValue.toInt().toString()
        : unitValue.toString();
    final localizedUnit = localizeUnitName(rawUnit);
    return '$valStr $localizedUnit';
  }

  /// Localizes backend order statuses for display
  static String orderStatusLabel(String rawStatus) {
    switch (rawStatus.trim().toLowerCase()) {
      case 'placed':
        return _hi ? 'नया ऑर्डर' : 'Placed';
      case 'accepted':
        return _hi ? 'स्वीकार किया गया' : 'Accepted';
      case 'preparing':
        return _hi ? 'तैयार हो रहा है' : 'Preparing';
      case 'out_for_delivery':
      case 'out':
        return _hi ? 'डिलीवरी के लिए निकला' : 'Out for Delivery';
      case 'ready_for_pickup':
        return _hi ? 'पिकअप के लिए तैयार' : 'Ready for Pickup';
      case 'delivered':
        return _hi ? 'डिलीवर हो गया' : 'Delivered';
      case 'collected':
        return _hi ? 'पिकअप पूरा हुआ' : 'Collected';
      case 'rejected':
        return _hi ? 'अस्वीकृत' : 'Rejected';
      case 'cancelled':
        return _hi ? 'रद्द' : 'Cancelled';
      default:
        return rawStatus;
    }
  }
}
