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
        // Layer 1: Deep gradient base with gold-brown warmth
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0B0B0D),
                  Color(0xFF12100C),
                  Color(0xFF0E0D0B),
                  Color(0xFF14110D),
                  Color(0xFF0B0B0D),
                ],
                stops: [0.0, 0.25, 0.5, 0.75, 1.0],
              ),
            ),
          ),
        ),

        // Layer 2: Vertical warm gradient overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1A1508).withValues(alpha: 0.3),
                  Colors.transparent,
                  const Color(0xFF0D0B08).withValues(alpha: 0.4),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.35, 0.65, 1.0],
              ),
            ),
          ),
        ),

        // Layer 3: Flowing wave patterns — visible, premium fintech
        Positioned.fill(
          child: CustomPaint(painter: _WavePainter()),
        ),

        // Layer 4: Radial gold glow — top left
        Positioned(
          top: -80,
          left: -60,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFD4AF37).withValues(alpha: 0.07),
                  const Color(0xFFC9A227).withValues(alpha: 0.03),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // Layer 5: Radial gold glow — bottom right
        Positioned(
          bottom: 60,
          right: -80,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFB8962E).withValues(alpha: 0.06),
                  const Color(0xFF8B7332).withValues(alpha: 0.02),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // Layer 6: Subtle center glow
        Positioned(
          top: MediaQuery.of(context).size.height * 0.3,
          left: MediaQuery.of(context).size.width * 0.2,
          child: Container(
            width: 200,
            height: 200,
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

        child,
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Filled wave bands for smooth flowing look
    for (var i = 0; i < 6; i++) {
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Color.fromRGBO(
          180 + (i * 8),
          150 + (i * 5),
          50 + (i * 3),
          0.015 + i * 0.004,
        );

      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 + i * 0.15
        ..color = Color.fromRGBO(
          212, 175, 55,
          0.04 + i * 0.008,
        );

      final yBase = size.height * (0.08 + i * 0.16);
      final amplitude1 = 25.0 + i * 8;
      final amplitude2 = 12.0 + i * 5;
      final freq1 = 1.5 + i * 0.3;
      final freq2 = 2.5 + i * 0.4;
      final phase = i * 0.9;

      final path = Path();
      path.moveTo(0, yBase);

      for (var x = 0.0; x <= size.width; x += 1) {
        final t = x / size.width;
        final y = yBase +
            sin(t * pi * freq1 + phase) * amplitude1 +
            sin(t * pi * freq2 + phase * 1.5) * amplitude2;
        path.lineTo(x, y);
      }

      // Draw the stroke line
      canvas.drawPath(path, strokePaint);

      // Draw a filled region below the wave for a subtle band effect
      final fillPath = Path.from(path);
      fillPath.lineTo(size.width, yBase + amplitude1 + 40);
      fillPath.lineTo(0, yBase + amplitude1 + 40);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
