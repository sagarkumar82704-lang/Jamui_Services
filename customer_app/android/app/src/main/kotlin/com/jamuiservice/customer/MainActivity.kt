package com.jamuiservice.customer

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.webkit.CookieManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val PAYMENT_CHANNEL = "com.jamuiservice.customer/intent_launcher"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            CookieManager.getInstance().setAcceptCookie(true)
        } catch (_: Exception) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PAYMENT_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "launchPaymentIntent") {
                val rawUri = call.argument<String>("uri")
                if (rawUri.isNullOrBlank()) {
                    result.error("INVALID_URI", "URI cannot be empty", null)
                    return@setMethodCallHandler
                }

                try {
                    val intent = if (rawUri.startsWith("intent://") || rawUri.startsWith("intent:#Intent")) {
                        Intent.parseUri(rawUri, Intent.URI_INTENT_SCHEME)
                    } else {
                        Intent(Intent.ACTION_VIEW, Uri.parse(rawUri))
                    }

                    // Security Guard: Verify scheme belongs to trusted payment flows
                    val scheme = (intent.scheme ?: intent.data?.scheme)?.lowercase()
                    val allowedSchemes = setOf(
                        "upi", "tez", "phonepe", "paytmmp", "paytm",
                        "gpay", "bhim", "cred", "credpay", "mobikwik"
                    )

                    if (scheme == null || !allowedSchemes.contains(scheme)) {
                        result.error("DISALLOWED_SCHEME", "Scheme '$scheme' is not a permitted payment scheme", null)
                        return@setMethodCallHandler
                    }

                    // Ensure safe intent dispatch flags
                    intent.addCategory(Intent.CATEGORY_BROWSABLE)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK

                    if (intent.resolveActivity(packageManager) != null) {
                        startActivity(intent)
                        result.success(mapOf("status" to "launched"))
                    } else {
                        // Check if an HTTPS browser fallback URL is provided by Razorpay
                        val fallback = intent.getStringExtra("browser_fallback_url")
                        if (!fallback.isNullOrBlank() && (fallback.startsWith("http://") || fallback.startsWith("https://"))) {
                            result.success(mapOf("status" to "fallback", "fallbackUrl" to fallback))
                        } else {
                            result.success(mapOf("status" to "not_installed", "scheme" to scheme))
                        }
                    }
                } catch (e: Exception) {
                    result.error("INTENT_ERROR", e.localizedMessage ?: "Failed to resolve intent", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
