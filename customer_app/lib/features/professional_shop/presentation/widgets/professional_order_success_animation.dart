import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/ecom_theme.dart';

/// Premium animated checkmark with self-drawing path and celebratory confetti particles.
///
/// Designed natively using Flutter [AnimationController] and [CustomPainter] without
/// any third-party bloated dependencies. Provides a 60fps, responsive, and lightweight
/// confirmation animation for the Jamui Services Professional Marketplace.
class ProfessionalOrderSuccessAnimation extends StatefulWidget {
  final double size;
  final VoidCallback? onAnimationComplete;

  const ProfessionalOrderSuccessAnimation({
    super.key,
    this.size = 140,
    this.onAnimationComplete,
  });

  @override
  State<ProfessionalOrderSuccessAnimation> createState() => _ProfessionalOrderSuccessAnimationState();
}

class _ProfessionalOrderSuccessAnimationState extends State<ProfessionalOrderSuccessAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _checkProgress;
  late final Animation<double> _confettiProgress;
  late final List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Phase 1: Scale circle up with slight overshoot (0.0 -> 0.35)
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.38, curve: Curves.easeOutBack),
      ),
    );

    // Phase 2: Draw the checkmark path (0.35 -> 0.80)
    _checkProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.35, 0.80, curve: Curves.easeOutCubic),
      ),
    );

    // Phase 3: Confetti burst & gentle float (0.35 -> 1.0)
    _confettiProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.35, 1.0, curve: Curves.easeOutQuad),
      ),
    );

    _particles = _generateConfetti(36);

    _mainController.forward().then((_) {
      if (mounted && widget.onAnimationComplete != null) {
        widget.onAnimationComplete!();
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  List<_ConfettiParticle> _generateConfetti(int count) {
    final rand = math.Random(42);
    final colors = [
      EcomColors.primary,
      const Color(0xFF2E7D32),
      const Color(0xFFFFB300),
      const Color(0xFFFFD54F),
      const Color(0xFFFF7043),
      const Color(0xFF26A69A),
      const Color(0xFF43A047),
    ];

    return List.generate(count, (index) {
      final angle = (index / count) * 2 * math.pi + (rand.nextDouble() - 0.5) * 0.4;
      final speed = 40.0 + rand.nextDouble() * 65.0;
      final color = colors[index % colors.length];
      final isCircle = rand.nextBool();
      final size = 4.0 + rand.nextDouble() * 4.5;
      final rotationSpeed = (rand.nextDouble() - 0.5) * 6.0;

      return _ConfettiParticle(
        angle: angle,
        speed: speed,
        color: color,
        isCircle: isCircle,
        size: size,
        rotationSpeed: rotationSpeed,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;

    return SizedBox(
      width: s * 1.5,
      height: s * 1.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Confetti Particle Explosion
          AnimatedBuilder(
            animation: _confettiProgress,
            builder: (context, _) {
              return CustomPaint(
                size: Size(s * 1.5, s * 1.5),
                painter: _ConfettiPainter(
                  progress: _confettiProgress.value,
                  particles: _particles,
                ),
              );
            },
          ),

          // Central Scaled Green Circle with Self-Drawing Checkmark
          AnimatedBuilder(
            animation: _mainController,
            builder: (context, _) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: s * 0.58,
                  height: s * 0.58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2E7D32),
                        EcomColors.primary,
                        EcomColors.primaryDark,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: EcomColors.primary.withValues(alpha: 0.35),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _SelfDrawingCheckmarkPainter(
                      progress: _checkProgress.value,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ConfettiParticle {
  final double angle;
  final double speed;
  final Color color;
  final bool isCircle;
  final double size;
  final double rotationSpeed;

  const _ConfettiParticle({
    required this.angle,
    required this.speed,
    required this.color,
    required this.isCircle,
    required this.size,
    required this.rotationSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiParticle> particles;

  _ConfettiPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final alpha = ((1.0 - progress) * 1.2).clamp(0.0, 1.0);

    for (final p in particles) {
      // Calculate particle outward trajectory with gentle gravity
      final dist = p.speed * progress;
      final dx = center.dx + math.cos(p.angle) * dist;
      // Drift down with slight simulated gravity as progress advances
      final dy = center.dy + math.sin(p.angle) * dist + (progress * progress * 24.0);

      final paint = Paint()
        ..color = p.color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.rotationSpeed * progress);

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 1.8),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _SelfDrawingCheckmarkPainter extends CustomPainter {
  final double progress;

  _SelfDrawingCheckmarkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * 0.088
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Checkmark geometric points relative to center
    final start = Offset(center.dx - r * 0.38, center.dy + r * 0.02);
    final vertex = Offset(center.dx - r * 0.08, center.dy + r * 0.32);
    final end = Offset(center.dx + r * 0.40, center.dy - r * 0.24);

    final path = Path();
    path.moveTo(start.dx, start.dy);

    // Split checkmark into two linear segments
    const split = 0.38; // Fraction allocated to first downward stroke
    if (progress <= split) {
      final t = progress / split;
      final current = Offset.lerp(start, vertex, t)!;
      path.lineTo(current.dx, current.dy);
    } else {
      path.lineTo(vertex.dx, vertex.dy);
      final t = (progress - split) / (1.0 - split);
      final current = Offset.lerp(vertex, end, t)!;
      path.lineTo(current.dx, current.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SelfDrawingCheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

