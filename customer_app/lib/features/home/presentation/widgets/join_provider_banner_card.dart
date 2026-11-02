import 'package:flutter/material.dart';
import '../../../../core/services/provider_app_launcher_service.dart';

class JoinProviderBannerCard extends StatelessWidget {
  final bool isCompact;

  const JoinProviderBannerCard({
    super.key,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E3A8A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle background decoration circles
          Positioned(
            right: -20,
            bottom: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            right: 40,
            top: -15,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isCompact ? 14 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(
                        Icons.handyman_rounded,
                        color: Color(0xFFFBBF24),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'क्या आप सर्विस प्रोवाइडर हैं?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15.5,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.stars_rounded, color: Color(0xFFFBBF24), size: 16),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Jamui Services से जुड़ें और अपने बिजनेस को अधिक ग्राहकों तक पहुँचाएँ।',
                            style: TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isCompact ? 12 : 16),
                Row(
                  children: [
                    // Highlight tags
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '0% कमीशन',
                        style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'सीधे कॉल्स',
                        style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => ProviderAppLauncherService.launchProviderApp(context),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF0F172A)),
                      label: const Text(
                        'प्रोवाइडर बनें',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBBF24),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
