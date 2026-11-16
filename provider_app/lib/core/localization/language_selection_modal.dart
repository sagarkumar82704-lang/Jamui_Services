import 'package:flutter/material.dart';
import 'provider_locale_controller.dart';
import 'provider_strings.dart';

/// Universal language selection modal & bottom sheet for Apna Jamui Provider App.
/// Works identically across Mobile, Tablet, and Desktop Web.
class LanguageSelectionModal {
  LanguageSelectionModal._();

  /// Displays the Language Selection UI.
  /// On wide screens (>= 600 px), shows a centered dialog for optimal desktop UX.
  /// On mobile (< 600 px), shows a clean bottom sheet.
  static Future<void> show(BuildContext context) async {
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    if (isWide) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _LanguageContent(onSelected: () => Navigator.of(ctx).pop()),
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: _LanguageContent(onSelected: () => Navigator.of(ctx).pop()),
          ),
        ),
      );
    }
  }
}

class _LanguageContent extends StatelessWidget {
  final VoidCallback onSelected;

  const _LanguageContent({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final current = ProviderLocaleController.instance.currentLocale;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.language_rounded, color: Color(0xFF0F766E), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ProviderStrings.selectLanguage,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Choose your preferred language / अपनी पसंदीदा भाषा चुनें',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _buildOption(
          context: context,
          code: 'hi',
          title: 'हिन्दी',
          subtitle: 'Hindi (डिफ़ॉल्ट)',
          isSelected: current == 'hi',
          key: const Key('lang_option_hi'),
        ),
        const SizedBox(height: 10),
        _buildOption(
          context: context,
          code: 'en',
          title: 'English',
          subtitle: 'English',
          isSelected: current == 'en',
          key: const Key('lang_option_en'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required String code,
    required String title,
    required String subtitle,
    required bool isSelected,
    required Key key,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await ProviderLocaleController.instance.setLocale(code);
          onSelected();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  code == 'hi'
                      ? '✓ भाषा बदलकर हिन्दी कर दी गई'
                      : '✓ Language switched to English',
                ),
                backgroundColor: const Color(0xFF0F766E),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFF16A34A) : Colors.grey.shade200,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    code.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22)
              else
                Icon(Icons.radio_button_unchecked_rounded, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

