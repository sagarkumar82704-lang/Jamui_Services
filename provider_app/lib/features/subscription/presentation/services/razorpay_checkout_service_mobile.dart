import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'razorpay_checkout_service.dart';

RazorpayCheckoutService createRazorpayCheckoutService() => RazorpayCheckoutServiceMobile();

class RazorpayCheckoutServiceMobile implements RazorpayCheckoutService {
  final Razorpay _razorpay = Razorpay();

  void Function(String paymentId, String orderId, String signature)? _onSuccess;
  void Function(int code, String message)? _onError;
  void Function()? _onDismiss;
  void Function(String walletName)? _onExternalWallet;

  @override
  void init({
    required void Function(String paymentId, String orderId, String signature) onSuccess,
    required void Function(int code, String message) onError,
    required void Function() onDismiss,
    void Function(String walletName)? onExternalWallet,
  }) {
    _onSuccess = onSuccess;
    _onError = onError;
    _onDismiss = onDismiss;
    _onExternalWallet = onExternalWallet;

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handleSuccess(PaymentSuccessResponse response) {
    _onSuccess?.call(
      response.paymentId ?? '',
      response.orderId ?? '',
      response.signature ?? '',
    );
  }

  void _handleError(PaymentFailureResponse response) {
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      _onDismiss?.call();
    } else {
      _onError?.call(
        response.code ?? 100,
        response.message ?? 'भुगतान विफल रहा।',
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _onExternalWallet?.call(response.walletName ?? '');
  }

  @override
  void open(Map<String, dynamic> options) {
    _razorpay.open(options);
  }

  @override
  void clear() {
    _razorpay.clear();
  }
}
