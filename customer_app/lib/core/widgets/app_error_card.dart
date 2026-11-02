import 'package:flutter/material.dart';

/// [AppErrorCard] — एरर / त्रुटि दिखाने वाला कॉमन विजेट।
/// 
/// इंटरनेट कटने या डेटा फेचिंग में समस्या आने पर लाल रंग का सुंदर एरर बॉक्स दिखाता है।
/// 
/// ## इस्तेमाल करने का तरीका:
/// ```dart
/// AppErrorCard(
///   message: 'इंटरनेट कनेक्शन नहीं है।',
///   onRetry: () => fetchProviders(),
/// )
/// ```
class AppErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  const AppErrorCard({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'पुनः प्रयास करें',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF991B1B),
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFFDC2626)),
                label: Text(
                  retryLabel,
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
