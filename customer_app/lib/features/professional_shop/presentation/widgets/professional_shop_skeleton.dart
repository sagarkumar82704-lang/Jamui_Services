import 'package:flutter/material.dart';

/// Card-matching Shimmer Skeleton Placeholder for Jamui Services Professional Shops.
///
/// Ensures exact layout geometry match with [ProfessionalShopCard] to eliminate
/// layout shifts/jumps when real vendor data finishes loading.
class ProfessionalShopSkeleton extends StatefulWidget {
  const ProfessionalShopSkeleton({super.key});

  @override
  State<ProfessionalShopSkeleton> createState() => _ProfessionalShopSkeletonState();
}

class _ProfessionalShopSkeletonState extends State<ProfessionalShopSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final opacity = _animation.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 88x88 Image Placeholder
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 14),

              // Details Placeholder
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Bar
                    Container(
                      height: 16,
                      width: 160,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300.withValues(alpha: opacity),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Distance/Locality Chip Placeholder
                    Row(
                      children: [
                        Container(
                          height: 14,
                          width: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300.withValues(alpha: opacity),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          height: 14,
                          width: 45,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300.withValues(alpha: opacity),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Fulfillment & Open Chips Placeholder
                    Row(
                      children: [
                        Container(
                          height: 16,
                          width: 95,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300.withValues(alpha: opacity),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          height: 16,
                          width: 65,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300.withValues(alpha: opacity),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Pricing Footer Placeholder
                    Row(
                      children: [
                        Container(
                          height: 12,
                          width: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300.withValues(alpha: opacity),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          height: 12,
                          width: 30,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300.withValues(alpha: opacity),
                            borderRadius: BorderRadius.circular(4),
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
      },
    );
  }
}
