import 'razorpay_checkout_service_stub.dart'
    if (dart.library.html) 'razorpay_checkout_service_web.dart'
    if (dart.library.io) 'razorpay_checkout_service_mobile.dart';

/// Unified cross-platform Razorpay Checkout service.
/// Uses native [package:razorpay_flutter] on Android/iOS and official
/// Razorpay Checkout JS SDK on Flutter Web.
abstract class RazorpayCheckoutService {
  factory RazorpayCheckoutService() => createRazorpayCheckoutService();

  void init({
    required void Function(String paymentId, String orderId, String signature) onSuccess,
    required void Function(int code, String message) onError,
    required void Function() onDismiss,
    void Function(String walletName)? onExternalWallet,
  });

  void open(Map<String, dynamic> options);

  void clear();
}
