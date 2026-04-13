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
                  Color(0xFF0E0D0B),
                  Color(0xFF0B0B0D),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // Single very subtle wave — barely visible, smooth, elegant
        Positioned.fill(
          child: CustomPaint(painter: _SubtleWavePainter()),
        ),

        // Soft radial glow — top area
        Positioned(
          top: -60,
          left: -40,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFD4AF37).withValues(alpha: 0.035),
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

class _SubtleWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Two very soft wave bands near the bottom — barely visible
    for (var i = 0; i < 2; i++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = Color.fromRGBO(212, 175, 55, 0.06 - i * 0.02);

      final yBase = size.height * (0.72 + i * 0.08);

      final path = Path();
      path.moveTo(0, yBase);
      for (var x = 0.0; x <= size.width; x += 1) {
        final t = x / size.width;
        final y = yBase +
            sin(t * pi * 1.2 + i * 0.5) * 18 +
            sin(t * pi * 2.0 + i * 0.8) * 8;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);

      // Very faint fill below
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Color.fromRGBO(180, 150, 46, 0.008);
      final fillPath = Path.from(path);
      fillPath.lineTo(size.width, size.height);
      fillPath.lineTo(0, size.height);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
