import 'dart:math';
import 'package:flutter/material.dart';

class PremiumBackground extends StatelessWidget {
  const PremiumBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return child;

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0B0B0D),
                  Color(0xFF0E0E10),
                  Color(0xFF100F0D),
                  Color(0xFF0B0B0D),
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(painter: _WavePainter()),
        ),
        Positioned(
          top: -60,
          left: -40,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFD4AF37).withValues(alpha: 0.04),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          right: -60,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFB8962E).withValues(alpha: 0.03),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (var i = 0; i < 4; i++) {
      paint.color = const Color(0xFFD4AF37).withValues(alpha: 0.025 + i * 0.005);
      final path = Path();
      final yOffset = size.height * (0.2 + i * 0.18);
      path.moveTo(0, yOffset);
      for (var x = 0.0; x <= size.width; x += 1) {
        final y = yOffset +
            sin((x / size.width) * pi * 2 + i * 0.8) * 30 +
            sin((x / size.width) * pi * 3 + i * 1.2) * 15;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
