import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// The "3D Liquid Glass" look of the prototype, in two pieces:
/// [LiquidBackground] is the soft mint backdrop of a page and [GlassSurface]
/// is a see-through white panel that lets it show.

/// Page backdrop: three soft blobs of colour over a pale green, as in the
/// prototype's "ambient refraction backdrop".
class LiquidBackground extends StatelessWidget {
  const LiquidBackground({super.key, required this.child});
  final Widget child;

  static const _blobs = [
    (Alignment(0.6, -0.64), Color(0x6B9EEFD4)),
    (Alignment(-0.76, 0.1), Color(0x29115E46)),
    (Alignment(0.5, 0.7), Color(0x579EEFD4)),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.liquidBase),
        for (final (center, color) in _blobs)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: center,
                radius: 0.9,
                colors: [color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        child,
      ],
    );
  }
}

/// A translucent white panel with a white edge, a soft shadow and the solid
/// 3D ledge under it. Give [blurSigma] only where content moves behind the
/// panel (the tab bar): blurring costs a layer, and over the still backdrop it
/// would look the same without it.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    required this.radius,
    this.blurSigma = 0,
    this.ledgeColor = AppColors.cardBevel,
    this.ledgeHeight = 4,
    this.fill = AppColors.glassFill,
  });

  final Widget child;
  final double radius;
  final double blurSigma;
  final Color ledgeColor;
  final double ledgeHeight;

  /// The see-through white; more opaque where text must stay readable over
  /// anything (a dialog).
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    Widget panel = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: borderRadius,
        border: Border.all(color: AppColors.glassEdge),
      ),
      child: child,
    );
    if (blurSigma > 0) {
      panel = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: panel,
        ),
      );
    }
    return CustomPaint(
      painter: _OuterShadowPainter(
        radius: radius,
        ledgeColor: ledgeColor,
        ledgeHeight: ledgeHeight,
      ),
      child: panel,
    );
  }
}

/// Draws the shadows only outside the panel. A normal box shadow is also
/// painted under the box, where it would show through the glass and grey it.
class _OuterShadowPainter extends CustomPainter {
  const _OuterShadowPainter({
    required this.radius,
    required this.ledgeColor,
    required this.ledgeHeight,
  });
  final double radius;
  final Color ledgeColor;
  final double ledgeHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect.inflate(48)),
        Path()..addRRect(shape),
      ),
    );
    canvas.drawRRect(
      shape.shift(const Offset(0, 8)),
      Paint()
        ..color = AppColors.cardShadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawRRect(
      shape.shift(Offset(0, ledgeHeight)),
      Paint()..color = ledgeColor,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OuterShadowPainter old) =>
      old.radius != radius ||
      old.ledgeColor != ledgeColor ||
      old.ledgeHeight != ledgeHeight;
}
