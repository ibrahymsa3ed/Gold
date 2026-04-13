import 'package:flutter/material.dart';

import '../theme/app_themes.dart';

class IgLogo extends StatelessWidget {
  const IgLogo({
    super.key,
    this.size = 48,
    this.applyLightModeTone = true,
  });

  final double size;
  final bool applyLightModeTone;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lightModeTone = const Color(0xFF8A6714);

    return Image.asset(
      'assets/icons/ig_logo_mark.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      color: !isDark && applyLightModeTone ? lightModeTone : null,
      colorBlendMode: !isDark && applyLightModeTone ? BlendMode.modulate : null,
    );
  }
}

class InstaGoldWordmark extends StatelessWidget {
  const InstaGoldWordmark({
    super.key,
    this.fontSize = 28,
  });

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? const Color(0xFFF1E6D3) : const Color(0xFF241E14);
    final accentColor = isDark ? kGoldLight : const Color(0xFF8A6714);

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Insta',
            style: TextStyle(
              color: baseColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              height: 1,
            ),
          ),
          TextSpan(
            text: 'Gold',
            style: TextStyle(
              color: accentColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              height: 1,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
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
      CurvedAnimation(
          parent: _ctrl, curve: const Interval(0, 0.6, curve: Curves.easeIn)),
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
          child: IgLogo(size: widget.size),
        ),
      ),
    );
  }
}
