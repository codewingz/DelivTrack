import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double width;
  final double? height;
  final bool showHero;
  final String heroTag;

  const AppLogo({
    super.key,
    this.width = 220,
    this.height,
    this.showHero = true,
    this.heroTag = 'app_logo_hero',
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = Image.asset(
      'assets/images/logo.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
    );

    if (showHero) {
      return Hero(
        tag: heroTag,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

