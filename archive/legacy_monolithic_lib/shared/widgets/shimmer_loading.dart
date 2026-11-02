import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// [ShimmerLoading] डेटा लोड होते समय स्मूथ और सुंदर कंकाल (Skeleton) लोडर प्रदान करता है।
class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final ShapeBorder? shapeBorder;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.shapeBorder,
  });

  const ShimmerLoading.circular({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = size / 2,
        shapeBorder = const CircleBorder();

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.3, end: 0.8).animate(
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
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: ShapeDecoration(
              color: AppColors.border,
              shape: widget.shapeBorder ??
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                  ),
            ),
          ),
        );
      },
    );
  }
}
