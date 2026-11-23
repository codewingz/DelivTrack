import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// A round mint badge with the first letter of [name] (a person's avatar).
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({
    super.key,
    required this.name,
    this.size = 48,
    this.filled = false,
  });
  final String name;
  final double size;

  /// Solid green with a white letter (the signed-in user) instead of mint.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : AppColors.brand50,
          shape: BoxShape.circle,
          border: filled ? null : Border.all(color: AppColors.brand100),
        ),
        child: Text(
          trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase(),
          // Fixed size: it must fit its circle (a documented exception, like
          // CountBadge).
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w800,
            color: filled ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }
}
