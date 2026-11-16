import 'package:flutter_test/flutter_test.dart';
import 'package:apna_jamui_provider/core/localization/provider_locale_controller.dart';
import 'package:apna_jamui_provider/core/localization/provider_strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ProviderLocaleController.instance.resetForTest('hi');
  });

  group('ProviderStrings Bilingual Parity Tests', () {
    test('Promotional Banner reference UI strings switch properly', () {
      // Hindi Check
      ProviderLocaleController.instance.resetForTest('hi');
      expect(ProviderStrings.promotionalBanner, 'प्रचार बैनर');
      expect(ProviderStrings.storefrontBannerPreview, 'स्टोरफ़्रंट बैनर पूर्वावलोकन');
      expect(ProviderStrings.liveOnStorefront, 'स्टोर पर लाइव');
      expect(ProviderStrings.hiddenInactive, 'छिपा हुआ / निष्क्रिय');
      expect(ProviderStrings.bannerActiveStatus, 'बैनर सक्रिय स्थिति');
      expect(ProviderStrings.bannerTitle, 'बैनर शीर्षक');
      expect(ProviderStrings.startDate, 'आरंभ तिथि');
      expect(ProviderStrings.endDate, 'अंतिम तिथि');
      expect(ProviderStrings.savePromotionalBanner, 'प्रचार बैनर सहेजें');

      // English Check
      ProviderLocaleController.instance.resetForTest('en');
      expect(ProviderStrings.promotionalBanner, 'Promotional Banner');
      expect(ProviderStrings.storefrontBannerPreview, 'Storefront Banner Preview');
      expect(ProviderStrings.liveOnStorefront, 'LIVE ON STOREFRONT');
      expect(ProviderStrings.hiddenInactive, 'HIDDEN / INACTIVE');
      expect(ProviderStrings.bannerActiveStatus, 'Banner Active Status');
      expect(ProviderStrings.bannerTitle, 'Banner Title');
      expect(ProviderStrings.startDate, 'Start Date');
      expect(ProviderStrings.endDate, 'End Date');
      expect(ProviderStrings.savePromotionalBanner, 'Save Promotional Banner');
    });

    test('Workspace navigation strings switch properly', () {
      ProviderLocaleController.instance.resetForTest('hi');
      expect(ProviderStrings.navHome, 'होम');
      expect(ProviderStrings.navProducts, 'उत्पाद');
      expect(ProviderStrings.navOrders, 'ऑर्डर्स');
      expect(ProviderStrings.navInventory, 'इन्वेंट्री');
      expect(ProviderStrings.navProfile, 'प्रोफाइल');

      ProviderLocaleController.instance.resetForTest('en');
      expect(ProviderStrings.navHome, 'Home');
      expect(ProviderStrings.navProducts, 'Products');
      expect(ProviderStrings.navOrders, 'Orders');
      expect(ProviderStrings.navInventory, 'Inventory');
      expect(ProviderStrings.navProfile, 'Profile');
    });

    test('Dashboard KPIs and action strings switch properly', () {
      ProviderLocaleController.instance.resetForTest('hi');
      expect(ProviderStrings.businessOverview, 'व्यापार अवलोकन');
      expect(ProviderStrings.totalSales, 'कुल बिक्री');
      expect(ProviderStrings.totalOrders, 'कुल ऑर्डर्स');
      expect(ProviderStrings.pendingOrders, 'लंबित ऑर्डर्स');
      expect(ProviderStrings.totalProducts, 'कुल उत्पाद');
      expect(ProviderStrings.activeProducts, 'सक्रिय उत्पाद');
      expect(ProviderStrings.outOfStock, 'आउट ऑफ स्टॉक');
      expect(ProviderStrings.quickActions, 'त्वरित कार्य');

      ProviderLocaleController.instance.resetForTest('en');
      expect(ProviderStrings.businessOverview, 'Business Overview');
      expect(ProviderStrings.totalSales, 'Total Sales');
      expect(ProviderStrings.totalOrders, 'Total Orders');
      expect(ProviderStrings.pendingOrders, 'Pending Orders');
      expect(ProviderStrings.totalProducts, 'Total Products');
      expect(ProviderStrings.activeProducts, 'Active Products');
      expect(ProviderStrings.outOfStock, 'Out of Stock');
      expect(ProviderStrings.quickActions, 'Quick Actions');
    });

    test('Orders management and status labels switch properly', () {
      ProviderLocaleController.instance.resetForTest('hi');
      expect(ProviderStrings.ordersManagement, 'ऑर्डर प्रबंधन');
      expect(ProviderStrings.sellerOrderNo, 'दुकान ऑर्डर नंबर');
      expect(ProviderStrings.platformOrderNo, 'ऑर्डर नंबर');
      expect(ProviderStrings.orderStatusLabel('placed'), 'नया ऑर्डर');
      expect(ProviderStrings.orderStatusLabel('accepted'), 'स्वीकार किया गया');
      expect(ProviderStrings.orderStatusLabel('delivered'), 'डिलीवर हो गया');
      expect(ProviderStrings.orderStatusLabel('rejected'), 'अस्वीकृत');

      ProviderLocaleController.instance.resetForTest('en');
      expect(ProviderStrings.ordersManagement, 'Orders Management');
      expect(ProviderStrings.sellerOrderNo, 'Seller Order No');
      expect(ProviderStrings.platformOrderNo, 'Order ID');
      expect(ProviderStrings.orderStatusLabel('placed'), 'Placed');
      expect(ProviderStrings.orderStatusLabel('accepted'), 'Accepted');
      expect(ProviderStrings.orderStatusLabel('delivered'), 'Delivered');
      expect(ProviderStrings.orderStatusLabel('rejected'), 'Rejected');
    });

    test('Unit localization and formatting works properly', () {
      ProviderLocaleController.instance.resetForTest('hi');
      expect(ProviderStrings.localizeUnitName('kg'), 'किलो');
      expect(ProviderStrings.localizeUnitName('gm'), 'ग्राम');
      expect(ProviderStrings.localizeUnitName('ltr'), 'लीटर');
      expect(ProviderStrings.formatUnit(1, 'kg'), '1 किलो');
      expect(ProviderStrings.formatUnit(2.5, 'kg'), '2.5 किलो');

      ProviderLocaleController.instance.resetForTest('en');
      expect(ProviderStrings.localizeUnitName('kg'), 'kg');
      expect(ProviderStrings.localizeUnitName('gm'), 'gm');
      expect(ProviderStrings.formatUnit(1, 'kg'), '1 kg');
      expect(ProviderStrings.formatUnit(2.5, 'kg'), '2.5 kg');
    });
  });
}

