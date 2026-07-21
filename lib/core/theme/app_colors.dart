import 'package:flutter/material.dart';

class AppColors {
  // Light Mode Standard Palette
  static const Color surface = Color(0xFFFBF9F4);
  static const Color atmosphericBlueGray = Color(0xFF7D8BA1);
  static const Color inactiveBlueGray = Color(0xFF9BA8BB);
  static const Color warmAccent = Color(0xFFF5E6CC);
  static const Color functionalBlue = Color(0xFF4A90E2);
  static const Color textPrimary = Color(0xFF2D3142);
  static const Color textSecondary = Color(0xFF9BA8BB);
  static const Color cloudMain = Color(0xFF7D8BA1);
  static const Color cloudShadow = Color(0xFF4F5D75);

  // Neumorphic Shadow Colors (Light Mode)
  // Highlight is intentionally translucent (~45% white), per the Clarity Clay
  // System spec. Fully opaque white is invisible on the cream surface but
  // "glows" harshly wherever a clay surface sits next to a dark one.
  static const Color shadowLight = Color(0x73FFFFFF);
  static Color shadowDark = const Color(0xFFD1CDC7).withValues(alpha: 0.5);
  
  static Color getCardColor() => Colors.white;
}
