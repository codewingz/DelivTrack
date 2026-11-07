import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'brand_loading_indicator.dart';
import '../design_system/foundations/radius/app_radius.dart';

/// Full-width primary action (56 high). Disabled while [isLoading] to block double taps.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
        ),
        child: isLoading
            ? const BrandLoadingIndicator(size: 22, strokeWidth: 2.4, color: Colors.white)
            : Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}
