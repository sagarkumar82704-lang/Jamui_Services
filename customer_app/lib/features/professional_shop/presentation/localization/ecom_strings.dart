import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scoped locale controller for the Professional Seller Mini E-commerce shop experience.
/// Option A: Embedded directly in Storefront AppBar / menu without touching main customer profile.
class EcomLocaleController extends ChangeNotifier {
  EcomLocaleController._();
  static final EcomLocaleController instance = EcomLocaleController._();

  static const String _prefKey = 'pro_shop_language_code';
  String _code = 'hi'; // Default Hindi

  String get currentLocale => _code;
  bool get isHindi => _code == 'hi';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKey);
      if (code == 'en' || code == 'hi') {
        _code = code!;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setLocale(String code) async {
    if (code != 'hi' && code != 'en') return;
    _code = code;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, code);
    } catch (_) {}
  }

  Future<void> toggleLocale() async {
    await setLocale(isHindi ? 'en' : 'hi');
  }

  // Keep old method names for compatibility with existing storefront code
  Future<void> setLanguage(String code) => setLocale(code);
  Future<void> toggleLanguage() => toggleLocale();

  // Compatibility: old ValueNotifier-based code
  String get currentCode => _code;
}

/// Comprehensive bilingual localized strings for the Mini E-commerce Shop flow.
class EcomStrings {
  EcomStrings._();

  static bool get _hi => EcomLocaleController.instance.isHindi;

  // Header & Navigation
  static String get languageTitle => _hi ? 'भाषा चुनें' : 'Select Language';
  static String get hindi => 'हिन्दी';
  static String get english => 'English';
  static String get languageSwitched => _hi ? 'भाषा सफलतापूर्वक बदली गई' : 'Language switched to English';
  static String get deliveryEstimate => _hi ? 'डिलीवरी 30-45 मिनट' : 'Delivery 30-45 mins';
  static String get pickupAvailable => _hi ? 'दुकान से लें (Pickup)' : 'Pickup from Store';
  static String get searchStorePlaceholder => _hi ? 'दुकान में उत्पाद खोजें...' : 'Search products in store...';
  static String get all => _hi ? 'सभी' : 'All';

  // Store & Status
  static String get shopOpen => _hi ? 'खुली है' : 'Open';
  static String get shopClosed => _hi ? 'बंद है' : 'Closed';
  static String ratingWithCount(double rating, int count) =>
      '★ ${rating.toStringAsFixed(1)} ($count${_hi ? ' रिव्यू' : ' reviews'})';

  // Product Grid & Details
  static String get inStock => _hi ? 'स्टॉक में उपलब्ध' : 'In Stock';
  static String get outOfStock => _hi ? 'स्टॉक खत्म' : 'Out of Stock';
  static String get lowStock => _hi ? 'कम स्टॉक' : 'Low Stock';
  static String offTag(int percent) => '$percent% ${_hi ? 'छूट' : 'OFF'}';
  static String get add => _hi ? 'जोड़ें' : 'Add';
  static String get addToCart => _hi ? 'कार्ट में जोड़ें' : 'Add to Cart';
  static String get addedToCart => _hi ? 'कार्ट में जोड़ा गया' : 'Added to Cart';
  static String get productDetails => _hi ? 'उत्पाद विवरण' : 'Product Details';
  static String get keyHighlights => _hi ? 'मुख्य विशेषताएं' : 'Key Highlights';
  static String get categoryLabel => _hi ? 'श्रेणी' : 'Category';
  static String get packSizeLabel => _hi ? 'इकाई / पैक' : 'Pack / Unit';
  static String get availabilityLabel => _hi ? 'उपलब्धता' : 'Availability';
  static String get soldBy => _hi ? 'दुकानदार' : 'Sold by';
  static String get description => _hi ? 'विवरण' : 'Description';
  static String get quantity => _hi ? 'मात्रा' : 'Quantity';
  static String get optionsTitle => _hi ? 'पैक व वजन विकल्प' : 'Options & Pack Sizes';
  static String get packagingOptions => _hi ? 'पैकेजिंग विकल्प' : 'Packaging Options';
  static String get reviewsCount => _hi ? 'रिव्यू' : 'reviews';
  static String get shopRatingLabel => _hi ? 'दुकान रेटिंग' : 'Shop Rating';
  static String get discountOff => _hi ? 'छूट' : 'OFF';
  static String get viewCart => _hi ? 'कार्ट देखें' : 'View Cart';
  static String get items => _hi ? 'आइटम' : 'items';

  /// Formats unit value and unit string into localized label (e.g., 1 किलो / 1 kg)
  static String formatUnit(double unitValue, String rawUnit) {
    final valStr = unitValue % 1 == 0 ? unitValue.toInt().toString() : unitValue.toString();
    final localizedUnit = localizeUnitName(rawUnit);
    return '$valStr $localizedUnit';
  }

  static String localizeUnitName(String rawUnit) {
    if (!_hi) return rawUnit;
    switch (rawUnit.trim().toLowerCase()) {
      case 'kg':
      case 'kilogram':
      case 'किलो':
        return 'किलो';
      case 'gm':
      case 'g':
      case 'gram':
      case 'ग्राम':
        return 'ग्राम';
      case 'l':
      case 'ltr':
      case 'liter':
      case 'litre':
        return 'लीटर';
      case 'ml':
        return 'मिली';
      case 'pc':
      case 'pcs':
      case 'piece':
      case 'pieces':
        return 'पीस';
      case 'pack':
      case 'packet':
        return 'पैक';
      case 'dozen':
        return 'दर्जन';
      default:
        return rawUnit;
    }
  }

  // Store Quick Menu (Reference Screen 6 Adaptation)
  static String get storeMenuTitle => _hi ? 'मेरा खाता (स्टोर मेनू)' : 'My Account (Store Menu)';
  static String get storeInfoAndAddress => _hi ? 'पते व दुकान जानकारी (Addresses)' : 'Store Info & Address';
  static String get contactSellerHelp => _hi ? 'सहायता (Help & Contact)' : 'Help & Contact Seller';
  static String get appLanguageSettings => _hi ? 'ऐप सेटिंग्स (भाषा: हिन्दी / EN)' : 'Store Settings (Language)';
  static String get callSeller => _hi ? 'दुकानदार को कॉल करें' : 'Call Seller';
  static String get whatsappSeller => _hi ? 'WhatsApp पर चैट करें' : 'Chat on WhatsApp';
  static String get storeTimings => _hi ? 'दुकान खुलने का समय' : 'Store Timings';
  static String get guestCustomer => _hi ? 'जमुई ग्राहक' : 'Jamui Customer';

  // Cart
  static String myCartTitle(int count) => '${_hi ? 'मेरा कार्ट' : 'My Cart'} ($count ${_hi ? 'आइटम' : 'items'})';
  static String get itemTotal => _hi ? 'आइटम कुल' : 'Item Total';
  static String get deliveryFee => _hi ? 'डिलीवरी शुल्क' : 'Delivery Fee';
  static String get free => _hi ? 'मुफ़्त' : 'FREE';
  static String get freeDelivery => _hi ? 'मुफ़्त डिलीवरी' : 'FREE';
  static String get totalPayable => _hi ? 'कुल भुगतान' : 'Total Payable';
  static String get placeOrder => _hi ? 'ऑर्डर करें' : 'Place Order';
  static String get cartEmptyTitle => _hi ? 'आपका कार्ट खाली है' : 'Your Cart is Empty';
  static String get cartEmptySubtitle => _hi ? 'दुकान से पसंदीदा सामान चुनें और कार्ट में जोड़ें।' : 'Browse the catalog and add products to your cart.';
  static String get emptyCartTitle => cartEmptyTitle;
  static String get emptyCartSubtitle => cartEmptySubtitle;
  static String get shopNow => _hi ? 'खरीदारी शुरू करें' : 'Shop Now';
  static String get browseProducts => _hi ? 'उत्पाद ब्राउज़ करें' : 'Browse Products';
  static String get deliveryAddress => _hi ? 'डिलीवरी का पता' : 'Delivery Address';
  static String get pickupInstructions => _hi ? 'पिकअप निर्देश' : 'Pickup Instructions';
  static String get pickupOption => _hi ? 'दुकान से लें' : 'Store Pickup';
  static String get deliveryOption => _hi ? 'होम डिलीवरी' : 'Home Delivery';
  static String get paymentMethod => _hi ? 'भुगतान का तरीका' : 'Payment Method';
  static String get cashOnDelivery => _hi ? 'कैश ऑन डिलीवरी (COD)' : 'Cash on Delivery (COD)';
  static String get codCashOnDelivery => cashOnDelivery;
  static String get payOnline => _hi ? 'ऑनलाइन भुगतान (UPI / कार्ड)' : 'Pay Online (UPI / Card)';
  static String get onlineUpiSoon => _hi ? 'ऑनलाइन UPI (जल्द)' : 'Online UPI (Soon)';
  static String get confirmOrder => _hi ? 'ऑर्डर कन्फर्म करें' : 'Confirm Order';
  static String get placingOrder => _hi ? 'ऑर्डर सबमिट हो रहा है...' : 'Placing your order...';
  static String get enterDeliveryAddress => _hi ? 'अपना पूरा डिलीवरी पता लिखें (मोहल्ला, लैंडमार्क सहित)' : 'Enter full delivery address (locality, landmark)';
  static String get addressRequiredError => _hi ? 'कृपया डिलीवरी के लिए अपना पूरा पता लिखें।' : 'Please enter your delivery address.';
  static String get contactPhoneLabel => _hi ? 'संपर्क मोबाइल नंबर' : 'Contact Mobile Number';
  static String get phoneRequiredError => _hi ? 'कृपया वैध 10-अंकीय मोबाइल नंबर दर्ज करें।' : 'Please enter a valid 10-digit mobile number.';
  static String get orderNotesHint => _hi ? 'दुकानदार के लिए निर्देश (वैकल्पिक)' : 'Instructions for seller (optional)';
  static String minOrderWarning(int minAmt) =>
      _hi ? 'होम डिलीवरी के लिए न्यूनतम ऑर्डर ₹$minAmt होना चाहिए।' : 'Minimum order for home delivery is ₹$minAmt.';
  static String freeDeliveryUnlocked(int threshold) =>
      _hi ? '₹$threshold+ के ऑर्डर पर मुफ़्त डिलीवरी!' : 'Free delivery on orders ₹$threshold+!';
  static String get fulfillmentMethodLabel => _hi ? 'डिलीवरी या पिकअप चुनें' : 'Select Fulfillment Mode';

  // Conflict Dialog
  static String get clearCartTitle => _hi ? 'कार्ट खाली करें और नई दुकान चुनें?' : 'Clear Cart & Switch Shop?';
  static String clearCartMessage(String shopName) => _hi
      ? 'आपके कार्ट में दूसरी दुकान का सामान है। क्या आप उसे हटाकर "$shopName" से नया कार्ट शुरू करना चाहते हैं?'
      : 'Your cart contains items from another store. Clear cart and start shopping from "$shopName"?';
  static String get clearAndAdd => _hi ? 'हाँ, नया कार्ट बनाएं' : 'Yes, Clear & Add';
  static String get cancel => _hi ? 'रद्द करें' : 'Cancel';

  // Favorites
  static String get myFavorites => _hi ? 'मेरी पसंदीदा चीजें' : 'My Favorites';
  static String get noFavoritesTitle => _hi ? 'कोई पसंदीदा उत्पाद नहीं है' : 'No Favorite Products Yet';
  static String get noFavoritesSubtitle =>
      _hi ? 'दुकान में किसी भी उत्पाद पर दिल (Heart) दबाकर यहाँ सहेजें।' : 'Tap the heart icon on any product to save it here.';

  // Order History & Tracking
  static String get myOrdersTitle => _hi ? 'मेरे ऑर्डर' : 'My Orders';
  static String get myOrders => myOrdersTitle;
  static String get activeOrdersTab => _hi ? 'सक्रिय ऑर्डर' : 'Active Orders';
  static String get pastOrdersTab => _hi ? 'पिछले ऑर्डर' : 'Past Orders';
  static String get activeOrders => activeOrdersTab;
  static String get pastOrders => pastOrdersTab;
  static String get noActiveOrders => _hi ? 'अभी कोई सक्रिय ऑर्डर नहीं है' : 'No active orders right now';
  static String get noPastOrders => _hi ? 'अभी तक कोई ऑर्डर नहीं किया' : 'You haven\'t placed any orders yet.';
  static String get noOrdersTitle => _hi ? 'कोई ऑर्डर नहीं मिला' : 'No Orders Found';
  static String get exploreShopsHint => _hi ? 'ताज़े किराने और रोज़मर्रा का सामान खोजें।' : 'Discover fresh groceries and daily essentials.';
  static String get errorLoadingOrders => _hi ? 'ऑर्डर लोड नहीं हो सके' : 'Unable to load orders';
  static String get trackOrder => _hi ? 'ऑर्डर ट्रैक करें' : 'Track Order';
  static String get reorder => _hi ? 'पुनः ऑर्डर करें' : 'Reorder';
  static String get orderNumber => _hi ? 'ऑर्डर' : 'Order';
  static String orderIdLabel(String id) => '${_hi ? 'ऑर्डर' : 'Order'} #$id';
  static String get dateLabel => _hi ? 'दिनांक' : 'Date';
  static String dateLabelFmt(String date) => '${_hi ? 'दिनांक' : 'Date'}: $date';
  static String get viewOrderDetails => _hi ? 'ऑर्डर विवरण देखें' : 'View Order Details';
  static String estimatedDelivery(String time) => '${_hi ? 'अनुमानित' : 'Estimated'}: $time';

  // Order Status Badges
  static String get loginRequired => _hi ? 'लॉगिन आवश्यक है' : 'Login Required';
  static String get pleaseSignInOrders => _hi ? 'कृपया अपने ऑर्डर देखने के लिए साइन इन करें।' : 'Please sign in to view your orders.';
  static String get orderStatusPlaced => _hi ? 'ऑर्डर मिला' : 'Placed';
  static String get orderStatusPacked => _hi ? 'तैयार हो रहा है' : 'Confirmed';
  static String get orderStatusReadyForPickup => _hi ? 'पिकअप के लिए तैयार' : 'Ready for Pickup';
  static String get orderStatusOutForDelivery => _hi ? 'रास्ते में' : 'Out for Delivery';
  static String get orderStatusDelivered => _hi ? 'पहुंच गया' : 'Delivered';
  static String get orderStatusCancelled => _hi ? 'रद्द' : 'Cancelled';
  static String get orderStatusRejected => _hi ? 'अस्वीकृत' : 'Rejected';
  static String get deliveryOtpLabel => _hi ? 'डिलीवरी OTP' : 'Delivery OTP';

  // Order Status Timeline Stages
  static String get statusPlaced => _hi ? 'ऑर्डर प्राप्त हुआ' : 'Order Placed';
  static String get statusPlacedDesc => _hi ? 'दुकानदार को ऑर्डर भेजा गया है' : 'Order sent to seller';
  static String get statusPacking => _hi ? 'प्रोसेसिंग (पैकिंग) चल रही है' : 'Processing & Packing';
  static String get statusPackingDesc => _hi ? 'दुकानदार सामान तैयार कर रहा है' : 'Store is preparing your items';
  static String get statusOutForDelivery => _hi ? 'रास्ते में' : 'Out for Delivery';
  static String get statusOutForDeliveryDesc => _hi ? 'डिलीवरी बॉय सामान लेकर निकल चुका है' : 'Rider is on the way with your order';
  static String get statusDelivered => _hi ? 'डिलीवरी' : 'Delivered';
  static String get statusDeliveredDesc => _hi ? 'सामान सफलतापूर्वक पहुंच गया' : 'Order successfully delivered';
  static String get statusReadyForPickup => _hi ? 'दुकान पर तैयार' : 'Ready for Pickup';
  static String get statusReadyForPickupDesc => _hi ? 'आपका ऑर्डर दुकान से लेने के लिए तैयार है' : 'Store is ready with your order';
  static String get statusPickedUp => _hi ? 'सामान प्राप्त हुआ' : 'Collected / Picked Up';
  static String get statusPickedUpDesc => _hi ? 'दुकान काउंटर से प्राप्त किया गया' : 'Collected from store counter';
  static String get statusCancelled => _hi ? 'ऑर्डर रद्द' : 'Order Cancelled';
  static String get statusRejected => _hi ? 'दुकानदार द्वारा अस्वीकृत' : 'Rejected by Seller';

  // Order Placement Animation & Confirmation
  static String get orderProcessingTitle => _hi ? 'आपका ऑर्डर प्रोसेस हो रहा है...' : 'Processing your order...';
  static String get orderProcessingSubtitle => _hi ? 'कृपया प्रतीक्षा करें।' : 'Please wait.';
  static String get orderSuccessTitle => _hi ? 'ऑर्डर सफलतापूर्वक हो गया!' : 'Order Placed Successfully!';
  static String get orderSuccessSubtitle => _hi ? 'धन्यवाद! आपका ऑर्डर मिल गया है।' : 'Thank you! Your order has been received.';
  static String get continueShopping => _hi ? 'शॉपिंग जारी रखें' : 'Continue Shopping';
  static String get secureTransaction => _hi ? 'सुरक्षित लेनदेन • Jamui Services' : 'Secure Transaction • Jamui Services';

  // Errors & Retry
  static String get retry => _hi ? 'पुनः प्रयास करें' : 'Retry';
  static String get errorLoadingCatalog => _hi ? 'उत्पाद लोड नहीं हो सके। कृपया दोबारा कोशिश करें।' : 'Failed to load catalog. Please retry.';
  static String get noProductsFound => _hi ? 'कोई उत्पाद नहीं मिला' : 'No products found';
  static String get tryAnotherCategory => _hi ? 'कृपया दूसरा श्रेणी या खोज शब्द चुनें।' : 'Try selecting another category or keyword.';
}
