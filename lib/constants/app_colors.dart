import 'package:flutter/material.dart';

class AppColors {
  // Brand Emerald & Ivory palette (V2 3D Liquid Glass)
  static const brand900 = Color(0xFF0B4633);
  static const brand800 = Color(0xFF115E46);
  static const brand700 = Color(0xFF167558);
  static const brand100 = Color(0xFFD8F3E5);
  static const brand50 = Color(0xFFEEF8F2);
  static const mint = Color(0xFF9EEFD4);
  static const mintLight = Color(0xFFB2F5DF);
  static const mintDark = Color(0xFF5CC5A2);

  // Core semantic aliases
  static const primary = Color(0xFF115E46);
  static const primaryDark = Color(0xFF0B4633);
  static const background = Color(0xFFF4F7F5);
  static const surface = Color(0xFFFFFFFF);
  static const accent = Color(0xFFDCA044);
  static const textPrimary = Color(0xFF14261E);
  static const textSecondary = Color(0xFF667B71);
  static const border = Color(0xFFE2EBE6);
  static const borderLight = Color(0xFFDCE6E0);
  static const label = Color(0xFF475D53);
  static const inputBackground = Color(0xFFF8FAF9);
  static const disabled = Color(0xFFF3F4F6);

  // 3D Card & Button bevel shadows
  static const cardBevel = Color(0xFFD6E3DC);
  static const cardShadow = Color(0x1F115E46);
  static const btnBevel = Color(0xFF073325);
  static const fabBevel = Color(0xFF5CC5A2);
  static const stripeDue = Color(0xFFD97706);
  static const closeButton = Color(0xFFF1F5F3);

  // 3D Liquid Glass
  static const liquidBase = Color(0xFFEDF4EF);
  static const glassFill = Color(0xA8FFFFFF);
  static const glassEdge = Color(0xE0FFFFFF);
  static const dockLedge = Color(0xFFCEDED5);
  static const glassDialogFill = Color(0xD9FFFFFF);
  static const glassSheetFill = Color(0xD6F4F7F5);
  static const sheetHandle = Color(0xFFB4C6BC);
  static const glassSnackFill = Color(0xF2F6FAF7);
  static const errorBevel = Color(0xFF8E1B1B);

  // Status & Financial indicators
  static const success = Color(0xFF15803D);
  static const pending = Color(0xFFB45309);
  static const error = Color(0xFFB91C1C);
  static const credit = Color(0xFF7C3AED);
  static const advance = Color(0xFF0369A1);
  static const freeGift = Color(0xFF64748B);

  // Gradients
  static const headerGradient = LinearGradient(
    begin: Alignment(-0.8, -1.0),
    end: Alignment(0.8, 1.0),
    colors: [Color(0xFF17785A), Color(0xFF115E46), Color(0xFF0B4633)],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment(-0.8, -1.0),
    end: Alignment(0.8, 1.0),
    colors: [Color(0xFF115E46), Color(0xFF0B4633), Color(0xFF073325)],
  );

  static const primaryBtnGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF17785A), Color(0xFF115E46)],
  );

  static const mintFabGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFB2F5DF), Color(0xFF9EEFD4)],
  );
}
