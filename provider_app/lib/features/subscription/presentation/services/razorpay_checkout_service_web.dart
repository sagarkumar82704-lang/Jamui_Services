import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'razorpay_checkout_service.dart';

RazorpayCheckoutService createRazorpayCheckoutService() => RazorpayCheckoutServiceWeb();

class RazorpayCheckoutServiceWeb implements RazorpayCheckoutService {
  void Function(String paymentId, String orderId, String signature)? _onSuccess;
  void Function(int code, String message)? _onError;
  void Function()? _onDismiss;

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
  }

  @override
  void open(Map<String, dynamic> options) {
    final optionsJson = jsonEncode(options);

    final successCallback = ((JSString paymentId, JSString orderId, JSString signature) {
      _onSuccess?.call(
        paymentId.toDart,
        orderId.toDart,
        signature.toDart,
      );
    }).toJS;

    final errorCallback = ((JSAny? code, JSAny? message) {
      int codeInt = 100;
      if (code != null) {
        final parsed = int.tryParse(code.toString());
        if (parsed != null) codeInt = parsed;
      }
      final msgStr = message != null ? message.toString() : 'भुगतान विफल रहा।';
      _onError?.call(codeInt, msgStr);
    }).toJS;

    final dismissCallback = (() {
      _onDismiss?.call();
    }).toJS;

    try {
      if (globalContext.has('openRazorpayWebCheckout')) {
        globalContext.callMethod(
          'openRazorpayWebCheckout'.toJS,
          optionsJson.toJS,
          successCallback,
          errorCallback,
          dismissCallback,
        );
      } else {
        _onError?.call(
          1,
          'Razorpay वेब गेटवे उपलब्ध नहीं है। कृपया पृष्ठ रिफ्रेश करें।',
        );
      }
    } catch (e) {
      _onError?.call(100, 'रेजरपे गेटवे खोलने में त्रुटि: $e');
    }
  }

  @override
  void clear() {
    _onSuccess = null;
    _onError = null;
    _onDismiss = null;
  }
}
