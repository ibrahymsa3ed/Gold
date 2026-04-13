import 'package:flutter/material.dart';

class IgLogo extends StatelessWidget {
  const IgLogo({super.key, this.size = 48, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _IgLogoPainter(color: color ?? const Color(0xFFD4AF37)),
    );
  }
}

class _IgLogoPainter extends CustomPainter {
  _IgLogoPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.075
      ..strokeCap = StrokeCap.round;

    // "I" — left vertical bar, slightly shifted right to interlock with G
    final ix = s * 0.30;
    canvas.drawLine(Offset(ix, s * 0.18), Offset(ix, s * 0.82), paint);

    // "G" — open arc wrapping around the I
    final gCenter = Offset(s * 0.55, s * 0.5);
    final gRadius = s * 0.32;
    final gRect = Rect.fromCircle(center: gCenter, radius: gRadius);

    // Arc from top-right going counter-clockwise, leaving a gap at top-right
    canvas.drawArc(gRect, -0.4, 4.8, false, paint);

    // "G" horizontal bar (the tongue of the G)
    final tongueY = s * 0.5;
    canvas.drawLine(
      Offset(gCenter.dx + gRadius * 0.15, tongueY),
      Offset(gCenter.dx + gRadius, tongueY),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _IgLogoPainter old) => old.color != color;
}

class IgLogoAnimated extends StatefulWidget {
  const IgLogoAnimated({super.key, this.size = 80});
  final double size;

  @override
  State<IgLogoAnimated> createState() => _IgLogoAnimatedState();
}

class _IgLogoAnimatedState extends State<IgLogoAnimated>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scale = Tween(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _opacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.6, curve: Curves.easeIn)),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Transform.scale(
          scale: _scale.value,
          child: IgLogo(size: widget.size, color: const Color(0xFFD4AF37)),
        ),
      ),
    );
  }
}
