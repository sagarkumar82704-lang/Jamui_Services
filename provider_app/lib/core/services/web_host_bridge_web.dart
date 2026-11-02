import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';

@JS('notifyJamuiHost')
external void _notifyJamuiHost(JSString message);

abstract class WebHostBridge {
  static final Map<String, Completer<Map<String, dynamic>?>> _pendingLocationRequests = {};
  static bool _callbackInstalled = false;
  static int _requestCounter = 0;

  /// Returns true if running inside the host Customer App WebView bridge
  static bool get isHostAvailable {
    try {
      return globalContext.has('JamuiHost');
    } catch (_) {
      return false;
    }
  }

  static void _ensureCallbackInstalled() {
    if (_callbackInstalled) return;
    _callbackInstalled = true;

    try {
      globalContext.setProperty(
        '__onJamuiLocationResponse'.toJS,
        ((JSAny? rawData) {
          try {
            if (rawData == null) return;
            String jsonStr = '';
            if (rawData.isA<JSString>()) {
              jsonStr = (rawData as JSString).toDart;
            } else {
              final jsonObj = globalContext.getProperty<JSObject>('JSON'.toJS);
              final res = jsonObj.callMethod<JSString>('stringify'.toJS, rawData);
              jsonStr = res.toDart;
            }

            if (jsonStr.isEmpty) return;

            final Map<String, dynamic> data = jsonDecode(jsonStr) as Map<String, dynamic>;
            final String? reqId = data['requestId'] as String?;
            if (reqId != null && _pendingLocationRequests.containsKey(reqId)) {
              _pendingLocationRequests.remove(reqId)?.complete(data);
            } else {
              debugPrint('⚠️ [WebHostBridge] Stale or duplicate response rejected for requestId: $reqId');
            }
          } catch (e) {
            debugPrint('⚠️ Error processing JamuiLocationResponse in WebView bridge: $e');
          }
        }).toJS,
      );
    } catch (e) {
      debugPrint('⚠️ Could not register __onJamuiLocationResponse: $e');
    }
  }

  static void notify(String message) {
    try {
      _notifyJamuiHost(message.toJS);
    } catch (_) {}
  }

  /// Request high-accuracy native GPS location from the host Customer App
  /// Returns a map with `latitude`, `longitude`, `accuracy`, and `success`, or null if unavailable/timed out.
  static Future<Map<String, dynamic>?> requestNativeLocation({
    Duration timeout = const Duration(seconds: 28),
  }) async {
    if (!isHostAvailable) {
      return null;
    }

    _ensureCallbackInstalled();

    final requestId = 'loc_${DateTime.now().millisecondsSinceEpoch}_${_requestCounter++}';
    final completer = Completer<Map<String, dynamic>?>();
    _pendingLocationRequests[requestId] = completer;

    final requestPayload = jsonEncode({
      'action': 'GET_NATIVE_LOCATION',
      'requestId': requestId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    notify(requestPayload);

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pendingLocationRequests.remove(requestId);
        debugPrint('⏱️ [WebHostBridge] Native location request timed out for $requestId');
        return null;
      },
    );
  }
}
